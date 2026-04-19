import Foundation
import AppKit
import Markdown

/// Converts a markdown string to an NSAttributedString using swift-markdown's AST.
enum MarkdownRenderer {

    static func render(_ markdown: String) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }
        let document = Document(parsing: markdown)
        var walker = AttributedStringWalker()
        walker.visit(document)
        return walker.result
    }
}

// MARK: - AST Walker

private struct AttributedStringWalker: MarkupWalker {
    private let output = NSMutableAttributedString()
    private var fontTraits: NSFontDescriptor.SymbolicTraits = []
    private var isMonospace = false
    private var linkURL: URL?
    private var headingLevel: Int = 0
    private var listDepth: Int = 0
    private var orderedIndex: Int? = nil

    var result: NSAttributedString { output }

    // MARK: - Block elements

    mutating func visitHeading(_ heading: Heading) {
        if output.length > 0 { appendNewlines(2) }
        headingLevel = heading.level
        descendInto(heading)
        headingLevel = 0
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if output.length > 0 { appendNewlines(2) }
        descendInto(paragraph)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        if output.length > 0 { appendNewlines(2) }
        let code = codeBlock.code.hasSuffix("\n")
            ? String(codeBlock.code.dropLast())
            : codeBlock.code
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .backgroundColor: NSColor.secondarySystemFill,
        ]
        output.append(NSAttributedString(string: code, attributes: attrs))
    }

    mutating func visitUnorderedList(_ list: UnorderedList) {
        listDepth += 1
        descendInto(list)
        listDepth -= 1
    }

    mutating func visitOrderedList(_ list: OrderedList) {
        listDepth += 1
        orderedIndex = 1
        descendInto(list)
        orderedIndex = nil
        listDepth -= 1
    }

    mutating func visitListItem(_ item: ListItem) {
        if output.length > 0 { appendNewlines(1) }
        let indent = String(repeating: "  ", count: max(0, listDepth - 1))
        if let idx = orderedIndex {
            appendText("\(indent)\(idx). ")
            orderedIndex = idx + 1
        } else {
            appendText("\(indent)\u{2022} ")
        }
        descendInto(item)
    }

    // MARK: - Inline elements

    mutating func visitText(_ text: Markdown.Text) {
        appendText(text.string)
    }

    mutating func visitStrong(_ strong: Strong) {
        fontTraits.insert(.bold)
        descendInto(strong)
        fontTraits.remove(.bold)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        fontTraits.insert(.italic)
        descendInto(emphasis)
        fontTraits.remove(.italic)
    }

    mutating func visitInlineCode(_ code: InlineCode) {
        let prev = isMonospace
        isMonospace = true
        appendText(code.code)
        isMonospace = prev
    }

    mutating func visitLink(_ link: Markdown.Link) {
        if let dest = link.destination, let url = URL(string: dest) {
            linkURL = url
        }
        descendInto(link)
        linkURL = nil
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        appendText(" ")
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        appendNewlines(1)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        if output.length > 0 { appendNewlines(1) }
        appendText("---")
        appendNewlines(1)
    }

    // MARK: - Helpers

    private func appendText(_ text: String) {
        var attrs: [NSAttributedString.Key: Any] = [:]

        if isMonospace {
            attrs[.font] = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            attrs[.backgroundColor] = NSColor.secondarySystemFill
        } else if headingLevel > 0 {
            let size: CGFloat = headingLevel == 1 ? 20 : headingLevel == 2 ? 17 : 15
            var descriptor = NSFont.systemFont(ofSize: size, weight: .bold).fontDescriptor
            if fontTraits.contains(.italic) {
                descriptor = descriptor.withSymbolicTraits(
                    descriptor.symbolicTraits.union(.italic))
            }
            attrs[.font] = NSFont(descriptor: descriptor, size: size)
        } else {
            let weight: NSFont.Weight = fontTraits.contains(.bold) ? .bold : .regular
            let base = NSFont.systemFont(ofSize: 14, weight: weight)
            if fontTraits.contains(.italic) {
                let descriptor = base.fontDescriptor.withSymbolicTraits(
                    base.fontDescriptor.symbolicTraits.union(.italic))
                attrs[.font] = NSFont(descriptor: descriptor, size: 14)
            } else {
                attrs[.font] = base
            }
        }

        if let url = linkURL {
            attrs[.link] = url
            attrs[.foregroundColor] = NSColor.linkColor
        }

        output.append(NSAttributedString(string: text, attributes: attrs))
    }

    private func appendNewlines(_ count: Int) {
        let nl = String(repeating: "\n", count: count)
        output.append(NSAttributedString(string: nl, attributes: [
            .font: NSFont.systemFont(ofSize: 14)
        ]))
    }
}
