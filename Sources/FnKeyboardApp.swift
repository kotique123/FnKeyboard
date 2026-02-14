import SwiftUI
import AppKit

/// Main entry point for the FnKeyboard menu bar application.
/// Uses NSStatusItem + NSPopover for precise centering below the icon.
@main
struct FnKeyboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows — everything is driven by the status item.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

/// Manages the status bar item and popover lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure popover
        popover.contentSize = NSSize(width: 720, height: 130)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: KeyboardView())

        // Configure status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Function Keys")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    /// Toggle popover centered below the status bar icon.
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Show relative to the button — NSPopover centers
            // the arrow on the positioning rect automatically.
            popover.show(
                relativeTo: sender.bounds,
                of: sender,
                preferredEdge: .minY
            )

            // Ensure popover window is key so it dismisses on outside click
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
