import SwiftUI
import AppKit

/// Renders a single function key that looks like a physical keycap.
///
/// Uses system colors that automatically adapt to light / dark mode.
/// Shows a tooltip with the key's function description on hover.
struct FunctionKeyView: View {
    let key: FunctionKey
    var isPhysicallyPressed: Bool = false

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var lastTapTime: Date = .distantPast

    /// True when either tapped on-screen or physically pressed.
    private var isActive: Bool { isPressed || isPhysicallyPressed }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: key.systemIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .opacity(isHovered ? 1.0 : 0.85)
                .frame(height: 14)

            Text(key.label)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(keycapBackground)
        .overlay(keycapBorder)
        .scaleEffect(isActive ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.08), value: isPhysicallyPressed)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            // Debounce rapid taps to prevent event flooding
            let now = Date()
            guard now.timeIntervalSince(lastTapTime) >= 0.2 else { return }
            lastTapTime = now

            // Trigger the actual system function
            KeySimulator.simulateKeyPress(fnId: key.id)

            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
        }
        .help(key.functionDescription)
    }

    // MARK: - Keycap Appearance

    /// Flat keycap background mimicking M1 MacBook Air function keys.
    private var keycapBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(backgroundColor)
            .shadow(
                color: .black.opacity(isPressed ? 0 : 0.04),
                radius: isPressed ? 0 : 0.5,
                y: isPressed ? 0 : 0.5
            )
    }

    /// Subtle inset border for a physical keycap feel.
    private var keycapBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(
                Color.primary.opacity(isHovered ? 0.15 : 0.06),
                lineWidth: 0.5
            )
    }

    /// Background color — flat dark style that adapts to system appearance.
    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.3)
        } else if isHovered {
            return Color.primary.opacity(0.07)
        } else {
            return Color(nsColor: .controlColor)
        }
    }
}
