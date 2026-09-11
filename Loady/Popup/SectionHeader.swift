import SwiftUI

/// Shared header for every module's popup section: icon, name, a subtitle,
/// and the headline number on the right.
struct SectionHeader: View {
    let module: Module
    let subtitle: String
    let value: String
    var animation: Animation?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: module.symbolName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 15)

            VStack(alignment: .leading, spacing: 0) {
                Text(module.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(-0.5)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(animation, value: value)
        }
    }
}
