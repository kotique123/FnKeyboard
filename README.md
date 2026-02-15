# Fn Keyboard

![Example](example.png)

A lightweight macOS menu-bar utility that puts the Mac function keys (F1–F12) at your fingertips. Click an on-screen keycap and the real system action fires — brightness, media controls, volume, and more.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu-bar only** — lives in the status bar with a keyboard icon, no Dock clutter
- **Beautiful popover** — all 12 function keys grouped like a real Mac keyboard
- **SF Symbols** — each key shows the matching system icon and label
- **Animations** — hover highlight and spring-press feedback
- **Dark / Light mode** — colors automatically adapt to your system appearance
- **Real key simulation** — tapping a keycap triggers the actual system function via HID / CGEvent
- **Physical key monitoring** — detects which F-keys are physically held down (requires Accessibility permission)
- **Security hardened** — hardened runtime, code signing, rate limiting, and memory-safe event handling

## Requirements

| Requirement | Minimum |
|---|---|
| macOS | 13.0 Ventura |
| Xcode CLI Tools | `xcode-select --install` |

## Installation

### Download (recommended)

Grab the latest pre-built app from the [Releases](../../releases) page — no build tools required:

1. Download **FnKeyboard.app.zip** (or the DMG) from the latest release
2. Unzip and move **FnKeyboard.app** to `/Applications`
3. Open the app — grant Input Monitoring when prompted

### Build from source

```bash
git clone https://github.com/<your-username>/FnKeyboard.git
cd FnKeyboard
chmod +x build.sh
./build.sh
open build/FnKeyboard.app
```

For distribution builds, sign with a Developer ID:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name" ./build.sh --dmg
```

### Create a distributable DMG

```bash
./build.sh --dmg
# → build/FnKeyboard.dmg
```

## Permissions

On first launch, macOS will prompt you for **Input Monitoring** (Accessibility).
This is required so the app can detect physical key presses and simulate system actions.

> **System Settings → Privacy & Security → Input Monitoring** — enable **FnKeyboard**.

## Project Structure

```
FnKeyboard/
├── Sources/
│   ├── FnKeyboardApp.swift        # @main entry — NSStatusItem + NSPopover
│   ├── FunctionKey.swift           # Data model & static key definitions
│   ├── FunctionKeyView.swift       # Individual keycap SwiftUI component
│   ├── KeyboardView.swift          # Main popover layout (header, keys, footer)
│   ├── KeyPressMonitor.swift       # CGEvent tap for physical key detection
│   └── KeySimulator.swift          # HID / CGEvent key simulation
├── Assets.xcassets/                # App icon asset catalog
├── FnKeyboard.entitlements          # Hardened Runtime entitlements (no exceptions)
├── Info.plist                      # App metadata (LSUIElement = true)
├── Package.swift                   # Swift Package Manager manifest
├── build.sh                        # One-step build + codesign + optional DMG
├── generate_icon.swift             # Standalone script to generate AppIcon.icns
└── LICENSE
```

## Usage

| Action | How |
|---|---|
| Open | Click the ⌨️ icon in the menu bar |
| Trigger a key | Click any keycap in the popover |
| Dismiss | Click anywhere outside the popover |
| Quit | Click the ⌨️ icon → **Quit** button |

## Security

FnKeyboard requires powerful system permissions to function. Please read the following so you understand the trade-offs.

### Permissions & Privilege

| Permission | Why it's needed | What it grants |
|---|---|---|
| **Input Monitoring** (Accessibility) | Detect physical F-key presses via a `CGEvent` tap | Read access to **all** keyboard events system-wide |
| **Accessibility — Event Injection** | Simulate brightness, media, and volume controls | Ability to post **arbitrary** HID and `CGEvent` key events |

macOS bundles both capabilities into a single Accessibility permission — they cannot be requested separately.

### No App Sandbox

The app runs **unsandboxed** because the `CGEvent` tap and HID event APIs are not available inside the App Sandbox. This means the process has unrestricted access to the filesystem, network, and other user-level resources.

### What the App Does — and Does NOT Do

- **Does:** Intercept `keyDown` and `keyUp` events, filter for F1–F12 key codes only, and discard everything else immediately.
- **Does NOT:** Log, store, transmit, or retain any keystroke data. No network connections are made. No data leaves the process.

### Hardened Runtime

The app is code-signed with **Hardened Runtime** and **zero entitlement exceptions**, which protects against:

- `DYLD_INSERT_LIBRARIES` code injection
- Unsigned executable memory (JIT)
- Debugger attachment by non-root processes

### Build Integrity

The build script ([build.sh](build.sh)) includes:

- **SHA-256 verification** of `generate_icon.swift` against the committed version before execution
- **`--timestamp`** on distribution code signatures for notarization support
- A warning when falling back to ad-hoc signing (not suitable for distribution)

### Runtime Protections

- **Event tap memory safety** — the CGEvent tap callback uses `passUnretained` (not `passRetained`) to avoid leaking every system keyboard event, and an `isMonitoring` guard prevents use-after-teardown if the monitor is deallocated while a callback is in-flight.
- **Rate limiting** — `KeySimulator` enforces a minimum 150 ms interval between simulated presses per key, preventing event flooding from rapid automated clicks.
- **Tap debouncing** — the UI debounces on-screen key taps (200 ms) as a second layer of defense against rapid input.

### Recommendations for Users

1. **Verify the source** — review the code before building, especially [KeyPressMonitor.swift](Sources/KeyPressMonitor.swift) and [KeySimulator.swift](Sources/KeySimulator.swift).
2. **Use a signed build** — set `CODESIGN_IDENTITY` when building for distribution to enable signature verification.
3. **Revoke access when not in use** — you can disable Input Monitoring for FnKeyboard in System Settings at any time.

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-idea`)
3. Commit your changes (`git commit -m "Add my idea"`)
4. Push to the branch (`git push origin feature/my-idea`)
5. Open a Pull Request

## License

[MIT](LICENSE)
