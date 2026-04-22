// BundledHelpersTests — every GUI release must ship its dependencies bundled.
//
// apfel-quick shells out to `apfel` for LLM inference. The .app bundle must
// include apfel in Contents/Helpers so users don't need a separate brew
// install. Failing to bundle is a release-blocking regression.

import Foundation
import Testing

@Suite("BundledHelpers")
struct BundledHelpersTests {
    private static let buildScript: String = {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // Tests/
        url.deleteLastPathComponent() // repo root
        url.appendPathComponent("scripts/build-app.sh")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    @Test("build-app.sh embeds the apfel helper")
    func apfelEmbedded() {
        #expect(
            Self.buildScript.contains("Contents/Helpers/apfel"),
            "build-app.sh must copy apfel into Contents/Helpers so users don't need a separate brew install"
        )
    }

    @Test("build-app.sh fails the build when apfel is missing on the host")
    func missingHelperFailsBuild() {
        #expect(
            Self.buildScript.contains("exit 1"),
            "build-app.sh must abort if the apfel helper can't be found — never ship a hollow bundle"
        )
    }

    @Test("build-app.sh signs the embedded helper before signing the bundle")
    func helperSigned() {
        #expect(
            Self.buildScript.contains("codesign_path \"$APP_BUNDLE/Contents/Helpers/apfel\""),
            "sign_bundle must sign Contents/Helpers/apfel before the outer bundle"
        )
    }

    @Test("build-app.sh embeds the ohr helper")
    func ohrEmbedded() {
        #expect(
            Self.buildScript.contains("Contents/Helpers/ohr"),
            "build-app.sh must copy ohr into Contents/Helpers — voice input needs ohr bundled, not a surprise brew dependency"
        )
    }

    @Test("build-app.sh signs ohr with the app's entitlements")
    func ohrSignedWithEntitlements() {
        #expect(
            Self.buildScript.contains("\"$APP_BUNDLE/Contents/Helpers/ohr\" --entitlements"),
            "sign_bundle must sign ohr with the parent app's entitlements so macOS TCC treats the spawned subprocess as part of the parent app for microphone grants"
        )
    }
}
