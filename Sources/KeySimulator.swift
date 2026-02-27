import AppKit
import Carbon
import IOKit
import IOKit.hidsystem

/// Simulates physical key presses for Mac function keys and dispatches custom actions.
///
/// - Brightness, keyboard backlight, media, and volume keys use HID system
///   events (NX key codes) because they are special system keys.
/// - Mission Control and Launchpad use `CGEvent` key simulation.
/// - Custom actions (openApp, openURL, shellCommand) are dispatched here.
///
/// Marked `@MainActor` to guarantee thread-safe access to the mutable
/// `lastPressTimestamps` dictionary (no concurrent mutations).
@MainActor
enum KeySimulator {

    // MARK: - Rate Limiting

    /// Minimum interval between simulated presses for the same key (seconds).
    private static let minimumPressInterval: TimeInterval = 0.15

    /// Tracks the last simulation timestamp per key ID to prevent event flooding.
    private static var lastPressTimestamps: [Int: TimeInterval] = [:]

    /// Simulate pressing the function key with the given ID (1–12), using the
    /// provided `KeyAction`. Defaults to `.system` if no action is supplied.
    /// Ignores calls that arrive faster than `minimumPressInterval` for the same key.
    /// Invalid key IDs outside the range 1–12 are silently ignored.
    static func simulateKeyPress(fnId: Int, action: KeyAction = .system) {
        // Validate key ID range to prevent misuse
        guard (1...12).contains(fnId) else { return }

        // Rate limiting: prevent rapid-fire event flooding
        let now = ProcessInfo.processInfo.systemUptime
        if let lastPress = lastPressTimestamps[fnId],
           now - lastPress < minimumPressInterval {
            return
        }
        lastPressTimestamps[fnId] = now

        switch action {
        case .openApp(let bundleID):
            dispatchOpenApp(bundleID: bundleID)
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .shellCommand(let cmd):
            dispatchShell(cmd: cmd)
        case .system:
            dispatchSystem(fnId: fnId)
        }
    }

    // MARK: - Action Dispatch

    private static func dispatchSystem(fnId: Int) {
        switch fnId {
        case 1:  sendHIDKey(code: NX_KEYTYPE_BRIGHTNESS_DOWN)
        case 2:  sendHIDKey(code: NX_KEYTYPE_BRIGHTNESS_UP)
        case 3:  sendCGKey(keyCode: 0xa0)   // F3 — Mission Control (160)
        case 4:  sendCGKey(keyCode: 0xa1)   // F4 — Launchpad (131 alias 161)
        case 5:  sendHIDKey(code: NX_KEYTYPE_ILLUMINATION_DOWN)
        case 6:  sendHIDKey(code: NX_KEYTYPE_ILLUMINATION_UP)
        case 7:  sendHIDKey(code: NX_KEYTYPE_PREVIOUS)
        case 8:  sendHIDKey(code: NX_KEYTYPE_PLAY)
        case 9:  sendHIDKey(code: NX_KEYTYPE_NEXT)
        case 10: sendHIDKey(code: NX_KEYTYPE_MUTE)
        case 11: sendHIDKey(code: NX_KEYTYPE_SOUND_DOWN)
        case 12: sendHIDKey(code: NX_KEYTYPE_SOUND_UP)
        default: break
        }
    }

    private static func dispatchOpenApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private static func dispatchShell(cmd: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", cmd]
        // Detach stdout/stderr so the shell output doesn't block the app
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    // MARK: - HID System Events (media / brightness / volume)

    /// Posts a HID system key event (key down + key up) using IOKit.
    /// This mirrors the mechanism macOS uses for physical special-function keys.
    ///
    /// IOKit HID event encoding (from IOKit/hidsystem headers):
    /// - `subtype: 8`  → NX_SUBTYPE_AUX_CONTROL_BUTTON (auxiliary control button event)
    /// - `0xa00`       → Key-down flag field for NX system-defined events
    /// - `0xb00`       → Key-up flag field for NX system-defined events
    /// - `data1`       → Encodes (keyCode << 16) | flags
    /// - `data2: -1`   → Repeat count (−1 = no repeat)
    private static func sendHIDKey(code: Int32) {
        func postHIDEvent(keyDown: Bool) {
            let flags: Int32 = keyDown ? 0xa00 : 0xb00         // NX key-down / key-up flags
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,                                     // NX_SUBTYPE_AUX_CONTROL_BUTTON
                data1: Int((Int32(code) << 16) | (keyDown ? 0x0a00 : 0x0b00)),
                data2: -1                                       // No key repeat
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        postHIDEvent(keyDown: true)
        postHIDEvent(keyDown: false)
    }

    // MARK: - CGEvent Key Simulation (Mission Control / Launchpad)

    /// Posts a CGEvent key-down + key-up for a regular virtual key code.
    private static func sendCGKey(keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
           let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
