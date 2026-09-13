/// Something that produces one sample per call.
///
/// Conformances own OS resources — Mach ports, IOKit handles, SMC connections —
/// and are **deliberately not `Sendable`**: refusing the conformance is what
/// stops a reader being touched from two threads. `SendableMetatype` is a
/// separate claim, about the type rather than its instances, and `Sampler`
/// needs it to spawn a Task while holding `Reader.Type`.
public protocol MetricReader: AnyObject, SendableMetatype {

    /// The only thing that crosses from the worker to the UI, hence `Sendable`.
    associatedtype Sample: Sendable

    /// `nil` when there is nothing to report yet — for delta-based readers,
    /// the first call.
    func read() -> Sample?
}
