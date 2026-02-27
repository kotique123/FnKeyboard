import Foundation

/// A named set of function key action overrides.
///
/// The `Default` profile ships empty — keys with no entry fall back to `.system`.
struct KeyProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// Overrides indexed by function key ID (1–12).  Absent keys use `.system`.
    var actions: [Int: KeyAction]

    init(id: UUID = UUID(), name: String, actions: [Int: KeyAction] = [:]) {
        self.id = id
        self.name = name
        self.actions = actions
    }

    /// A blank profile with the given name (all keys at system defaults).
    static func blank(name: String) -> KeyProfile {
        KeyProfile(name: name)
    }
}
