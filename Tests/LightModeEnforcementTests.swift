// LightModeEnforcementTests — regression guard for issue #1.
//
// User-facing overlays must not mix a hardcoded `.background(.white)` with
// semantic foreground colors like `.foregroundStyle(.secondary)` while in
// dark mode, because that produces invisible text.
//
// After issue #10 the app supports a user-selectable appearance
// (system / light / dark). The invariant now is: each overlay view must
// either pin `.preferredColorScheme(.light)` explicitly, OR route its
// color scheme through `settings.appearance.swiftUIColorScheme` so the
// user stays in control AND the background is adaptive.
//
// https://github.com/Arthur-Ficial/apfel-quick/issues/1
// https://github.com/Arthur-Ficial/apfel-quick/issues/10

import Foundation
import Testing

@Suite("LightModeEnforcement")
struct LightModeEnforcementTests {
    private static let viewsDir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // Tests/
        url.deleteLastPathComponent() // repo root
        return url.appendingPathComponent("Sources/Views", isDirectory: true)
    }()

    private static let overlayViews = [
        "WelcomeOverlayView.swift",
        "SettingsView.swift",
        "OverlayView.swift",
    ]

    @Test("Every overlay view controls its color scheme (hardcoded light or settings-driven)",
          arguments: overlayViews)
    func viewControlsColorScheme(name: String) throws {
        let url = Self.viewsDir.appendingPathComponent(name)
        let source = try String(contentsOf: url, encoding: .utf8)
        let locksLight = source.contains(".preferredColorScheme(.light)")
        let usesAppearance = source.contains("appearance.swiftUIColorScheme")
        #expect(
            locksLight || usesAppearance,
            "\(name) must either pin `.preferredColorScheme(.light)` or route through `settings.appearance.swiftUIColorScheme` so dark-mode users don't see invisible text."
        )
    }

    @Test("Views that opt into user-driven appearance must use adaptive backgrounds",
          arguments: overlayViews)
    func adaptiveBackgroundWhenAppearanceDriven(name: String) throws {
        let url = Self.viewsDir.appendingPathComponent(name)
        let source = try String(contentsOf: url, encoding: .utf8)
        let usesAppearance = source.contains("appearance.swiftUIColorScheme")
        if usesAppearance {
            // Explicit white background while allowing dark mode would make
            // `.foregroundStyle(.secondary)` invisible (the original bug).
            // Allow `.background(.white)` only paired with a hardcoded
            // `.preferredColorScheme(.light)`.
            let hasWhiteBackground = source.contains(".background(.white)")
                || source.contains(".background(Color.white)")
            #expect(
                !hasWhiteBackground,
                "\(name) routes color scheme through settings but hardcodes `.background(.white)`. Use `Color(NSColor.windowBackgroundColor)` instead."
            )
        }
    }
}
