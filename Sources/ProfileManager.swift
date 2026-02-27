import Foundation
import Combine

/// Manages a list of `KeyProfile` objects and tracks the active one.
///
/// Profiles and the active profile ID are persisted in `UserDefaults`.
/// `KeyActionStore` delegates all reads to the active profile so the UI
/// automatically reflects whichever profile is selected.
final class ProfileManager: ObservableObject {

    private static let profilesKey    = "keyProfiles"
    private static let activeIDKey    = "activeProfileID"

    /// All stored profiles. Always contains at least one (the built-in Default).
    @Published private(set) var profiles: [KeyProfile] = []

    /// The currently active profile.
    @Published private(set) var activeProfile: KeyProfile

    init() {
        let loaded = Self.loadProfiles()
        let profiles = loaded.isEmpty ? [KeyProfile(id: Self.defaultID, name: "Default")] : loaded
        self.profiles = profiles

        let savedID = UserDefaults.standard.string(forKey: Self.activeIDKey).flatMap { UUID(uuidString: $0) }
        let active = profiles.first { $0.id == savedID } ?? profiles[0]
        self.activeProfile = active
    }

    // MARK: - Built-in Default ID

    /// Stable UUID for the built-in Default profile so it survives reinstalls.
    static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // MARK: - Public API

    func setActive(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        activeProfile = profile
        UserDefaults.standard.set(id.uuidString, forKey: Self.activeIDKey)
    }

    /// Creates a new blank profile and makes it active.
    @discardableResult
    func createProfile(name: String) -> KeyProfile {
        let profile = KeyProfile.blank(name: name)
        profiles.append(profile)
        save()
        setActive(id: profile.id)
        return profile
    }

    /// Duplicates an existing profile under a new name.
    @discardableResult
    func duplicate(id: UUID, name: String) -> KeyProfile? {
        guard let source = profiles.first(where: { $0.id == id }) else { return nil }
        let copy = KeyProfile(name: name, actions: source.actions)
        profiles.append(copy)
        save()
        return copy
    }

    func rename(id: UUID, to name: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].name = name
        if activeProfile.id == id { activeProfile.name = name }
        save()
    }

    /// Deletes a profile.  The Default profile cannot be deleted.
    /// If the active profile is deleted, falls back to Default.
    func delete(id: UUID) {
        guard id != Self.defaultID else { return }
        profiles.removeAll { $0.id == id }
        save()
        if activeProfile.id == id {
            setActive(id: profiles.first?.id ?? Self.defaultID)
        }
    }

    /// Updates a key action in the active profile.
    func setAction(_ action: KeyAction?, for fnId: Int) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfile.id }) else { return }
        if let action, action != .system {
            profiles[idx].actions[fnId] = action
        } else {
            profiles[idx].actions.removeValue(forKey: fnId)
        }
        activeProfile = profiles[idx]
        save()
    }

    /// Clears all overrides in the active profile.
    func resetActiveProfile() {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfile.id }) else { return }
        profiles[idx].actions = [:]
        activeProfile = profiles[idx]
        save()
    }

    // MARK: - Persistence

    private static func loadProfiles() -> [KeyProfile] {
        guard
            let data = UserDefaults.standard.data(forKey: profilesKey),
            let decoded = try? JSONDecoder().decode([KeyProfile].self, from: data)
        else { return [] }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.profilesKey)
    }
}
