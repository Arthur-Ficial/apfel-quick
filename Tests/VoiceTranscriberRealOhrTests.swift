import Testing
import Foundation
import ApfelServerKit
@testable import apfel_quick

/// Real-ohr integration: spawn the actual `ohr` binary against a bundled
/// audio fixture and confirm VoiceTranscriber's JSON parser decodes the
/// real wire format.
///
/// apfel-chat never exercised this - their inline `--mic` flag isn't even
/// supported by ohr 0.1.6. This test proves our invocation and our parser
/// both match reality.
///
/// The test self-disables when /opt/homebrew/bin/ohr is not installed so
/// CI on machines without ohr is not red. Local dev boxes where ohr lives
/// run it as a hard integration check.

@Suite("VoiceTranscriber real ohr (integration)")
struct VoiceTranscriberRealOhrTests {

    private static func ohrPath() -> String? {
        ApfelBinaryFinder.find(name: "ohr")
    }

    private static func fixtureURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // Tests/
        url.appendPathComponent("Fixtures")
        url.appendPathComponent("hello.m4a")
        return url
    }

    @Test func testRealOhrProducesDecodableJSONForFileMode() async throws {
        guard let ohr = Self.ohrPath() else {
            Issue.record("ohr not installed - skipping integration test. Install with: brew install Arthur-Ficial/tap/ohr")
            return
        }
        let fixture = Self.fixtureURL()
        guard FileManager.default.fileExists(atPath: fixture.path) else {
            Issue.record("fixture missing at \(fixture.path)")
            return
        }

        // Spawn ohr with `-o json <file>`. For file-mode ohr emits a SINGLE
        // JSON object (not a stream of lines), so we intercept stdout
        // manually instead of going through VoiceTranscriber's line reader.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ohr)
        proc.arguments = ["-o", "json", fixture.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        #expect(!data.isEmpty, "ohr produced no stdout for fixture")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil, "ohr output was not valid JSON")

        // File-mode ohr returns `{duration, language, metadata, model,
        // segments, text}`. We confirm the segment shape matches what
        // VoiceSegment expects by re-encoding a segment and decoding it.
        let segments = json?["segments"] as? [[String: Any]]
        #expect(segments != nil)
        #expect(segments!.count >= 1)
        let firstSegment = segments![0]
        let segData = try JSONSerialization.data(withJSONObject: firstSegment)
        let seg = try JSONDecoder().decode(VoiceSegment.self, from: segData)
        #expect(seg.text.count > 0, "empty text in segment: \(firstSegment)")
    }

    @Test func testRealOhrListenFlagIsAccepted() async throws {
        guard let ohr = Self.ohrPath() else {
            Issue.record("ohr not installed - skipping integration test")
            return
        }
        // Spawn with our production args + have our VoiceTranscriber manage
        // the lifecycle. If ohr rejects any of the flags we pass (say,
        // because someone "learned from apfel-chat" and added `--mic`),
        // the process will exit immediately with a non-zero status and
        // isRunning will flip to false before the stop() call.
        let t = VoiceTranscriber(
            binaryFinder: { ohr },
            language: "en-US",
            micPermission: AlwaysGrantedMicrophonePermission()
        )
        try await t.start()
        // Give ohr a beat to reject invalid flags if it's going to.
        try? await Task.sleep(for: .milliseconds(400))
        let stillRunning = await t.isRunning
        await t.stop()
        #expect(stillRunning, "ohr exited immediately - our argv is wrong for this ohr version")
    }
}
