import Testing
import Foundation
@testable import apfel_quick

/// TDD (RED) for saved prompts / slash commands (issue #11).
///
/// Spec:
/// - A SavedPrompt has a short `alias` and a full `prompt` expansion.
/// - A configurable prefix (default `/`) turns the input into a command.
/// - Input `/translate` expands to the saved prompt verbatim.
/// - Input `/translate hello` expands to "<saved prompt>\n\nhello".
/// - Prefix is configurable via QuickSettings.savedPromptPrefix.
/// - Aliases are stored in QuickSettings.savedPrompts.

@Suite("SavedPrompt")
struct SavedPromptTests {

    @Test func testInitProducesUUID() {
        let p = SavedPrompt(alias: "translate", prompt: "Translate to English:")
        #expect(p.id != UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
    }

    @Test func testCodableRoundTrip() throws {
        let p = SavedPrompt(alias: "grammar", prompt: "Fix grammar, return only the fix:")
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(SavedPrompt.self, from: data)
        #expect(back.alias == p.alias)
        #expect(back.prompt == p.prompt)
        #expect(back.id == p.id)
    }

    @Test func testEquatableById() {
        let a = SavedPrompt(alias: "x", prompt: "y")
        let b = a
        #expect(a == b)
    }

    @Test func testDefaultsAreSensible() {
        // The default set should include a translate + grammar + tldr alias
        // so new installs feel useful immediately.
        let defaults = SavedPrompt.defaults
        #expect(defaults.count >= 3)
        let aliases = Set(defaults.map(\.alias))
        #expect(aliases.contains("translate"))
        #expect(aliases.contains("grammar"))
        #expect(aliases.contains("tldr"))
    }

    @Test func testDefaultsAreUnique() {
        let defaults = SavedPrompt.defaults
        let aliases = defaults.map(\.alias)
        #expect(Set(aliases).count == aliases.count)
    }

    @Test func testDefaultsHaveNonEmptyPrompts() {
        for p in SavedPrompt.defaults {
            #expect(!p.prompt.isEmpty, "alias \(p.alias) has empty prompt")
            #expect(!p.alias.isEmpty)
        }
    }
}

@Suite("SavedPromptResolver")
struct SavedPromptResolverTests {

    private let prompts = [
        SavedPrompt(alias: "translate", prompt: "Translate to English:"),
        SavedPrompt(alias: "grammar", prompt: "Fix grammar, return only the fix:"),
        SavedPrompt(alias: "tldr", prompt: "TL;DR:"),
    ]

    // MARK: - resolve(input:prefix:savedPrompts:)

    @Test func testResolveBareAliasExpandsToPrompt() {
        let result = SavedPromptResolver.resolve(
            input: "/translate",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == "Translate to English:")
    }

    @Test func testResolveAliasWithTrailingContextAppends() {
        let result = SavedPromptResolver.resolve(
            input: "/translate hello world",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == "Translate to English:\n\nhello world")
    }

    @Test func testResolveReturnsNilForNonAlias() {
        let result = SavedPromptResolver.resolve(
            input: "regular prompt",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == nil)
    }

    @Test func testResolveReturnsNilForUnknownAlias() {
        let result = SavedPromptResolver.resolve(
            input: "/nope",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == nil)
    }

    @Test func testResolveIsCaseSensitive() {
        // Aliases are case-sensitive by design so e.g. /Summarize is distinct
        // from /summarize and users can have both.
        let result = SavedPromptResolver.resolve(
            input: "/Translate",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == nil)
    }

    @Test func testResolveWithCustomPrefix() {
        let result = SavedPromptResolver.resolve(
            input: ";translate hi",
            prefix: ";",
            savedPrompts: prompts
        )
        #expect(result == "Translate to English:\n\nhi")
    }

    @Test func testResolveWithMultiCharPrefix() {
        let result = SavedPromptResolver.resolve(
            input: ">>translate hi",
            prefix: ">>",
            savedPrompts: prompts
        )
        #expect(result == "Translate to English:\n\nhi")
    }

    @Test func testResolveEmptyPrefixResolvesNothing() {
        // Guard: an empty prefix would match every input. Resolver must
        // refuse to match in that case.
        let result = SavedPromptResolver.resolve(
            input: "anything",
            prefix: "",
            savedPrompts: prompts
        )
        #expect(result == nil)
    }

    @Test func testResolveEmptyAliasesReturnsNil() {
        let result = SavedPromptResolver.resolve(
            input: "/translate",
            prefix: "/",
            savedPrompts: []
        )
        #expect(result == nil)
    }

    @Test func testResolveInputIsJustThePrefixReturnsNil() {
        let result = SavedPromptResolver.resolve(
            input: "/",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(result == nil)
    }

    @Test func testResolveStripsLeadingWhitespaceOnTrailingContext() {
        let result = SavedPromptResolver.resolve(
            input: "/translate    hello",
            prefix: "/",
            savedPrompts: prompts
        )
        // Trailing whitespace collapses to a single space before appending.
        #expect(result == "Translate to English:\n\nhello")
    }

    // MARK: - matches(input:prefix:savedPrompts:)

    @Test func testMatchesReturnsPromptsStartingWithFragment() {
        let matches = SavedPromptResolver.matches(
            input: "/t",
            prefix: "/",
            savedPrompts: prompts
        )
        let aliases = matches.map(\.alias)
        #expect(aliases.contains("translate"))
        #expect(aliases.contains("tldr"))
        #expect(!aliases.contains("grammar"))
    }

    @Test func testMatchesReturnsAllWhenInputIsJustPrefix() {
        let matches = SavedPromptResolver.matches(
            input: "/",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(matches.count == 3)
    }

    @Test func testMatchesReturnsEmptyForNonPrefixInput() {
        let matches = SavedPromptResolver.matches(
            input: "regular",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(matches.isEmpty)
    }

    @Test func testMatchesSortsAliasesAlphabetically() {
        let matches = SavedPromptResolver.matches(
            input: "/",
            prefix: "/",
            savedPrompts: prompts
        )
        let sorted = matches.map(\.alias).sorted()
        #expect(matches.map(\.alias) == sorted)
    }

    @Test func testMatchesExcludesResultsOnceAFullMatchWithSpaceIsTyped() {
        // User typed "/translate some text" - autocomplete should not
        // pop up anymore (they are past the alias selection).
        let matches = SavedPromptResolver.matches(
            input: "/translate some text",
            prefix: "/",
            savedPrompts: prompts
        )
        #expect(matches.isEmpty)
    }
}

@Suite("QuickSettings + saved prompts")
struct QuickSettingsSavedPromptsTests {

    @Test func testDefaultPrefixIsSlash() {
        let s = QuickSettings()
        #expect(s.savedPromptPrefix == "/")
    }

    @Test func testDefaultSavedPromptsArePopulated() {
        let s = QuickSettings()
        #expect(s.savedPrompts.count >= 3)
    }

    @Test func testCustomPrefixRoundTripsThroughCodable() throws {
        var s = QuickSettings()
        s.savedPromptPrefix = ";"
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuickSettings.self, from: data)
        #expect(back.savedPromptPrefix == ";")
    }

    @Test func testCustomSavedPromptsRoundTripThroughCodable() throws {
        var s = QuickSettings()
        s.savedPrompts = [SavedPrompt(alias: "custom", prompt: "Do thing:")]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuickSettings.self, from: data)
        #expect(back.savedPrompts.count == 1)
        #expect(back.savedPrompts.first?.alias == "custom")
    }

    @Test func testLegacySettingsWithoutSavedPromptsStillDecodes() throws {
        // A QuickSettings JSON blob written before this feature must still
        // load cleanly and fall back to defaults.
        let legacy = #"""
        {"hotkeyKeyCode":49,"hotkeyModifiers":524288,"autoCopy":true,"launchAtLogin":true,"showMenuBar":true,"checkForUpdatesOnLaunch":true,"hasSeenWelcome":true,"launchAtLoginPromptShown":true}
        """#
        let s = try JSONDecoder().decode(QuickSettings.self, from: Data(legacy.utf8))
        #expect(s.savedPromptPrefix == "/")
        #expect(s.savedPrompts.count >= 3)
    }
}
