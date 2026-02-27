import SwiftUI
import AppKit

/// Settings window with two tabs: Key Customization and Profiles.
struct SettingsView: View {

    @EnvironmentObject private var store: KeyActionStore

    var body: some View {
        TabView {
            KeyCustomizationTab()
                .tabItem { Label("Keys", systemImage: "keyboard") }
            ProfilesTab()
                .tabItem { Label("Profiles", systemImage: "person.2") }
        }
        .frame(width: 560, height: 520)
    }
}

// MARK: - Key Customization Tab

/// Per-key action override list.
private struct KeyCustomizationTab: View {

    @EnvironmentObject private var store: KeyActionStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            keyList
            Divider()
            footerBar
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Key Customization")
                .font(.system(.headline, design: .rounded))
            Spacer()
            Text("Active: \(store.profileManager.activeProfile.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var keyList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(FunctionKey.allKeys) { key in
                    KeyActionRow(fnId: key.id, label: key.label, defaultIcon: key.systemIcon)
                    if key.id < 12 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Reset All to Defaults") {
                store.resetAll()
            }
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .font(.caption)
            .padding(.trailing, 20)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Profiles Tab

private struct ProfilesTab: View {

    @EnvironmentObject private var store: KeyActionStore
    @State private var newProfileName: String = ""
    @State private var isCreating = false

    private var manager: ProfileManager { store.profileManager }

    var body: some View {
        VStack(spacing: 0) {
            profileHeader
            Divider()
            profileList
            Divider()
            profileFooter
        }
    }

    private var profileHeader: some View {
        HStack {
            Image(systemName: "person.2")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Profiles")
                .font(.system(.headline, design: .rounded))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var profileList: some View {
        List {
            ForEach(manager.profiles) { profile in
                HStack {
                    // Active indicator
                    Image(systemName: manager.activeProfile.id == profile.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(manager.activeProfile.id == profile.id ? Color.accentColor : .secondary)
                        .font(.system(size: 14))

                    Text(profile.name)
                        .font(.system(size: 13))
                    Spacer()

                    // Activate button
                    if manager.activeProfile.id != profile.id {
                        Button("Use") { manager.setActive(id: profile.id) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    // Duplicate button
                    Button {
                        manager.duplicate(id: profile.id, name: "\(profile.name) Copy")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate profile")

                    // Delete button (disabled for Default)
                    Button {
                        manager.delete(id: profile.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(profile.id == ProfileManager.defaultID ? Color.secondary.opacity(0.3) : .red)
                    }
                    .buttonStyle(.plain)
                    .disabled(profile.id == ProfileManager.defaultID)
                    .help(profile.id == ProfileManager.defaultID ? "The Default profile cannot be deleted" : "Delete profile")
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
    }

    private var profileFooter: some View {
        HStack(spacing: 8) {
            if isCreating {
                TextField("Profile name", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit { commitCreate() }
                Button("Create", action: commitCreate)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { isCreating = false; newProfileName = "" }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    isCreating = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func commitCreate() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        manager.createProfile(name: name)
        newProfileName = ""
        isCreating = false
    }
}

// MARK: - Per-Key Row

/// A single row in the settings list for one function key.
private struct KeyActionRow: View {

    let fnId: Int
    let label: String
    let defaultIcon: String

    @EnvironmentObject private var store: KeyActionStore
    @State private var selectedType: ActionType = .system
    @State private var textInput: String = ""

    private enum ActionType: String, CaseIterable, Identifiable {
        case system     = "System"
        case openApp    = "App"
        case openURL    = "URL"
        case shell      = "Shell"
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Key badge
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 36, height: 26)
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            // Type picker
            Picker("", selection: $selectedType) {
                ForEach(ActionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .onChange(of: selectedType) { _ in commitChange() }

            // Detail input (hidden for .system)
            if selectedType != .system {
                TextField(placeholder, text: $textInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { commitChange() }
            } else {
                Spacer()
            }

            // Reset button
            Button {
                store.setAction(nil, for: fnId)
                syncFromStore()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11))
                    .foregroundStyle(store.action(for: fnId) == .system ? Color.secondary.opacity(0.3) : .accentColor)
            }
            .buttonStyle(.plain)
            .help("Reset to system default")
            .disabled(store.action(for: fnId) == .system)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear { syncFromStore() }
        .onChange(of: store.overrides) { _ in syncFromStore() }
    }

    private var placeholder: String {
        switch selectedType {
        case .system:  return ""
        case .openApp: return "com.apple.Safari"
        case .openURL: return "https://example.com"
        case .shell:   return "open -a Terminal"
        }
    }

    private func syncFromStore() {
        switch store.action(for: fnId) {
        case .system:
            selectedType = .system
            textInput = ""
        case .openApp(let id):
            selectedType = .openApp
            textInput = id
        case .openURL(let url):
            selectedType = .openURL
            textInput = url.absoluteString
        case .shellCommand(let cmd):
            selectedType = .shell
            textInput = cmd
        }
    }

    private func commitChange() {
        switch selectedType {
        case .system:
            store.setAction(nil, for: fnId)
        case .openApp:
            let trimmed = textInput.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            store.setAction(.openApp(bundleID: trimmed), for: fnId)
        case .openURL:
            let trimmed = textInput.trimmingCharacters(in: .whitespaces)
            guard let url = URL(string: trimmed), url.scheme != nil else { return }
            store.setAction(.openURL(url: url), for: fnId)
        case .shell:
            let trimmed = textInput.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            store.setAction(.shellCommand(cmd: trimmed), for: fnId)
        }
    }
}
