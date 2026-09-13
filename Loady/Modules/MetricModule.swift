import SwiftUI

/// What a module contributes to the single menu bar item.
struct MenuBarPresentation: Sendable, Equatable {
    /// 0...1, for any bar or chart the item draws.
    let fraction: Double
    let text: String
}

/// One metric the app can show.
///
/// Not `Identifiable`: its `id` is nonisolated and cannot be satisfied from a
/// @MainActor type. Views key off `\.module`.
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
