import Foundation

/// The action performed when a function key is activated.
///
/// - `system`: fires the default macOS system function (HID / CGEvent), unchanged from v1.
/// - `openApp`: launches or activates an app by its bundle identifier.
/// - `openURL`: opens any URL (https://, file://, custom schemes).
/// - `shellCommand`: runs a command string via `/bin/sh -c` in the background.
enum KeyAction: Codable, Equatable {
    case system
    case openApp(bundleID: String)
    case openURL(url: URL)
    case shellCommand(cmd: String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, bundleID, url, cmd
    }

    private enum ActionType: String, Codable {
        case system, openApp, openURL, shellCommand
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ActionType.self, forKey: .type)
        switch type {
        case .system:
            self = .system
        case .openApp:
            let id = try c.decode(String.self, forKey: .bundleID)
            self = .openApp(bundleID: id)
        case .openURL:
            let url = try c.decode(URL.self, forKey: .url)
            self = .openURL(url: url)
        case .shellCommand:
            let cmd = try c.decode(String.self, forKey: .cmd)
            self = .shellCommand(cmd: cmd)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system:
            try c.encode(ActionType.system, forKey: .type)
        case .openApp(let id):
            try c.encode(ActionType.openApp, forKey: .type)
            try c.encode(id, forKey: .bundleID)
        case .openURL(let url):
            try c.encode(ActionType.openURL, forKey: .type)
            try c.encode(url, forKey: .url)
        case .shellCommand(let cmd):
            try c.encode(ActionType.shellCommand, forKey: .type)
            try c.encode(cmd, forKey: .cmd)
        }
    }

    // MARK: - Display helpers

    /// Human-readable summary for use in the settings UI.
    var displaySummary: String {
        switch self {
        case .system:               return "System Default"
        case .openApp(let id):      return id
        case .openURL(let url):     return url.absoluteString
        case .shellCommand(let cmd): return cmd
        }
    }

    /// SF Symbol name representing the action type.
    var typeIcon: String {
        switch self {
        case .system:        return "bolt.fill"
        case .openApp:       return "square.grid.3x3.fill"
        case .openURL:       return "link"
        case .shellCommand:  return "terminal.fill"
        }
    }

    /// Short label for the action type (used in the type picker).
    var typeName: String {
        switch self {
        case .system:        return "System"
        case .openApp:       return "App"
        case .openURL:       return "URL"
        case .shellCommand:  return "Shell"
        }
    }
}
