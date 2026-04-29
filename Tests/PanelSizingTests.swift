import Testing
import Foundation
@testable import apfel_quick

@Suite("PanelSizing")
struct PanelSizingTests {

    // MARK: - Idle (collapsed)

    @Test func testIdleHeightIsInputOnly() {
        let h = PanelSizing.panelHeight(output: "", isStreaming: false, errorMessage: nil)
        #expect(h == 60)
    }

    // MARK: - Streaming with no output yet

    @Test func testStreamingEmptyOutputAddsBody() {
        let h = PanelSizing.panelHeight(output: "", isStreaming: true, errorMessage: nil)
        // approxLines = max(1, 0/60 + 1) = 1
        // body = min(380, 22 + 40) = 62
        // total = 60 + 62
        #expect(h == 122)
    }

    // MARK: - Output present, not streaming

    @Test func testShortOutputUsesOneLine() {
        let h = PanelSizing.panelHeight(output: "hello", isStreaming: false, errorMessage: nil)
        #expect(h == 122)
    }

    @Test func testLongOutputCapsAtMaxBodyHeight() {
        // 10 000 chars -> approxLines ~ 167 -> 167*22+40 well past 380, so capped
        let long = String(repeating: "x", count: 10_000)
        let h = PanelSizing.panelHeight(output: long, isStreaming: false, errorMessage: nil)
        #expect(h == CGFloat(60 + 380))
    }

    // MARK: - Error banner adds 40

    @Test func testErrorBannerAddsFourtyOnTopOfIdle() {
        let h = PanelSizing.panelHeight(output: "", isStreaming: false, errorMessage: "boom")
        #expect(h == 100)
    }

    @Test func testErrorBannerStacksWithOutput() {
        let h = PanelSizing.panelHeight(output: "hi", isStreaming: false, errorMessage: "boom")
        #expect(h == 162)
    }

    // MARK: - Idempotence: same inputs -> same output

    @Test func testPureFunctionIsIdempotent() {
        let a = PanelSizing.panelHeight(output: "abc", isStreaming: true, errorMessage: nil)
        let b = PanelSizing.panelHeight(output: "abc", isStreaming: true, errorMessage: nil)
        #expect(a == b)
    }
}
