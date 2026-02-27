import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for Launch at Login.
///
/// `SMAppService` requires the app to be located in `/Applications` (or run
/// from a signed bundle) to take effect at runtime.  During ad-hoc / dev
/// builds the toggle still compiles and persists, but macOS may silently
/// ignore the registration until the app is moved to `/Applications`.
final class LaunchAtLoginManager: ObservableObject {

    /// Whether the app is currently registered as a login item.
    @Published private(set) var isEnabled: Bool = false

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            print("⚠️  LaunchAtLogin error: \(error.localizedDescription)")
        }
    }
}
