import Foundation
import Combine

/// Persists per-key `KeyAction` overrides via the active `KeyProfile`.
///
/// Delegates reads and writes to `ProfileManager` so that switching profiles
/// automatically updates the entire keyboard layout.  The `overrides` property
/// is a computed view of the active profile's actions.
final class KeyActionStore: ObservableObject {

    let profileManager: ProfileManager
    private var cancellables: Set<AnyCancellable> = []

    init(profileManager: ProfileManager = ProfileManager()) {
        self.profileManager = profileManager
        // Re-publish profile changes as KeyActionStore changes so SwiftUI views update.
        profileManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// All overrides from the active profile.
    var overrides: [Int: KeyAction] { profileManager.activeProfile.actions }

    /// Returns the action for the given key ID, falling back to `.system`.
    func action(for fnId: Int) -> KeyAction {
        overrides[fnId] ?? .system
    }

    /// Sets a custom action for a key in the active profile.
    /// Pass `nil` to restore the system default.
    func setAction(_ action: KeyAction?, for fnId: Int) {
        profileManager.setAction(action, for: fnId)
    }

    /// Removes all overrides in the active profile.
    func resetAll() {
        profileManager.resetActiveProfile()
    }
}
