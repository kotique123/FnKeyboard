# Copilot Instructions

## Build Commands

```bash
# Type-check and compile all sources (no .app bundle — use during development)
swift build

# Single-pass type-check only (fastest feedback loop)
swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos13.0 Sources/*.swift

# Build .app bundle for current architecture
./build.sh

# Build + DMG for current architecture
./build.sh --dmg

# Build + DMG for both arm64 and x86_64 (distribution)
./build.sh --release

# Signed distribution build
CODESIGN_IDENTITY="Developer ID Application: Your Name" ./build.sh --release
```

`swift build` uses SPM for type-checking; `./build.sh` calls `swiftc` directly and produces the `.app` bundle. SPM (`Package.swift`) exists only for editor tooling. No automated tests.

## Architecture

A menu-bar-only macOS app (`LSUIElement = true` in `Info.plist`) with no Dock icon and no sandbox.

**Entry point flow:** `FnKeyboardApp` (@main SwiftUI App) → `AppDelegate` (NSApplicationDelegateAdaptor) → `NSStatusItem` + `NSPopover` → `KeyboardView` (SwiftUI)

**Data model:** `FunctionKey` (value type) holds id (1–12), label, SF Symbol name, and description. Static groupings in `FunctionKey.groups` mirror the physical M1 MacBook Air keyboard layout (used by `KeyboardView`).

**Key customization stack:**
- `KeyAction` enum — `.system`, `.openApp(bundleID:)`, `.openURL(url:)`, `.shellCommand(cmd:)` — all Codable.
- `KeyProfile` — a named `[Int: KeyAction]` dict (Identifiable, Codable).
- `ProfileManager` — ObservableObject; owns `[KeyProfile]` + `activeProfile`; persisted as JSON in `UserDefaults`.
- `KeyActionStore` — thin ObservableObject pass-through to `ProfileManager`; injected as `@EnvironmentObject` into the entire SwiftUI tree from `AppDelegate`.

**Two distinct event simulation paths in `KeySimulator`:**
- **HID via IOKit** (`sendHIDKey`) — brightness, keyboard backlight, media, volume (F1, F2, F5–F12). Uses `NSEvent.otherEvent(with: .systemDefined ...)` encoded as NX system-defined events, posted to `.cghidEventTap`.
- **CGEvent** (`sendCGKey`) — Mission Control (F3, keyCode `0xa0`) and Launchpad (F4, keyCode `0xa1`).
- Custom actions (`.openApp`, `.openURL`, `.shellCommand`) are dispatched before reaching either HID/CGEvent path.

**Physical key detection:** `KeyPressMonitor` installs a `.listenOnly` CGEvent tap. Uses a `TapContext` weak-reference wrapper (`passRetained` once, `passUnretained` in callback) to safely bridge Swift ARC to the C callback — prevents both retain cycles and dangling pointers if the monitor is deallocated mid-callback. `isMonitoring` is protected by `NSLock` for thread-safe access between the main thread and the event tap thread.

**Live state:** `SystemStateMonitor` polls brightness (IOKit `IODisplayGetFloatParameter`) and volume/mute (CoreAudio `AudioObjectGetPropertyData`) every 1 second. Injected as `@EnvironmentObject` from `KeyboardView`; consumed in `FunctionKeyView` to render a 2 px bar on F1/F2/F10–F12.

**Profile menu:** right-click on the status bar icon shows an `NSMenu` listing all profiles (active one checked). Left-click shows the popover as before.

## Key Conventions

- **`KeySimulator` is `@MainActor`** — guarantees serial access to `lastPressTimestamps` without locks.
- **Rate limiting at two layers:** `KeySimulator` enforces 150 ms per key; `FunctionKeyView` debounces tap gestures at 200 ms. Both must be maintained if modifying input handling.
- **No App Sandbox** — required because CGEvent tap and HID event APIs are unavailable inside the sandbox. `FnKeyboard.entitlements` intentionally has no keys (hardened runtime with zero exceptions). Shell commands via `.shellCommand` work because there is no sandbox.
- **`KeyActionStore` is the single environment object injected at the top level** — never create a second instance. `ProfileManager` is owned by `AppDelegate` and flows down through `KeyActionStore`.
- **Profile Default ID is stable** (`ProfileManager.defaultID` — a fixed UUID) so the built-in Default profile survives `UserDefaults` being cleared and reinstalls.
- **`generate_icon.swift`** is a standalone script (not part of the SPM target). `build.sh` verifies its SHA-256 against the committed version before executing it as a supply-chain protection measure.
- **SF Symbols** are used for all key icons — symbol names live in `FunctionKey.allKeys`. Pick symbols from the SF Symbols app when adding keys.
- All UI uses `Color.primary` / `.secondary` / `Color(nsColor: .controlColor)` — never hard-code colors, so light/dark mode adaptation is automatic.
- **`SMAppService`** for Launch at Login requires the app bundle to be in `/Applications` at runtime; ad-hoc signed dev builds may be silently ignored by macOS.
