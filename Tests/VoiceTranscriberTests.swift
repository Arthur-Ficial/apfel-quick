import Testing
import Foundation
@testable import apfel_quick

/// TDD coverage for ohr-based voice transcription (issue #12).
///
/// Spec (validated against ohr 0.1.6):
/// - VoiceTranscriber (actor) spawns `ohr --listen -o json --language <code> --quiet`.
/// - Each stdout line is a JSON `{id, start, end, text}` object it decodes
///   into `VoiceSegment` and yields on the `segments` AsyncStream.
/// - Errors surface as typed `VoiceTranscriberError`.
/// - QuickSettings gates the feature and holds an optional binary override
///   plus the language code passed to ohr.
///
/// Note: --listen requires an interactive terminal OR a non-plain output
/// format. From a subprocess pipe we have no TTY, so `-o json` is mandatory
/// (not decorative). The unit tests below exercise the JSON-parse path via
/// a fake ohr binary; the full round-trip with real ohr + a real mic lives
/// in a separate manual test because it needs audio input.

/// Stub permission that unconditionally reports authorized. Used by tests
/// that exercise subprocess behavior without dragging the real TCC prompt
/// into CI.
struct AlwaysGrantedMicrophonePermission: MicrophonePermissionRequesting {
    func currentStatus() -> MicrophoneAuthorizationStatus { .authorized }
    func requestAccess() async -> MicrophoneAuthorizationStatus { .authorized }
}

/// Stub permission that reports a fixed status. Used to exercise the
/// permission-denied branch.
struct FixedMicrophonePermission: MicrophonePermissionRequesting {
    let status: MicrophoneAuthorizationStatus
    func currentStatus() -> MicrophoneAuthorizationStatus { status }
    func requestAccess() async -> MicrophoneAuthorizationStatus { status }
}

@Suite("VoiceTranscriber")
struct VoiceTranscriberTests {

    @Test func testStartThrowsWhenBinaryNotFound() async {
        let t = VoiceTranscriber(
            binaryFinder: { nil },
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        do {
            try await t.start()
            Issue.record("expected throw")
        } catch let error as VoiceTranscriberError {
            #expect(error == .binaryNotFound)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func testStartThrowsWhenMicrophoneDenied() async {
        // Even if the ohr binary is present, we refuse to spawn it without
        // mic permission — silently spawning a doomed child process would
        // leave the UI "recording" forever.
        let t = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            baseArgsOverride: ["5"],
            micPermission: FixedMicrophonePermission(status: .denied)
        )
        do {
            try await t.start()
            Issue.record("expected throw")
        } catch let error as VoiceTranscriberError {
            #expect(error == .microphoneDenied)
        } catch {
            Issue.record("wrong error: \(error)")
        }
        #expect(await t.isRunning == false)
    }

    @Test func testStartThrowsWhenMicrophoneRestricted() async {
        let t = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            baseArgsOverride: ["5"],
            micPermission: FixedMicrophonePermission(status: .restricted)
        )
        do {
            try await t.start()
            Issue.record("expected throw")
        } catch let error as VoiceTranscriberError {
            #expect(error == .microphoneRestricted)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func testStopWhenNotStartedIsNoOp() async {
        let t = VoiceTranscriber(
            binaryFinder: { "/nonexistent" },
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        await t.stop()
        #expect(await t.isRunning == false)
    }

    @Test func testStartThrowsWhenSpawnFails() async {
        // /etc/hosts exists but is not executable. Process.run() fails.
        let t = VoiceTranscriber(
            binaryFinder: { "/etc/hosts" },
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        do {
            try await t.start()
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

    @Test func testStdoutJSONSegmentsAreDecodedAndYielded() async throws {
        // Fake ohr: a shell script printing a fixed JSON stream to stdout.
        // This exercises the full parse pipeline without needing real ohr.
        let scriptURL = try makeFakeOhr(stdoutLines: [
            #"{"id":0,"start":0,"end":0.5,"text":"hello"}"#,
            #"{"id":1,"start":0.5,"end":1.0,"text":" world"}"#,
        ])
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let t = VoiceTranscriber(
            binaryFinder: { scriptURL.path },
            baseArgsOverride: [],
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()

        var texts: [String] = []
        let deadline = Date().addingTimeInterval(3.0)
        for await seg in await t.segments {
            texts.append(seg.text)
            if texts.count >= 2 { break }
            if Date() > deadline { break }
        }
        await t.stop()

        #expect(texts == ["hello", " world"])
    }

    @Test func testIsRunningReflectsLifecycle() async throws {
        let t = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            baseArgsOverride: ["5"],
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()
        #expect(await t.isRunning == true)
        await t.stop()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await t.isRunning == false)
    }

    @Test func testDoubleStopIsSafe() async throws {
        let t = VoiceTranscriber(
            binaryFinder: { "/bin/sleep" },
            baseArgsOverride: ["5"],
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()
        await t.stop()
        await t.stop()
    }

    @Test func testBadJSONLinesAreSilentlyIgnored() async throws {
        // Mixed stream: nonsense, then one valid segment, then more nonsense.
        let scriptURL = try makeFakeOhr(stdoutLines: [
            "not-json-at-all",
            #"{"id":0,"start":0,"end":1,"text":"hi"}"#,
            "also-not-json",
        ])
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let t = VoiceTranscriber(
            binaryFinder: { scriptURL.path },
            baseArgsOverride: [],
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()

        var texts: [String] = []
        let deadline = Date().addingTimeInterval(3.0)
        for await seg in await t.segments {
            texts.append(seg.text)
            if Date() > deadline { break }
        }
        await t.stop()

        #expect(texts == ["hi"])
    }

    @Test func testDefaultArgumentsMatchOhrInvocationContract() async throws {
        // Spawn a fake ohr that echoes its own argv to stdout (one per line)
        // as JSON segments with text equal to each arg. Confirms the
        // transcriber actually passes the documented flag set.
        let scriptURL = try makeArgvEchoingFakeOhr()
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let t = VoiceTranscriber(
            binaryFinder: { scriptURL.path },
            language: "de-DE",
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()

        var receivedArgs: [String] = []
        let deadline = Date().addingTimeInterval(3.0)
        for await seg in await t.segments {
            receivedArgs.append(seg.text)
            if Date() > deadline { break }
        }
        await t.stop()

        #expect(receivedArgs.contains("--listen"))
        #expect(receivedArgs.contains("-o"))
        #expect(receivedArgs.contains("json"))
        #expect(receivedArgs.contains("--language"))
        #expect(receivedArgs.contains("de-DE"))
        #expect(receivedArgs.contains("--quiet"))
    }
}

@Suite("VoiceSegment JSON")
struct VoiceSegmentTests {

    @Test func testDecodeMatchesOhrWireFormat() throws {
        let json = #"{"id":0,"start":0,"end":0.42,"text":"The quick"}"#
        let seg = try JSONDecoder().decode(VoiceSegment.self, from: Data(json.utf8))
        #expect(seg.id == 0)
        #expect(seg.start == 0.0)
        #expect(seg.end == 0.42)
        #expect(seg.text == "The quick")
    }

    @Test func testDecodeHandlesIntegerStartEnd() throws {
        // ohr emits `"start":0` (integer) for segments that start at 0.
        let json = #"{"id":3,"start":0,"end":1,"text":" brown fox"}"#
        let seg = try JSONDecoder().decode(VoiceSegment.self, from: Data(json.utf8))
        #expect(seg.start == 0.0)
        #expect(seg.end == 1.0)
    }

    @Test func testDecodeHandlesUnicodeInText() throws {
        let json = #"{"id":1,"start":0,"end":1,"text":"café 🚀"}"#
        let seg = try JSONDecoder().decode(VoiceSegment.self, from: Data(json.utf8))
        #expect(seg.text == "café 🚀")
    }

    @Test func testDecodeRejectsMissingFields() {
        let json = #"{"id":0,"text":"no timestamps"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(VoiceSegment.self, from: Data(json.utf8))
        }
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

    @Test func testDefaultVoiceLanguage() {
        let s = QuickSettings()
        #expect(s.voiceLanguage == "en-US")
    }

    @Test func testVoiceFieldsRoundTrip() throws {
        var s = QuickSettings()
        s.voiceEnabled = false
        s.ohrBinaryPathOverride = "/opt/homebrew/bin/ohr"
        s.voiceLanguage = "de-DE"
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(QuickSettings.self, from: data)
        #expect(back.voiceEnabled == false)
        #expect(back.ohrBinaryPathOverride == "/opt/homebrew/bin/ohr")
        #expect(back.voiceLanguage == "de-DE")
    }

    @Test func testLegacyBlobDecodes() throws {
        let legacy = #"""
        {"hotkeyKeyCode":49,"hotkeyModifiers":524288,"autoCopy":true,"launchAtLogin":true,"showMenuBar":true,"checkForUpdatesOnLaunch":true,"hasSeenWelcome":true,"launchAtLoginPromptShown":true}
        """#
        let s = try JSONDecoder().decode(QuickSettings.self, from: Data(legacy.utf8))
        #expect(s.voiceEnabled == true)
        #expect(s.ohrBinaryPathOverride == nil)
        #expect(s.voiceLanguage == "en-US")
    }
}

// MARK: - Test helpers

/// Write a shell script that prints the given lines to stdout, each followed
/// by a newline, and exits. Make it executable and return its URL.
private func makeFakeOhr(stdoutLines: [String]) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("voice-fake-ohr-\(UUID().uuidString).sh")
    let body = stdoutLines
        .map { "printf '%s\\n' '\($0.replacingOccurrences(of: "'", with: "'\\''"))'" }
        .joined(separator: "\n")
    let script = "#!/bin/sh\n\(body)\n"
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

/// Fake ohr that re-emits every argv entry as a VoiceSegment JSON line.
/// Used to verify the transcriber passes the expected flags.
private func makeArgvEchoingFakeOhr() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("voice-argv-echo-\(UUID().uuidString).sh")
    let script = #"""
    #!/bin/sh
    i=0
    for a in "$@"; do
      esc=$(printf '%s' "$a" | sed 's/\\/\\\\/g; s/"/\\"/g')
      printf '{"id":%d,"start":0,"end":0.1,"text":"%s"}\n' "$i" "$esc"
      i=$((i + 1))
    done
    """#
    try script.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}
