import SwiftUI

/// A capsule progress bar sized for the popup.
struct Bar: View {
    let fraction: Double
    var tint: Color = .accentColor
    var height: CGFloat = 6
    var animation: Animation?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quinary)
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(animation, value: fraction)
    }
}
