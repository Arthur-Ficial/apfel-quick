import Testing
import Foundation
import AppKit
@testable import apfel_quick

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    // MARK: - Plain text passthrough

    @Test func testPlainTextUnchanged() {
        let result = MarkdownRenderer.render("Hello world")
        #expect(result.string == "Hello world")
    }

    // MARK: - Bold

    @Test func testBoldRendered() {
        let result = MarkdownRenderer.render("This is **bold** text")
        #expect(result.string == "This is bold text")
        let boldRange = (result.string as NSString).range(of: "bold")
        let attrs = result.attributes(at: boldRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.fontDescriptor.symbolicTraits.contains(.bold))
    }

    // MARK: - Italic

    @Test func testItalicRendered() {
        let result = MarkdownRenderer.render("This is *italic* text")
        #expect(result.string == "This is italic text")
        let italicRange = (result.string as NSString).range(of: "italic")
        let attrs = result.attributes(at: italicRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.fontDescriptor.symbolicTraits.contains(.italic))
    }

    // MARK: - Inline code

    @Test func testInlineCodeRendered() {
        let result = MarkdownRenderer.render("Use `print()` here")
        #expect(result.string == "Use print() here")
        let codeRange = (result.string as NSString).range(of: "print()")
        let attrs = result.attributes(at: codeRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.isFixedPitch)
    }

    // MARK: - Code blocks

    @Test func testCodeBlockRendered() {
        let input = """
        Here is code:

        ```swift
        let x = 42
        ```

        Done.
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("let x = 42"))
        let codeRange = (result.string as NSString).range(of: "let x = 42")
        let attrs = result.attributes(at: codeRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.isFixedPitch)
    }

    // MARK: - Headings

    @Test func testHeadingRendered() {
        let result = MarkdownRenderer.render("# Title\n\nBody text")
        #expect(result.string.contains("Title"))
        #expect(result.string.contains("Body text"))
        let titleRange = (result.string as NSString).range(of: "Title")
        let attrs = result.attributes(at: titleRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.pointSize > 14)
    }

    // MARK: - Lists

    @Test func testUnorderedListRendered() {
        let input = """
        Items:

        - First
        - Second
        - Third
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("First"))
        #expect(result.string.contains("Second"))
        #expect(result.string.contains("Third"))
    }

    @Test func testOrderedListRendered() {
        let input = """
        Steps:

        1. First
        2. Second
        3. Third
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("First"))
        #expect(result.string.contains("Second"))
    }

    // MARK: - Links

    @Test func testLinkRendered() {
        let result = MarkdownRenderer.render("Visit [Apple](https://apple.com)")
        #expect(result.string.contains("Apple"))
        let linkRange = (result.string as NSString).range(of: "Apple")
        let attrs = result.attributes(at: linkRange.location, effectiveRange: nil)
        let link = attrs[.link]
        #expect(link != nil)
    }

    // MARK: - Empty / whitespace

    @Test func testEmptyStringReturnsEmpty() {
        let result = MarkdownRenderer.render("")
        #expect(result.string == "")
    }

    // MARK: - Partial / streaming markdown

    @Test func testUnclosedBoldDoesNotCrash() {
        let result = MarkdownRenderer.render("This is **bold but uncl")
        #expect(result.string.contains("bold"))
    }

    @Test func testUnclosedCodeBlockDoesNotCrash() {
        let result = MarkdownRenderer.render("```swift\nlet x = 1\n")
        #expect(result.string.contains("let x = 1"))
    }

    // MARK: - Thematic break

    @Test func testThematicBreak() {
        let result = MarkdownRenderer.render("Above\n\n---\n\nBelow")
        #expect(result.string.contains("Above"))
        #expect(result.string.contains("Below"))
    }
}
