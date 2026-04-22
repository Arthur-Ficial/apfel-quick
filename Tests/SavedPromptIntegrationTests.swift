import Testing
import Foundation
@testable import apfel_quick

/// End-to-end: QuickViewModel.submit must expand a saved-prompt input
/// before handing it to the service, and never send the raw `/alias`
/// form to the model.

@Suite("Saved prompts + QuickViewModel")
@MainActor
struct SavedPromptIntegrationTests {

    private func makeViewModel(_ settings: QuickSettings = QuickSettings()) -> (QuickViewModel, CapturingService) {
        let service = CapturingService()
        let vm = QuickViewModel(settings: settings, service: service)
        vm.serviceWaitTimeout = .milliseconds(100)
        return (vm, service)
    }

    @Test func testBareAliasExpandsBeforeSend() async {
        let (vm, service) = makeViewModel()
        vm.input = "/translate"
        await vm.submit()
        let sent = await service.waitForPrompt()
        #expect(sent?.hasPrefix("Translate") == true)
        #expect(sent?.contains("/translate") == false)
    }

    @Test func testAliasWithContextAppends() async {
        let (vm, service) = makeViewModel()
        vm.input = "/translate hello world"
        await vm.submit()
        let sent = await service.waitForPrompt()
        #expect(sent?.contains("Translate") == true)
        #expect(sent?.contains("hello world") == true)
    }

    @Test func testUnknownAliasIsSentAsRawText() async {
        let (vm, service) = makeViewModel()
        vm.input = "/unknown"
        await vm.submit()
        let sent = await service.waitForPrompt()
        #expect(sent == "/unknown")
    }

    @Test func testNonAliasInputIsSentVerbatim() async {
        let (vm, service) = makeViewModel()
        vm.input = "hello there"
        await vm.submit()
        let sent = await service.waitForPrompt()
        #expect(sent == "hello there")
    }

    @Test func testCustomPrefixFromSettings() async {
        var s = QuickSettings()
        s.savedPromptPrefix = ";"
        let (vm, service) = makeViewModel(s)
        vm.input = ";translate hi"
        await vm.submit()
        let sent = await service.waitForPrompt()
        #expect(sent?.contains("Translate") == true)
        #expect(sent?.contains("hi") == true)
    }

    @Test func testPromptMatchesExposedForAutocomplete() {
        let (vm, _) = makeViewModel()
        vm.input = "/t"
        let aliases = vm.savedPromptMatches.map(\.alias)
        #expect(aliases.contains("translate"))
        #expect(aliases.contains("tldr"))
    }

    @Test func testPromptMatchesEmptyWhenNoPrefix() {
        let (vm, _) = makeViewModel()
        vm.input = "hello"
        #expect(vm.savedPromptMatches.isEmpty)
    }

    @Test func testCompleteSelectedAliasReplacesInput() {
        let (vm, _) = makeViewModel()
        vm.input = "/t"
        let translate = vm.settings.savedPrompts.first(where: { $0.alias == "translate" })!
        vm.complete(savedPrompt: translate)
        #expect(vm.input == "/translate ")
    }
}

// Captures the prompt passed into send() so the test can assert what was sent.
actor CapturingService: QuickService {
    private var _lastPrompt: String?

    nonisolated func send(prompt: String) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.record(prompt) }
            continuation.yield(StreamDelta(text: "ok", finishReason: nil))
            continuation.finish()
        }
    }

    /// Poll briefly so tests don't race against the detached Task in send().
    func waitForPrompt(timeoutMs: Int = 200) async -> String? {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if let p = _lastPrompt { return p }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return _lastPrompt
    }

    private func record(_ prompt: String) {
        _lastPrompt = prompt
    }

    nonisolated func healthCheck() async throws -> Bool { true }
}
