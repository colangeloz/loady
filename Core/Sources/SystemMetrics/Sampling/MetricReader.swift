/// Something that produces one sample per call.
///
/// Conformances own OS resources — Mach ports, IOKit handles, SMC connections
/// — and are therefore **deliberately not `Sendable`**. That isn't an
/// oversight: refusing the conformance is what makes the compiler stop a
/// reader being touched from two threads at once. A `Sampler` owns the
/// instance and supplies the isolation; a reader never crosses a boundary.
// `SendableMetatype` says the *type itself* is safe to share across threads —
// which it trivially is, being nothing but type information. That is a separate
// question from whether *instances* are safe, and they explicitly are not.
// Without this, `Sampler` can't spawn a Task without warning, because holding a
// generic `Sampler<Reader>` implies holding `Reader.Type`.
public protocol MetricReader: AnyObject, SendableMetatype {

    /// What this reader produces. Must be `Sendable` — it's the only thing
    /// that crosses from the background worker to the UI.
    associatedtype Sample: Sendable

    /// Reads once. Returns `nil` when there's nothing to report yet, which for
    /// delta-based readers means the first call after creation.
    func read() -> Sample?
}
