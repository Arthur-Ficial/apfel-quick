// ============================================================================
// DarkModeRenderProofTests.swift — Visual render proof for issue #20.
//
// Runs the REAL MarkdownRenderer against a realistic response, draws the
// resulting NSAttributedString into an NSImage under both .darkAqua and
// .aqua appearances, and writes PNGs to /tmp/apfel-quick-render-proof/
// plus asserts text pixels are visible against the background.
//
// CLI-driven: `swift test --filter DarkModeRenderProof` produces the PNGs.
// No overlay, no hotkey, no NSPanel required — runs in CI.
// ============================================================================

import Testing
import Foundation
import AppKit
@testable import apfel_quick

@Suite("DarkModeRenderProof")
struct DarkModeRenderProofTests {

    private static let outputDir = URL(fileURLWithPath: "/tmp/apfel-quick-render-proof")
    private static let sampleMarkdown = """
    # Dark mode render proof

    This is a response from the model, rendered by `MarkdownRenderer`.
    It contains **bold text**, *italic text*, a `code span`, and a
    second paragraph so we can sample multiple rows.

    - First bullet point
    - Second bullet point with a [link](https://example.com)

    > A block quote sits in secondary label color and should stay visible.
    """

    @Test func testRenderDarkAppearance() throws {
        let image = try Self.renderImage(appearanceName: .darkAqua)
        try Self.save(image, to: Self.outputDir.appendingPathComponent("dark.png"))
        try Self.assertTextIsVisible(image: image, isDark: true)
    }

    @Test func testRenderLightAppearance() throws {
        let image = try Self.renderImage(appearanceName: .aqua)
        try Self.save(image, to: Self.outputDir.appendingPathComponent("light.png"))
        try Self.assertTextIsVisible(image: image, isDark: false)
    }

    // MARK: - Helpers

    /// Asserts that the rendered image contains at least one pixel whose
    /// luminance differs from the background by a substantial margin.
    /// If `isDark` is true, we expect bright text against a dark background;
    /// otherwise dark text against a light background. Samples a 20x20 grid
    /// so we never miss a glyph just because the sample point landed in
    /// whitespace.
    private static func assertTextIsVisible(image: NSImage, isDark: Bool) throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            Issue.record("could not get bitmap rep")
            return
        }

        // Background sample: top-right corner, where no text is drawn.
        let bgX = Int(Double(rep.pixelsWide) * 0.97)
        let bgY = Int(Double(rep.pixelsHigh) * 0.03)
        let bgLum = rep.colorAt(x: bgX, y: bgY)?.luminance() ?? 0

        // Grid sample of the body area: left half, top 70%, 20x20 grid.
        var minLum = 1.0
        var maxLum = 0.0
        let gridStartX = Int(Double(rep.pixelsWide) * 0.05)
        let gridEndX = Int(Double(rep.pixelsWide) * 0.80)
        let gridStartY = Int(Double(rep.pixelsHigh) * 0.05)
        let gridEndY = Int(Double(rep.pixelsHigh) * 0.75)
        for x in stride(from: gridStartX, to: gridEndX, by: max(1, (gridEndX - gridStartX) / 20)) {
            for y in stride(from: gridStartY, to: gridEndY, by: max(1, (gridEndY - gridStartY) / 20)) {
                if let l = rep.colorAt(x: x, y: y)?.luminance() {
                    minLum = Swift.min(minLum, l)
                    maxLum = Swift.max(maxLum, l)
                }
            }
        }

        if isDark {
            #expect(bgLum < 0.3, "dark-mode bg luminance must be < 0.3 (was \(bgLum))")
            #expect(maxLum > bgLum + 0.4,
                    "dark-mode must contain pixels significantly brighter than bg (maxText=\(maxLum), bg=\(bgLum)) — text is invisible, issue #20 regressed")
        } else {
            #expect(bgLum > 0.7, "light-mode bg luminance must be > 0.7 (was \(bgLum))")
            #expect(minLum < bgLum - 0.4,
                    "light-mode must contain pixels significantly darker than bg (minText=\(minLum), bg=\(bgLum))")
        }
    }

    private static func renderImage(appearanceName: NSAppearance.Name) throws -> NSImage {
        guard let appearance = NSAppearance(named: appearanceName) else {
            throw NSError(domain: "RenderProof", code: 1, userInfo: [NSLocalizedDescriptionKey: "appearance unavailable"])
        }

        let attr = MarkdownRenderer.render(sampleMarkdown)
        let size = NSSize(width: 620, height: 320)
        let image = NSImage(size: size)

        appearance.performAsCurrentDrawingAppearance {
            image.lockFocus()
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: size).fill()

            let padding: CGFloat = 20
            let textRect = NSRect(
                x: padding,
                y: padding,
                width: size.width - padding * 2,
                height: size.height - padding * 2
            )
            attr.draw(in: textRect)
            image.unlockFocus()
        }
        return image
    }

    private static func save(_ image: NSImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "RenderProof", code: 2, userInfo: [NSLocalizedDescriptionKey: "could not encode PNG"])
        }
        try png.write(to: url)
    }
}

private extension NSColor {
    func luminance() -> Double {
        let c = self.usingColorSpace(.sRGB) ?? self
        return 0.2126 * Double(c.redComponent)
             + 0.7152 * Double(c.greenComponent)
             + 0.0722 * Double(c.blueComponent)
    }
}
