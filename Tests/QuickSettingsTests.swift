import Testing
import Foundation
@testable import apfel_quick

// Tests for QuickSettings persistence.
// Uses an isolated UserDefaults suite per test to avoid cross-test contamination.

@Suite("QuickSettings")
struct QuickSettingsTests {

    // Isolated UserDefaults suite name — unique per test run
    private func freshDefaults() -> UserDefaults {
        let suiteName = "com.apfelquick.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return defaults
    }

    // MARK: - 1. Default values

    @Test func testDefaultValues() {
        let settings = QuickSettings()
        #expect(settings.autoCopy == true)
        #expect(settings.launchAtLogin == true)
        #expect(settings.showMenuBar == true)
        #expect(settings.checkForUpdatesOnLaunch == true)
        #expect(settings.hasSeenWelcome == false)
    }

    // MARK: - 2. Hotkey defaults

    @Test func testHotkeyDefaults() {
        let settings = QuickSettings()
        // Space bar key code = 49
        #expect(settings.hotkeyKeyCode == 49)
        // Option key modifier = NSEvent.ModifierFlags.option.rawValue = 524288
        #expect(settings.hotkeyModifiers == 524288)
    }

    // MARK: - 3. Save and load round-trip preserves all fields

    @Test func testSaveAndLoadRoundtrip() {
        let defaults = freshDefaults()
        var settings = QuickSettings()
        settings.autoCopy = false
        settings.launchAtLogin = false
        settings.showMenuBar = false
        settings.checkForUpdatesOnLaunch = false
        settings.hasSeenWelcome = true
        settings.hotkeyKeyCode = 36   // Return key
        settings.hotkeyModifiers = 786432  // Command + Option

        settings.save(to: defaults)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.autoCopy == false)
        #expect(loaded.launchAtLogin == false)
        #expect(loaded.showMenuBar == false)
        #expect(loaded.checkForUpdatesOnLaunch == false)
        #expect(loaded.hasSeenWelcome == true)
        #expect(loaded.hotkeyKeyCode == 36)
        #expect(loaded.hotkeyModifiers == 786432)
    }

    // MARK: - 4. Load from empty UserDefaults returns defaults

    @Test func testLoadFromEmptyDefaultsReturnsDefaults() {
        let defaults = freshDefaults()
        let loaded = QuickSettings.load(from: defaults)
        // Should be identical to a fresh QuickSettings()
        #expect(loaded.autoCopy == true)
        #expect(loaded.launchAtLogin == true)
        #expect(loaded.showMenuBar == true)
        #expect(loaded.checkForUpdatesOnLaunch == true)
        #expect(loaded.hasSeenWelcome == false)
        #expect(loaded.hotkeyKeyCode == 49)
        #expect(loaded.hotkeyModifiers == 524288)
    }

    // MARK: - 5. Load from corrupt data returns defaults

    @Test func testLoadFromCorruptDataReturnsDefaults() {
        let defaults = freshDefaults()
        // Write garbage bytes to the settings key
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF])
        defaults.set(garbage, forKey: QuickSettings.defaultsKey)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.autoCopy == true)
        #expect(loaded.launchAtLogin == true)
        #expect(loaded.hasSeenWelcome == false)
    }

    // MARK: - 6. Second save overwrites first

    @Test func testSaveOverwritesPreviousValue() {
        let defaults = freshDefaults()

        var first = QuickSettings()
        first.autoCopy = true
        first.save(to: defaults)

        var second = QuickSettings()
        second.autoCopy = false
        second.save(to: defaults)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.autoCopy == false)
    }

    // MARK: - Additional edge cases

    // 7. hasSeenWelcome can be toggled and persisted
    @Test func testHasSeenWelcomeToggle() {
        let defaults = freshDefaults()
        var settings = QuickSettings()
        #expect(settings.hasSeenWelcome == false)

        settings.hasSeenWelcome = true
        settings.save(to: defaults)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.hasSeenWelcome == true)
    }

    // 8. Custom hotkey key code persists correctly
    @Test func testCustomHotkeyKeyCodePersists() {
        let defaults = freshDefaults()
        var settings = QuickSettings()
        settings.hotkeyKeyCode = 0   // 'a' key
        settings.save(to: defaults)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.hotkeyKeyCode == 0)
    }

    // 9. Modifier flags zero value persists
    @Test func testZeroModifierFlagsPersists() {
        let defaults = freshDefaults()
        var settings = QuickSettings()
        settings.hotkeyModifiers = 0
        settings.save(to: defaults)

        let loaded = QuickSettings.load(from: defaults)
        #expect(loaded.hotkeyModifiers == 0)
    }

    // 10. defaultsKey is stable
    @Test func testDefaultsKeyIsStable() {
        #expect(QuickSettings.defaultsKey == "QuickSettings")
    }
}
