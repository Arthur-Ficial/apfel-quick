import Testing
import Foundation
@testable import apfel_quick

// These tests are written in the RED phase — QuickViewModel does not yet exist.
// They define the intended API and will compile once QuickViewModel is implemented.

@MainActor
struct QuickViewModelTests {

    // MARK: - 1. Streaming output accumulates correctly

    @Test func testSubmitStreamsOutput() async throws {
        let service = MockQuickService()
        await service.setResponses([
            StreamDelta(text: "Hello", finishReason: nil),
            StreamDelta(text: " world", finishReason: nil),
            StreamDelta(text: "!", finishReason: .some("stop")),
        ])
        let vm = QuickViewModel(service: service)
        vm.inputText = "Say hello"
        await vm.submit()
        #expect(vm.output == "Hello world!")
    }

    // MARK: - 2. Auto-copy enabled writes to clipboard on completion

    @Test func testAutoCopyOnCompletionWhenEnabled() async throws {
        let service = MockQuickService()
        await service.setResponses([
            StreamDelta(text: "Copied text", finishReason: .some("stop")),
        ])
        let vm = QuickViewModel(service: service)
        vm.autoCopy = true
        vm.inputText = "Give me something to copy"
        await vm.submit()
        let clipboardValue = NSPasteboard.general.string(forType: .string)
        #expect(clipboardValue == vm.output)
    }

    // MARK: - 3. Auto-copy disabled leaves clipboard untouched

    @Test func testAutoCopyDisabledSkipsClipboard() async throws {
        // Seed clipboard with a sentinel value
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("sentinel", forType: .string)

        let service = MockQuickService()
        await service.setResponses([
            StreamDelta(text: "Should not be copied", finishReason: .some("stop")),
        ])
        let vm = QuickViewModel(service: service)
        vm.autoCopy = false
        vm.inputText = "Don't copy this"
        await vm.submit()

        let clipboardValue = NSPasteboard.general.string(forType: .string)
        #expect(clipboardValue == "sentinel")
    }

    // MARK: - 4. cancel() stops isStreaming

    @Test func testCancelMidStreamStopsIsStreaming() async throws {
        let service = MockQuickService()
        // Use a non-zero delay so we can cancel while streaming is in flight
        await service.setResponses([
            StreamDelta(text: "chunk one", finishReason: nil),
            StreamDelta(text: "chunk two", finishReason: nil),
        ])
        await service.setDelay(.milliseconds(200))

        let vm = QuickViewModel(service: service)
        vm.inputText = "Long running prompt"

        let submitTask = Task { await vm.submit() }
        // Give streaming a moment to start
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.isStreaming == true)

        vm.cancel()
        await submitTask.value

        #expect(vm.isStreaming == false)
    }

    // MARK: - 5. Service error surfaces in errorMessage

    @Test func testServiceErrorSetsErrorMessage() async throws {
        let service = MockQuickService()
        await service.setShouldThrow(true)

        let vm = QuickViewModel(service: service)
        vm.inputText = "This will fail"
        await vm.submit()

        #expect(vm.errorMessage != nil)
        #expect(vm.isStreaming == false)
    }

    // MARK: - 6. Update detection: newer remote version sets .updateAvailable

    @Test func testUpdateAvailableDetected() async throws {
        // QuickViewModel accepts a currentVersionProvider closure so the
        // version logic is fully testable without touching Info.plist.
        let vm = QuickViewModel(
            service: MockQuickService(),
            currentVersion: "1.0.0"
        )
        // Simulate the server reporting a newer version
        await vm.handleUpdateCheck(remoteVersion: "1.1.0")
        #expect(vm.updateState == .updateAvailable(newVersion: "1.1.0"))
    }
}

// MARK: - MockQuickService helpers (actor-isolated setters for @MainActor test context)

extension MockQuickService {
    func setResponses(_ value: [StreamDelta]) {
        responses = value
    }
    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }
    func setDelay(_ value: Duration) {
        delay = value
    }
}
