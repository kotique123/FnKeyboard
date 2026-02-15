import SwiftUI
import AppKit

/// Observable object that monitors physical keyboard events via CGEvent tap
/// and publishes the set of currently pressed function key IDs.
///
/// Requires Accessibility permissions (Input Monitoring) on macOS.
/// The app will prompt the user automatically on first launch.
///
/// Thread Safety: `isMonitoring` is protected by `NSLock` for safe access
/// from the event tap callback. A weak-reference `TapContext` prevents
/// dangling-pointer dereferences if the monitor is deallocated while the
/// tap is still registered.
///
/// Security Note: The CGEvent tap API does not support filtering by key code
/// at registration time. All key events flow through the callback, but only
/// recognised function key codes (F1–F12) are processed; all other events
/// are immediately discarded without being stored or logged.
final class KeyPressMonitor: ObservableObject {

    /// Set of function key IDs (1–12) currently held down.
    @Published var pressedKeys: Set<Int> = []

    // MARK: - Thread-Safe Monitoring Flag

    /// Whether the event tap is actively monitoring.
    /// Protected by `_monitoringLock` for thread-safe access from the
    /// CGEvent tap callback and the main thread.
    private var _isMonitoring = false
    private let _monitoringLock = NSLock()

    private var isMonitoring: Bool {
        get { _monitoringLock.lock(); defer { _monitoringLock.unlock() }; return _isMonitoring }
        set { _monitoringLock.lock(); defer { _monitoringLock.unlock() }; _isMonitoring = newValue }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Safe Callback Context

    /// Weak-reference wrapper passed to the C callback via `Unmanaged`.
    /// Using a weak reference avoids a retain cycle and ensures the callback
    /// safely becomes a no-op if the monitor is deallocated.
    private class TapContext {
        weak var monitor: KeyPressMonitor?
        init(_ monitor: KeyPressMonitor) { self.monitor = monitor }
    }

    /// Retained by the C callback; released in `stopMonitoring()`.
    private var tapContext: TapContext?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Event Tap

    /// Installs a CGEvent tap to intercept key-down / key-up globally.
    ///
    /// Only `keyDown` and `keyUp` events are intercepted.
    /// `flagsChanged` is intentionally excluded to minimise the event surface.
    private func startMonitoring() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        // Create a weak-reference context for the C callback.
        let context = TapContext(self)
        let contextPtr = Unmanaged.passRetained(context).toOpaque()

        // Use a passthrough (listenOnly) tap so events are not consumed.
        // Return value is ignored for listenOnly taps — use passUnretained
        // to avoid leaking every CGEvent that flows through the system.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let ctx = Unmanaged<TapContext>.fromOpaque(refcon).takeUnretainedValue()
                ctx.monitor?.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: contextPtr
        ) else {
            // Balance the passRetained since the tap was not created.
            Unmanaged.passUnretained(context).release()
            print("⚠️  Could not create event tap. Enable Input Monitoring in System Settings → Privacy & Security.")
            return
        }

        tapContext = context
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isMonitoring = true
    }

    /// Removes the event tap and prevents further event processing.
    private func stopMonitoring() {
        isMonitoring = false
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        // Release the retained TapContext given to the C callback.
        // Perform release on main thread to avoid race conditions if a callback is currently executing.
        if let ctx = tapContext {
            tapContext = nil
            DispatchQueue.main.async {
                Unmanaged.passUnretained(ctx).release()
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Maps raw CGEvent key codes to function key IDs and updates state.
    /// Only processes recognized function key codes; all other events are ignored.
    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard isMonitoring else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard let fnId = Self.keyCodeToFnId[Int(keyCode)] else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isMonitoring else { return }
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
