import Testing
import AppKit
@testable import apfel_quick

@Suite("HotkeySettings")
struct HotkeySettingsTests {

    // MARK: - Display name

    @Test func testDisplayNameOptionSpace() {
        let settings = QuickSettings()  // default Option+Space
        #expect(settings.hotkeyDisplayName == "\u{2325}Space")
    }

    @Test func testDisplayNameControlSpace() {
        var settings = QuickSettings()
        settings.hotkeyModifiers = NSEvent.ModifierFlags.control.rawValue
        settings.hotkeyKeyCode = 49
        #expect(settings.hotkeyDisplayName == "\u{2303}Space")
    }

    @Test func testDisplayNameCommandShiftA() {
        var settings = QuickSettings()
        settings.hotkeyModifiers = NSEvent.ModifierFlags([.command, .shift]).rawValue
        settings.hotkeyKeyCode = 0  // 'a'
        #expect(settings.hotkeyDisplayName == "\u{21E7}\u{2318}A")
    }

    @Test func testDisplayNameCommandReturn() {
        var settings = QuickSettings()
        settings.hotkeyModifiers = NSEvent.ModifierFlags.command.rawValue
        settings.hotkeyKeyCode = 36  // Return
        #expect(settings.hotkeyDisplayName == "\u{2318}\u{21A9}")
    }

    // MARK: - Validation

    @Test func testValidateRequiresModifier() {
        // No modifier = invalid
        #expect(QuickSettings.isValidHotkey(keyCode: 49, modifiers: 0) == false)
    }

    @Test func testValidateAcceptsOptionSpace() {
        let optionRaw = NSEvent.ModifierFlags.option.rawValue
        #expect(QuickSettings.isValidHotkey(keyCode: 49, modifiers: optionRaw) == true)
    }

    @Test func testValidateAcceptsControlSpace() {
        let controlRaw = NSEvent.ModifierFlags.control.rawValue
        #expect(QuickSettings.isValidHotkey(keyCode: 49, modifiers: controlRaw) == true)
    }

    @Test func testValidateAcceptsCommandShift() {
        let raw = NSEvent.ModifierFlags([.command, .shift]).rawValue
        #expect(QuickSettings.isValidHotkey(keyCode: 0, modifiers: raw) == true)
    }

    @Test func testValidateRejectsShiftAlone() {
        // Shift alone is not a valid modifier for hotkeys
        let shiftRaw = NSEvent.ModifierFlags.shift.rawValue
        #expect(QuickSettings.isValidHotkey(keyCode: 49, modifiers: shiftRaw) == false)
    }
}
