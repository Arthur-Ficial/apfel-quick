import SwiftUI
import Combine

struct OverlayView: View {
    @Bindable var viewModel: QuickViewModel
    @FocusState private var inputFocused: Bool
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Input row
            HStack(spacing: 8) {
                TextField("Ask anything…", text: $viewModel.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.submit() } }
                    .disabled(viewModel.isStreaming)

                // Send button — works even if onSubmit doesn't fire on some panel setups
                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(viewModel.input.isEmpty && !viewModel.isStreaming)
                .help("Send (or press Return)")

                Button {
                    showSettings = true
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

            // Divider + result (only shown when there's output or streaming)
            if !viewModel.output.isEmpty || viewModel.isStreaming {
                Divider()
                ScrollView {
                    Text(viewModel.output + (viewModel.isStreaming ? "▋" : ""))
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(20)
                }
                .frame(maxHeight: 380)
                // Floating "copied" badge — overlaid top-right, doesn't push layout
                .overlay(alignment: .topTrailing) {
                    if viewModel.justCopied {
                        CopiedBadge()
                            .padding(.top, 10)
                            .padding(.trailing, 14)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.6).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: viewModel.justCopied)
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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { inputFocused = true }
        .onKeyPress(.escape) {
            if viewModel.isStreaming {
                viewModel.cancel()
            }
            // AppDelegate handles actual window dismissal
            NotificationCenter.default.post(name: .dismissOverlay, object: nil)
            return .handled
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
    }
}

extension Notification.Name {
    static let dismissOverlay = Notification.Name("ApfelQuick.dismissOverlay")
    static let openSettings = Notification.Name("ApfelQuick.openSettings")
}

// MARK: - Floating "Copied" badge (never pushes the response out of view)

private struct CopiedBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text("Copied")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(red: 0.22, green: 0.78, blue: 0.44),
                             Color(red: 0.14, green: 0.62, blue: 0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        )
    }
}
