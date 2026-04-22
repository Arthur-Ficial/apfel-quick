import Foundation
import AppKit  // for NSEvent.ModifierFlags

struct QuickSettings: Codable, Sendable {
    // Hotkey — stored as key code + modifier flags raw value
    var hotkeyKeyCode: UInt16 = 49       // Space bar
    var hotkeyModifiers: UInt = 524288   // Option key (NSEvent.ModifierFlags.option.rawValue)

    // Behaviour
    var autoCopy: Bool = true            // Auto-copy result to clipboard when streaming completes
    var launchAtLogin: Bool = true       // Start at login
    var showMenuBar: Bool = true         // Show status bar icon

    // Updates
    var checkForUpdatesOnLaunch: Bool = true

    // First run
    var hasSeenWelcome: Bool = false
    var launchAtLoginPromptShown: Bool = false

    // Saved prompts (aliases)
    var savedPromptPrefix: String = "/"
    var savedPrompts: [SavedPrompt] = SavedPrompt.defaults

    // Appearance
    var appearance: AppearancePreference = .system

    // MCP servers (attached to apfel --serve at launch)
    var mcpServers: [MCPServerConfig] = []

    // Voice input (ohr)
    var voiceEnabled: Bool = true
    var ohrBinaryPathOverride: String?
    var voiceLanguage: String = "en-US"

    // Persistence key
    static let defaultsKey = "QuickSettings"

    // Custom decoder so settings blobs written before a field was added
    // still load cleanly, falling back to each field's default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .hotkeyKeyCode) ?? 49
        hotkeyModifiers = try c.decodeIfPresent(UInt.self, forKey: .hotkeyModifiers) ?? 524288
        autoCopy = try c.decodeIfPresent(Bool.self, forKey: .autoCopy) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        showMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showMenuBar) ?? true
        checkForUpdatesOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? true
        hasSeenWelcome = try c.decodeIfPresent(Bool.self, forKey: .hasSeenWelcome) ?? false
        launchAtLoginPromptShown = try c.decodeIfPresent(Bool.self, forKey: .launchAtLoginPromptShown) ?? false
        savedPromptPrefix = try c.decodeIfPresent(String.self, forKey: .savedPromptPrefix) ?? "/"
        savedPrompts = try c.decodeIfPresent([SavedPrompt].self, forKey: .savedPrompts) ?? SavedPrompt.defaults
        appearance = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        mcpServers = try c.decodeIfPresent([MCPServerConfig].self, forKey: .mcpServers) ?? []
        voiceEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
        ohrBinaryPathOverride = try c.decodeIfPresent(String.self, forKey: .ohrBinaryPathOverride)
        voiceLanguage = try c.decodeIfPresent(String.self, forKey: .voiceLanguage) ?? "en-US"
    }

    init() {}
}

extension QuickSettings {
    static func load(from defaults: UserDefaults = .standard) -> QuickSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(QuickSettings.self, from: data)
        else { return QuickSettings() }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: QuickSettings.defaultsKey)
        }
    }
}

// MARK: - Hotkey display and validation

extension QuickSettings {

    /// Human-readable hotkey label, e.g. "\u{2325}Space" for Option+Space.
    var hotkeyDisplayName: String {
        let flags = NSEvent.ModifierFlags(rawValue: hotkeyModifiers)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option)  { parts.append("\u{2325}") }
        if flags.contains(.shift)   { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }
        parts.append(Self.keyName(for: hotkeyKeyCode))
        return parts.joined()
    }

    /// Whether a hotkey combo is valid (must include Ctrl, Option, or Cmd).
    static func isValidHotkey(keyCode: UInt16, modifiers: UInt) -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            || flags.contains(.option)
            || flags.contains(.command)
    }

    /// Map key codes to display names.
    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "\u{21A9}"   // Return
        case 48: return "\u{21E5}"   // Tab
        case 51: return "\u{232B}"   // Delete
        case 53: return "\u{238B}"   // Escape
        default:
            let letterMap: [UInt16: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
                8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
                16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
                23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
                30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
                37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
                43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
                50: "`",
            ]
            return letterMap[keyCode] ?? "Key\(keyCode)"
        }
    }
}
