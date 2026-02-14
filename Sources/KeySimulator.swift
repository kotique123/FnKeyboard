import AppKit
import Carbon
import IOKit
import IOKit.hidsystem

/// Simulates physical key presses for Mac function keys.
///
/// - Brightness, keyboard backlight, media, and volume keys use HID system
///   events (NX key codes) because they are special system keys.
/// - Mission Control and Launchpad use `CGEvent` key simulation.
enum KeySimulator {

    /// Simulate pressing the function key with the given ID (1–12).
    static func simulateKeyPress(fnId: Int) {
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

    // MARK: - HID System Events (media / brightness / volume)

    /// Posts a HID system key event (key down + key up) using IOKit.
    /// This is the same mechanism macOS uses for the physical special keys.
    private static func sendHIDKey(code: Int32) {
        func postHIDEvent(keyDown: Bool) {
            let flags: Int32 = keyDown ? 0xa00 : 0xb00
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int((Int32(code) << 16) | (keyDown ? 0x0a00 : 0x0b00)),
                data2: -1
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
