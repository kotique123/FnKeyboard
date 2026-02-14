import SwiftUI
import AppKit

/// Observable object that monitors physical keyboard events via CGEvent tap
/// and publishes the set of currently pressed function key IDs.
///
/// Requires Accessibility permissions (Input Monitoring) on macOS.
/// The app will prompt the user automatically on first launch.
final class KeyPressMonitor: ObservableObject {

    /// Set of function key IDs (1–12) currently held down.
    @Published var pressedKeys: Set<Int> = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Event Tap

    /// Installs a CGEvent tap to intercept key-down / key-up globally.
    private func startMonitoring() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        // Use a passthrough tap so events are not consumed.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyPressMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // No accessibility permission yet — will be prompted automatically.
            print("⚠️  Could not create event tap. Enable Input Monitoring in System Settings → Privacy & Security.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Removes the event tap.
    private func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Maps raw CGEvent key codes to function key IDs and updates state.
    private func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard let fnId = Self.keyCodeToFnId[Int(keyCode)] else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case .keyDown:
                self.pressedKeys.insert(fnId)
            case .keyUp:
                self.pressedKeys.remove(fnId)
            default:
                break
            }
        }
    }

    /// Mapping from macOS virtual key codes to F-key IDs (1–12).
    private static let keyCodeToFnId: [Int: Int] = [
        122: 1,   // F1
        120: 2,   // F2
         99: 3,   // F3
        118: 4,   // F4
         96: 5,   // F5
         97: 6,   // F6
         98: 7,   // F7
        100: 8,   // F8
        101: 9,   // F9
        109: 10,  // F10
        103: 11,  // F11
        111: 12,  // F12
    ]
}
