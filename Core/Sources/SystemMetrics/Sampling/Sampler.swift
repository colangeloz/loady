import Foundation

/// Drives one `MetricReader` off the main thread and publishes its samples.
///
/// The app's single isolation boundary: a non-Sendable reader lives inside this
/// actor, and only Sendable samples leave it.
public actor Sampler<Reader: MetricReader> {

    public typealias Sample = Reader.Sample

    /// Built on `start()`, released on `stop()` — readers hold kernel
    /// resources, so a module you never enable should not cost a mach port.
    private let make: @Sendable () -> Reader
    private var reader: Reader?

    private var interval: Duration
    private var tickTask: Task<Void, Never>?

    /// Keyed so a listener can remove itself without disturbing the others.
    private var listeners: [UUID: AsyncStream<Sample>.Continuation] = [:]

    /// A factory, not an instance: `Reader` is not `Sendable`, so the reader
    /// must be created on this actor rather than handed to it.
    public init(interval: Duration, make: @escaping @Sendable () -> Reader) {
        self.interval = interval
        self.make = make
    }

    deinit {
        tickTask?.cancel()
    }

    /// Idempotent.
    public func start() {
        guard tickTask == nil else { return }
        if reader == nil { reader = make() }
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
        reader = nil   // releases mach ports and IOKit handles
    }

    /// Changes the cadence. Takes effect on the next tick.
    public func setInterval(_ interval: Duration) {
        self.interval = interval
    }

    /// `.bufferingNewest(1)`: if the main thread stalls, the UI resumes with
    /// the freshest reading rather than replaying stale ones.
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
        guard let reader else { return }
        let clock = ContinuousClock()

        _ = reader.read()   // baseline; delta readers report nothing first time

        var deadline = clock.now

        while !Task.isCancelled {
            deadline = deadline.advanced(by: interval)

            // Absolute deadline, not `sleep(for:)`, which would add the read's
            // own duration to every interval and drift slow. `tolerance` lets
            // the kernel batch this wakeup with others.
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
