import SwiftUI
import Combine

struct OverlayView: View {
    @Bindable var viewModel: QuickViewModel
    @FocusState private var inputFocused: Bool
    /// The send button icon and color change based on state:
    ///  - idle: arrow.up.circle.fill (purple)
    ///  - streaming: stop.fill (purple)
    ///  - justCopied: checkmark.circle.fill (green, 2s)
    private var sendIcon: String {
        if viewModel.justCopied { return "checkmark.circle.fill" }
        if viewModel.isStreaming { return "stop.fill" }
        return "arrow.up.circle.fill"
    }

    private var sendColor: Color {
        viewModel.justCopied
            ? Color(red: 0.18, green: 0.72, blue: 0.36)
            : Color(red: 0.55, green: 0.36, blue: 0.96)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Input row
            HStack(spacing: 8) {
                TextField("Ask anything…", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.submit() } }
                    .disabled(viewModel.isStreaming)

                // Voice (ohr) mic button — hidden when the user disables voice in settings
                if viewModel.settings.voiceEnabled {
                    Button {
                        Task { await viewModel.toggleVoice() }
                    } label: {
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                            .foregroundStyle(
                                viewModel.isRecording
                                    ? Color(red: 0.90, green: 0.25, blue: 0.25)
                                    : Color.secondary
                            )
                            .font(.system(size: 16))
                            .symbolEffect(.pulse, isActive: viewModel.isRecording)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.isRecording ? "Stop listening" : "Voice (ohr)")
                }

                // Send / stop / copied indicator — same slot, different icon
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: sendIcon)
                        .foregroundStyle(sendColor)
                        .font(.system(size: 20))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(viewModel.input.isEmpty && !viewModel.isStreaming)
                .help(viewModel.justCopied ? "Copied to clipboard" : "Send (or press Return)")

                Button {
                    NotificationCenter.default.post(
                        name: .openSettings, object: nil)
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Saved-prompt autocomplete
            if !viewModel.savedPromptMatches.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.savedPromptMatches) { match in
                        Button {
                            viewModel.complete(savedPrompt: match)
                        } label: {
                            HStack(spacing: 10) {
                                Text(viewModel.settings.savedPromptPrefix + match.alias)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                                Text(match.prompt)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Divider + result (only shown when there's output or streaming)
            if !viewModel.output.isEmpty || viewModel.isStreaming {
                Divider()
                MarkdownTextView(
                    attributedString: MarkdownRenderer.render(viewModel.output),
                    isStreaming: viewModel.isStreaming
                )
                .frame(maxHeight: 380)
                .padding(20)
            }

            // Error message
            if let error = viewModel.errorMessage {
                Divider()
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .preferredColorScheme(viewModel.settings.appearance.swiftUIColorScheme)
        .onAppear { inputFocused = true }
        .onKeyPress(.escape) {
            if viewModel.isStreaming {
                viewModel.cancel()
            }
            NotificationCenter.default.post(name: .dismissOverlay, object: nil)
            return .handled
        }
    }
}

extension Notification.Name {
    static let dismissOverlay = Notification.Name("ApfelQuick.dismissOverlay")
    static let openSettings = Notification.Name("ApfelQuick.openSettings")
    static let hotkeyChanged = Notification.Name("ApfelQuick.hotkeyChanged")
}
