import SwiftUI
import AppKit

/// Displays an NSAttributedString in a non-editable, selectable NSTextView.
/// Used for markdown-rendered output in the overlay.
struct MarkdownTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let isStreaming: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let newAttr = NSMutableAttributedString(attributedString: attributedString)
        if isStreaming {
            let cursor = NSAttributedString(string: "\u{258B}", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor,
            ])
            newAttr.append(cursor)
        }
        if textView.attributedString() != newAttr {
            textView.textStorage?.setAttributedString(newAttr)
        }
    }
}
