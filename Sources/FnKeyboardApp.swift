import SwiftUI
import AppKit

/// Main entry point for the FnKeyboard menu bar application.
/// Uses NSStatusItem + NSPopover for precise centering below the icon.
@main
struct FnKeyboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows — everything is driven by the status item.
        Settings {
            SettingsView()
                .environmentObject(appDelegate.actionStore)
        }
    }
}

// MARK: - AppDelegate

/// Manages the status bar item and popover lifecycle.
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    /// Shared profile manager — source of truth for all key customizations.
    let profileManager = ProfileManager()

    /// Shared action store — thin pass-through to `profileManager`.
    private(set) lazy var actionStore = KeyActionStore(profileManager: profileManager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure popover
        popover.contentSize = NSSize(width: 720, height: 130)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: KeyboardView(onDismiss: { [weak self] in
                self?.popover.performClose(nil)
            })
            .environmentObject(actionStore)
        )

        // Configure status item — left-click shows popover, right-click shows profile menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Function Keys")
            button.image?.isTemplate = true
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    // MARK: - Status Item Click

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showProfileMenu(sender)
        } else {
            togglePopover(sender)
        }
    }

    /// Toggle popover centered below the status bar icon.
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(
                relativeTo: sender.bounds,
                of: sender,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Profile NSMenu

    /// Shows a context menu listing all profiles for quick switching.
    private func showProfileMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        // Profile switcher items
        for profile in profileManager.profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(switchProfile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.id
            item.state = profile.id == profileManager.activeProfile.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let newItem = NSMenuItem(title: "New Profile…", action: #selector(newProfile), keyEquivalent: "")
        newItem.target = self
        menu.addItem(newItem)

        let manageItem = NSMenuItem(title: "Manage Profiles…", action: #selector(openSettings), keyEquivalent: ",")
        manageItem.target = self
        menu.addItem(manageItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FnKeyboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        sender.performClick(nil)
        // Remove menu so left-click reverts to togglePopover
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        profileManager.setActive(id: id)
    }

    @objc private func newProfile() {
        let alert = NSAlert()
        alert.messageText = "New Profile"
        alert.informativeText = "Enter a name for the new profile:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "Profile Name"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { profileManager.createProfile(name: name) }
        }
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
