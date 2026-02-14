import Foundation

/// Represents a Mac keyboard function key with its associated system function.
struct FunctionKey: Identifiable {
    let id: Int
    let label: String
    let systemIcon: String
    let functionDescription: String
}

// MARK: - Key Group

/// A visual grouping of function keys (mirrors the physical keyboard layout).
struct KeyGroup: Identifiable {
    let id = UUID()
    let title: String
    let keys: [FunctionKey]
}

// MARK: - Static Data

extension FunctionKey {
    /// All 12 standard Mac function keys with their default functions.
    static let allKeys: [FunctionKey] = [
        FunctionKey(id: 1,  label: "F1",  systemIcon: "sun.min",              functionDescription: "Brightness Down"),
        FunctionKey(id: 2,  label: "F2",  systemIcon: "sun.max",              functionDescription: "Brightness Up"),
        FunctionKey(id: 3,  label: "F3",  systemIcon: "macwindow.on.rectangle", functionDescription: "Mission Control"),
        FunctionKey(id: 4,  label: "F4",  systemIcon: "square.grid.3x3.fill", functionDescription: "Launchpad"),
        FunctionKey(id: 5,  label: "F5",  systemIcon: "light.min",            functionDescription: "Keyboard Brightness Down"),
        FunctionKey(id: 6,  label: "F6",  systemIcon: "light.max",            functionDescription: "Keyboard Brightness Up"),
        FunctionKey(id: 7,  label: "F7",  systemIcon: "backward.end.fill",    functionDescription: "Previous Track"),
        FunctionKey(id: 8,  label: "F8",  systemIcon: "playpause.fill",       functionDescription: "Play / Pause"),
        FunctionKey(id: 9,  label: "F9",  systemIcon: "forward.end.fill",     functionDescription: "Next Track"),
        FunctionKey(id: 10, label: "F10", systemIcon: "speaker.slash.fill",   functionDescription: "Mute"),
        FunctionKey(id: 11, label: "F11", systemIcon: "speaker.wave.1.fill",  functionDescription: "Volume Down"),
        FunctionKey(id: 12, label: "F12", systemIcon: "speaker.wave.3.fill",  functionDescription: "Volume Up"),
    ]

    /// Top row key groups (F1–F6) — display & input controls.
    static let topGroups: [KeyGroup] = [
        KeyGroup(title: "Brightness", keys: [allKeys[0], allKeys[1]]),
        KeyGroup(title: "Desktop",    keys: [allKeys[2], allKeys[3]]),
        KeyGroup(title: "KB Light",   keys: [allKeys[4], allKeys[5]]),
    ]

    /// Bottom row key groups (F7–F12) — media & sound controls.
    static let bottomGroups: [KeyGroup] = [
        KeyGroup(title: "Media",  keys: [allKeys[6], allKeys[7], allKeys[8]]),
        KeyGroup(title: "Sound",  keys: [allKeys[9], allKeys[10], allKeys[11]]),
    ]

    /// Single-row grouped layout matching M1 MacBook Air physical keyboard.
    static let groups: [KeyGroup] = [
        KeyGroup(title: "Brightness", keys: [allKeys[0], allKeys[1]]),
        KeyGroup(title: "Desktop",    keys: [allKeys[2], allKeys[3]]),
        KeyGroup(title: "KB Light",   keys: [allKeys[4], allKeys[5]]),
        KeyGroup(title: "Media",      keys: [allKeys[6], allKeys[7], allKeys[8]]),
        KeyGroup(title: "Sound",      keys: [allKeys[9], allKeys[10], allKeys[11]]),
    ]
}
