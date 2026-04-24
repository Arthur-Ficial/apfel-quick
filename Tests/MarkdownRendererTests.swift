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

    // MARK: - Dark-mode color correctness (issue #20)
    // Plain text rendered inside NSTextView defaults to raw black when no
    // `.foregroundColor` is set, which is invisible / near-invisible in dark
    // mode. The renderer must set `NSColor.labelColor` so the text adapts
    // to the current system appearance.

    @Test func testPlainTextUsesAdaptiveLabelColor() {
        let result = MarkdownRenderer.render("Hello world")
        let range = (result.string as NSString).range(of: "Hello world")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == NSColor.labelColor,
                "Plain text must use NSColor.labelColor so it stays visible in dark mode (issue #20)")
    }

    @Test func testBoldTextUsesAdaptiveLabelColor() {
        let result = MarkdownRenderer.render("This is **bold** text")
        let range = (result.string as NSString).range(of: "bold")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == NSColor.labelColor,
                "Bold text must use NSColor.labelColor so it stays visible in dark mode (issue #20)")
    }

    @Test func testHeadingUsesAdaptiveLabelColor() {
        let result = MarkdownRenderer.render("# A heading")
        let range = (result.string as NSString).range(of: "A heading")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == NSColor.labelColor,
                "Heading text must use NSColor.labelColor so it stays visible in dark mode (issue #20)")
    }

    @Test func testCodeBlockUsesAdaptiveLabelColor() {
        let result = MarkdownRenderer.render("""
        ```
        let x = 1
        ```
        """)
        let range = (result.string as NSString).range(of: "let x = 1")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == NSColor.labelColor,
                "Fenced code block text must use NSColor.labelColor so it stays visible in dark mode (issue #20)")
    }

    @Test func testInlineCodeUsesAdaptiveLabelColor() {
        let result = MarkdownRenderer.render("Use `let` for constants")
        let range = (result.string as NSString).range(of: "let")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == NSColor.labelColor,
                "Inline code must use NSColor.labelColor so it stays visible in dark mode (issue #20)")
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

    // MARK: - Tables

    @Test func testTableRendered() {
        let input = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("Name"))
        #expect(result.string.contains("Age"))
        #expect(result.string.contains("Alice"))
        #expect(result.string.contains("30"))
        #expect(result.string.contains("Bob"))
        #expect(result.string.contains("25"))
    }

    @Test func testTableHeaderIsBold() {
        let input = """
        | Header |
        |--------|
        | Cell |
        """
        let result = MarkdownRenderer.render(input)
        let headerRange = (result.string as NSString).range(of: "Header")
        let attrs = result.attributes(at: headerRange.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.fontDescriptor.symbolicTraits.contains(.bold))
    }

    @Test func testTableCellsAreSeparated() {
        let input = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let result = MarkdownRenderer.render(input)
        // Cells should be separated by tab or pipe
        let text = result.string
        #expect(text.contains("A"))
        #expect(text.contains("B"))
        #expect(text.contains("1"))
        #expect(text.contains("2"))
    }

    // MARK: - Block quotes

    @Test func testBlockQuoteRendered() {
        let input = """
        > This is a quote
        > with two lines
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("This is a quote"))
        #expect(result.string.contains("with two lines"))
    }

    @Test func testBlockQuoteHasForegroundColor() {
        let result = MarkdownRenderer.render("> Quoted text")
        let range = (result.string as NSString).range(of: "Quoted text")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color != nil)
    }

    @Test func testNestedBlockQuote() {
        let input = """
        > Outer
        > > Inner
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("Outer"))
        #expect(result.string.contains("Inner"))
    }

    // MARK: - Strikethrough

    @Test func testStrikethroughRendered() {
        let result = MarkdownRenderer.render("This is ~~deleted~~ text")
        #expect(result.string == "This is deleted text")
        let strikeRange = (result.string as NSString).range(of: "deleted")
        let attrs = result.attributes(at: strikeRange.location, effectiveRange: nil)
        let strikeStyle = attrs[.strikethroughStyle] as? Int
        #expect(strikeStyle != nil)
        #expect(strikeStyle! != 0)
    }

    // MARK: - Task lists (checkboxes)

    @Test func testTaskListChecked() {
        let input = """
        - [x] Done task
        - [ ] Todo task
        """
        let result = MarkdownRenderer.render(input)
        // Checked item should show a checkmark or filled box
        let text = result.string
        #expect(text.contains("Done task"))
        #expect(text.contains("Todo task"))
    }

    @Test func testTaskListMarkers() {
        let input = """
        - [x] Checked
        - [ ] Unchecked
        """
        let result = MarkdownRenderer.render(input)
        let text = result.string
        // Should have distinct markers for checked vs unchecked
        #expect(text.contains("\u{2611}") || text.contains("\u{2705}") || text.contains("[x]"))  // checked marker
        #expect(text.contains("\u{2610}") || text.contains("\u{25CB}") || text.contains("[ ]"))  // unchecked marker
    }

    // MARK: - Nested lists

    @Test func testNestedUnorderedList() {
        let input = """
        - Parent
          - Child
          - Child 2
        - Parent 2
        """
        let result = MarkdownRenderer.render(input)
        #expect(result.string.contains("Parent"))
        #expect(result.string.contains("Child"))
        #expect(result.string.contains("Child 2"))
        #expect(result.string.contains("Parent 2"))
    }

    // MARK: - Images (alt text only)

    @Test func testImageShowsAltText() {
        let result = MarkdownRenderer.render("![Screenshot](https://example.com/img.png)")
        #expect(result.string.contains("Screenshot"))
        // Should have an image marker
        #expect(result.string.contains("\u{1F5BC}"))
    }

    // MARK: - Bold + italic combined

    @Test func testBoldItalicCombined() {
        let result = MarkdownRenderer.render("This is ***bold italic*** text")
        #expect(result.string == "This is bold italic text")
        let range = (result.string as NSString).range(of: "bold italic")
        let attrs = result.attributes(at: range.location, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font!.fontDescriptor.symbolicTraits.contains(.bold))
        #expect(font!.fontDescriptor.symbolicTraits.contains(.italic))
    }

    // MARK: - Multiple paragraphs preserve separation

    @Test func testMultipleParagraphsSeparated() {
        let result = MarkdownRenderer.render("First paragraph.\n\nSecond paragraph.")
        let text = result.string
        #expect(text.contains("First paragraph."))
        #expect(text.contains("Second paragraph."))
        // Should have double newline between paragraphs
        #expect(text.contains("First paragraph.\n\nSecond paragraph."))
    }
}
