import SwiftUI
import AppKit

/// Main view displayed in the menu-bar popover.
/// Renders function keys in grouped rows that mirror the
/// physical Mac keyboard layout, plus a header and footer.
struct KeyboardView: View {

    @StateObject private var keyMonitor = KeyPressMonitor()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 12)
            keysSection
            Divider().padding(.horizontal, 12)
            footer
        }
        .frame(width: 720)
    }

    // MARK: - Header

    /// App title bar with keyboard icon.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Function Keys")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Keys Section

    /// Single row of grouped function keys matching M1 MacBook Air layout.
    private var keysSection: some View {
        HStack(spacing: 10) {
            ForEach(FunctionKey.groups) { group in
                HStack(spacing: 3) {
                    ForEach(group.keys) { key in
                        FunctionKeyView(
                            key: key,
                            isPhysicallyPressed: keyMonitor.pressedKeys.contains(key.id)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Footer

    /// Hint text and quit button.
    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "fn")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            Text("Press fn + key for standard function")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
