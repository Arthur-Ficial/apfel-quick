import SwiftUI
import AppKit

/// Tabbed, scrollable Settings window. Each tab is its own focused pane so
/// the view fits on a laptop display without clipping.
struct SettingsView: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        TabView {
            GeneralTab(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }

            SavedPromptsTab(viewModel: viewModel)
                .tabItem { Label("Prompts", systemImage: "text.quote") }

            VoiceTab(viewModel: viewModel)
                .tabItem { Label("Voice", systemImage: "mic") }

            MCPTab(viewModel: viewModel)
                .tabItem { Label("MCP", systemImage: "puzzlepiece.extension") }

            AboutTab(viewModel: viewModel)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 600, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(viewModel.settings.appearance.swiftUIColorScheme)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General").font(.headline)

                HotkeyRecorderView(
                    keyCode: $viewModel.settings.hotkeyKeyCode,
                    modifiers: $viewModel.settings.hotkeyModifiers
                )
                .onChange(of: viewModel.settings.hotkeyKeyCode) { _, _ in viewModel.settings.save() }
                .onChange(of: viewModel.settings.hotkeyModifiers) { _, _ in viewModel.settings.save() }

                Divider()

                Toggle("Copy result to clipboard automatically", isOn: $viewModel.settings.autoCopy)
                    .onChange(of: viewModel.settings.autoCopy) { _, _ in viewModel.settings.save() }

                Toggle("Launch at login", isOn: $viewModel.settings.launchAtLogin)
                    .onChange(of: viewModel.settings.launchAtLogin) { [weak viewModel] _, _ in
                        viewModel?.settings.save()
                        viewModel?.applyLaunchAtLogin()
                    }

                Toggle("Show menu bar icon", isOn: $viewModel.settings.showMenuBar)
                    .onChange(of: viewModel.settings.showMenuBar) { _, _ in viewModel.settings.save() }

                Toggle("Check for updates on launch", isOn: $viewModel.settings.checkForUpdatesOnLaunch)
                    .onChange(of: viewModel.settings.checkForUpdatesOnLaunch) { _, _ in viewModel.settings.save() }

                Toggle("Show welcome screen on next launch", isOn: Binding(
                    get: { !viewModel.settings.hasSeenWelcome },
                    set: { newValue in
                        viewModel.settings.hasSeenWelcome = !newValue
                        viewModel.settings.save()
                    }
                ))

                Divider()

                HStack {
                    Text("Appearance")
                    Spacer()
                    Picker("", selection: $viewModel.settings.appearance) {
                        ForEach(AppearancePreference.allCases, id: \.self) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .onChange(of: viewModel.settings.appearance) { _, _ in viewModel.settings.save() }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Prompts

private struct SavedPromptsTab: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SavedPromptsEditor(viewModel: viewModel)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Voice

private struct VoiceTab: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Voice input (ohr)").font(.headline)

                Toggle("Enable voice input", isOn: $viewModel.settings.voiceEnabled)
                    .onChange(of: viewModel.settings.voiceEnabled) { _, _ in viewModel.settings.save() }

                if viewModel.settings.voiceEnabled {
                    Divider()

                    HStack(spacing: 8) {
                        Text("Language")
                            .frame(width: 90, alignment: .leading)
                        TextField(
                            "en-US",
                            text: $viewModel.settings.voiceLanguage
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                        .onChange(of: viewModel.settings.voiceLanguage) { _, _ in viewModel.settings.save() }
                    }

                    HStack(spacing: 8) {
                        Text("ohr path")
                            .frame(width: 90, alignment: .leading)
                        TextField(
                            "auto-detect",
                            text: Binding(
                                get: { viewModel.settings.ohrBinaryPathOverride ?? "" },
                                set: { newValue in
                                    viewModel.settings.ohrBinaryPathOverride =
                                        newValue.isEmpty ? nil : newValue
                                    viewModel.settings.save()
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                viewModel.settings.ohrBinaryPathOverride = url.path
                                viewModel.settings.save()
                            }
                        }
                    }

                    Divider()

                    Text("How it works")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Tap the mic button in the overlay to start. apfel-quick spawns `ohr --listen -o json --language \(viewModel.settings.voiceLanguage)` and streams decoded segments into the input as you speak. Tap the mic again to stop.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("If you see an 'ohr not found' error, install it with:\n  brew install Arthur-Ficial/tap/ohr")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - MCP

private struct MCPTab: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MCPServersEditor(viewModel: viewModel)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - About

private struct AboutTab: View {
    @Bindable var viewModel: QuickViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("apfel-quick")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Version \(viewModel.currentVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    updateStatusView
                    Spacer()
                    Button("Check for update") {
                        Task { await viewModel.checkForUpdateManual() }
                    }
                    .disabled(viewModel.updateState == .checking)
                }

                Divider()

                Link(
                    "Source on GitHub",
                    destination: URL(string: "https://github.com/Arthur-Ficial/apfel-quick")!
                )
                .font(.system(size: 12))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch viewModel.updateState {
        case .checking:
            Text("Checking…").font(.system(size: 12)).foregroundStyle(.secondary)
        case .upToDate:
            Text("Up to date").font(.system(size: 12)).foregroundStyle(.green)
        case .updateAvailable(let v):
            Button("Update to \(v)") { [weak viewModel] in viewModel?.installUpdate() }
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        case .installing(let v):
            Text("Installing \(v)…").font(.system(size: 12)).foregroundStyle(.secondary)
        case .installed(let v):
            Text("Installed \(v)").font(.system(size: 12)).foregroundStyle(.green)
        case .error(let msg):
            Text(msg).font(.system(size: 12)).foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }
}
