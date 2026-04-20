import SwiftUI
import AppKit

/// A button that, when clicked, captures the next key combo as the new hotkey.
struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt
    @State private var isRecording = false
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Hotkey")
                    .font(.system(size: 13))
                Spacer()
                if isRecording {
                    HotkeyCapture { captured in
                        let rawMods = captured.modifierFlags
                            .intersection(.deviceIndependentFlagsMask).rawValue
                        guard QuickSettings.isValidHotkey(
                            keyCode: captured.keyCode, modifiers: rawMods
                        ) else {
                            validationError = "Must include Ctrl, Option, or Cmd"
                            isRecording = false
                            return
                        }
                        keyCode = captured.keyCode
                        modifiers = rawMods
                        validationError = nil
                        isRecording = false
                        NotificationCenter.default.post(
                            name: .hotkeyChanged, object: nil)
                    } onCancel: {
                        isRecording = false
                    }
                    .frame(width: 160, height: 28)
                } else {
                    Button {
                        validationError = nil
                        isRecording = true
                    } label: {
                        Text(displayName)
                            .font(.system(size: 13, weight: .medium,
                                          design: .monospaced))
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let error = validationError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private var displayName: String {
        var s = QuickSettings()
        s.hotkeyKeyCode = keyCode
        s.hotkeyModifiers = modifiers
        return s.hotkeyDisplayName
    }
}

// MARK: - NSViewRepresentable key capture field

/// An invisible, first-responder NSView that grabs exactly one key-down event
/// and reports it back. Press Escape to cancel without changing the hotkey.
struct HotkeyCapture: NSViewRepresentable {
    var onCapture: (NSEvent) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureView {
        let view = HotkeyCaptureView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        // Become first responder on next runloop tick so the view is in the
        // window hierarchy.
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureView, context: Context) {}
}

final class HotkeyCaptureView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            onCancel?()
        } else {
            onCapture?(event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.1).setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        path.fill()
        let label = "Press a key combo..."
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let size = label.size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        label.draw(at: point, withAttributes: attrs)
    }
}
