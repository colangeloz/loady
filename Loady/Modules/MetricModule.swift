import SwiftUI

/// What a module contributes to the single menu bar item.
struct MenuBarPresentation: Sendable, Equatable {
    /// 0...1, for any bar or chart the item draws.
    let fraction: Double
    /// The compact readout, e.g. "6%". Kept short — menu bar space is scarce.
    let text: String
}

/// One metric the app can show.
///
/// The protocol is deliberately thin: modules differ enormously in what they
/// measure and how their detail view looks, but they agree on exactly three
/// things — an identity, whether they're on, and a compact readout.
///
/// `AnyView` in `popupSection` is a pragmatic type erasure. A protocol with an
/// associated View type would be purer, but it can't be stored in an array
/// without a wrapper that costs more than it saves at this size.
// NOT `Identifiable`. That protocol's `id` requirement is nonisolated, and
// satisfying it from a @MainActor type is a Swift 6 isolation error. Views key
// off `\.module` instead, which is a plain enum and needs no isolation.
@MainActor
protocol MetricModule: AnyObject {
    var module: Module { get }
    var isEnabled: Bool { get set }

    /// `nil` until the first sample arrives.
    var presentation: MenuBarPresentation? { get }

    func start()
    func stop()

    /// This module's section of the popup.
    func popupSection() -> AnyView
}
