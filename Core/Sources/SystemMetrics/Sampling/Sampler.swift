import Foundation

/// Drives one `MetricReader` on a background executor and publishes its
/// samples to any number of listeners.
///
/// This is the single isolation boundary in the app:
///
///     IOKit / Mach  →  MetricReader (non-Sendable, owned here)
///                            │
///                       actor Sampler
///                            │  AsyncStream<Sample>   ← Sendable values only
///     ═══════════════════════╪═══════════════════════
///                            │
///                      @MainActor UI
///
public actor Sampler<Reader: MetricReader> {

    public typealias Sample = Reader.Sample

    private let reader: Reader
    private var interval: Duration
    private var tickTask: Task<Void, Never>?

    /// One entry per listener. Keyed so a listener can remove itself when its
    /// stream is torn down, without disturbing the others.
    private var listeners: [UUID: AsyncStream<Sample>.Continuation] = [:]

    /// - Parameter make: a factory, not an instance.
    ///
    ///   `Reader` is not `Sendable`, so an already-built one could not legally
    ///   be handed across the boundary into this actor. Passing a `@Sendable`
    ///   closure instead means the reader is *created here*, on the actor's own
    ///   executor, and never exists anywhere else.
    public init(interval: Duration, make: @Sendable () -> Reader) {
        self.interval = interval
        self.reader = make()
    }

    deinit {
        tickTask?.cancel()
    }

    /// Begins sampling. Idempotent — calling it twice does nothing.
    public func start() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            await self?.run()
        }
    }

    /// Stops sampling and finishes every open stream.
    public func stop() {
        tickTask?.cancel()
        tickTask = nil
        for listener in listeners.values { listener.finish() }
        listeners.removeAll()
    }

    /// Changes the cadence. Takes effect on the next tick.
    public func setInterval(_ interval: Duration) {
        self.interval = interval
    }

    /// A new, independent stream of samples.
    ///
    /// Buffering is `.bufferingNewest(1)`: if the main thread stalls — a long
    /// scroll, a beachball elsewhere — the UI resumes with the *freshest*
    /// reading rather than replaying a backlog of stale ones. For a live
    /// monitor, old samples have no value.
    public func stream() -> AsyncStream<Sample> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            listeners[id] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeListener(id) }
            }
        }
    }

    private func removeListener(_ id: UUID) {
        listeners[id] = nil
    }

    private func run() async {
        let clock = ContinuousClock()

        // Establishes the baseline. Delta-based readers have nothing to say
        // on their first call, by contract.
        _ = reader.read()

        var deadline = clock.now

        while !Task.isCancelled {
            deadline = deadline.advanced(by: interval)

            // Absolute deadlines, never `sleep(for:)`. A relative sleep adds
            // however long the read took to every interval, so a "1 second"
            // sampler drifts measurably slow over an hour.
            //
            // `tolerance` lets the kernel fire this early to batch our wakeup
            // with other pending timers. Wakeups, not work, drain batteries.
            try? await clock.sleep(until: deadline, tolerance: interval / 10)

            // If the lid was closed for eight hours, `deadline` is now 28,800
            // ticks in the past and `sleep(until:)` returns instantly. Without
            // this the loop would spin thousands of times catching up.
            if clock.now - deadline > interval * 4 {
                deadline = clock.now
                _ = reader.read()   // discard the delta accumulated while asleep
                continue
            }

            guard let sample = reader.read() else { continue }

            // The only data that crosses the boundary: a Sendable value type.
            for listener in listeners.values {
                listener.yield(sample)
            }
        }
    }
}
