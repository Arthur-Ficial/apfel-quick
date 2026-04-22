import Testing
import Foundation
@testable import apfel_quick

/// TDD (RED) for ohr-based voice transcription (issue #12).
///
/// Spec:
/// - `VoiceTranscriber` is an actor managing an `ohr --listen` subprocess.
/// - `start()` throws if the ohr binary cannot be found.
/// - While running, stdout lines are pushed into an AsyncStream<String>.
/// - `stop()` terminates the process; double-stop is a no-op.
/// - `QuickSettings.voiceEnabled` (default true) gates the feature in the UI.

@Suite("VoiceTranscriber")
struct VoiceTranscriberTests {

    @Test func testStartThrowsWhenBinaryNotFound() async {
        let transcriber = VoiceTranscriber(binaryFinder: { nil })
        do {
            try await transcriber.start()
            Issue.record("expected throw")
        } catch let error as VoiceTranscriberError {
            #expect(error == .binaryNotFound)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func testStopWhenNotStartedIsNoOp() async {
        let transcriber = VoiceTranscriber(binaryFinder: { "/nonexistent" })
        await transcriber.stop()
        let running = await transcriber.isRunning
        #expect(running == false)
    }

    @Test func testStartThrowsWhenSpawnFails() async {
        // /etc/hosts exists but is not executable. Process.run() fails.
        let transcriber = VoiceTranscriber(binaryFinder: { "/etc/hosts" })
        do {
            try await transcriber.start()
            Issue.record("expected throw")
        } catch let error as VoiceTranscriberError {
            guard case .spawnFailed = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test func testLinesStreamYieldsStdoutLines() async throws {
        // /bin/echo writes one line and exits. It's a reasonable stand-in
        // for a subprocess whose stdout we want to consume.
        let transcriber = VoiceTranscriber(
            binaryFinder: { "/bin/echo" },
            extraArgs: ["hello world"]
        )
        try await transcriber.start()
        var collected: [String] = []
        for await line in await transcriber.lines {
            collected.append(line)
            if collected.count >= 1 { break }
        }
        await transcriber.stop()
        #expect(collected.first == "hello world")
    }

    @Test func testIsRunningReflectsLifecycle() async throws {
        let transcriber = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            extraArgs: ["5"]
        )
        try await transcriber.start()
        #expect(await transcriber.isRunning == true)
        await transcriber.stop()
        // Give the kernel a moment to reap the process.
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await transcriber.isRunning == false)
    }

    @Test func testDoubleStopIsSafe() async throws {
        let transcriber = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            extraArgs: ["5"]
        )
        try await transcriber.start()
        await transcriber.stop()
        await transcriber.stop()
    }
}

@Suite("QuickSettings voice")
struct QuickSettingsVoiceTests {

    @Test func testDefaultVoiceEnabled() {
        let s = QuickSettings()
        #expect(s.voiceEnabled == true)
    }

    @Test func testDefaultOhrPathIsNil() {
        let s = QuickSettings()
        #expect(s.ohrBinaryPathOverride == nil)
    }

    @Test func testVoiceFieldsRoundTrip() throws {
        var s = QuickSettings()
        s.voiceEnabled = false
        s.ohrBinaryPathOverride = "/opt/homebrew/bin/ohr"
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuickSettings.self, from: data)
        #expect(back.voiceEnabled == false)
        #expect(back.ohrBinaryPathOverride == "/opt/homebrew/bin/ohr")
    }

    @Test func testLegacyBlobDecodes() throws {
        let legacy = #"""
        {"hotkeyKeyCode":49,"hotkeyModifiers":524288,"autoCopy":true,"launchAtLogin":true,"showMenuBar":true,"checkForUpdatesOnLaunch":true,"hasSeenWelcome":true,"launchAtLoginPromptShown":true}
        """#
        let s = try JSONDecoder().decode(QuickSettings.self, from: Data(legacy.utf8))
        #expect(s.voiceEnabled == true)
        #expect(s.ohrBinaryPathOverride == nil)
    }
}
