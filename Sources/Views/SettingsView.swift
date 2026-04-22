import SwiftUI
import AppKit  // for NSEvent.ModifierFlags

struct SettingsView: View {
    @Bindable var viewModel: QuickViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
            }

            Divider()

            // Hotkey
            HotkeyRecorderView(
                keyCode: $viewModel.settings.hotkeyKeyCode,
                modifiers: $viewModel.settings.hotkeyModifiers
            )
            .onChange(of: viewModel.settings.hotkeyKeyCode) { _, _ in
                viewModel.settings.save()
            }
            .onChange(of: viewModel.settings.hotkeyModifiers) { _, _ in
                viewModel.settings.save()
            }

            Divider()

            SavedPromptsEditor(viewModel: viewModel)

            Divider()

            // Auto-copy
            Toggle("Copy result to clipboard automatically", isOn: $viewModel.settings.autoCopy)
                .onChange(of: viewModel.settings.autoCopy) { _, _ in viewModel.settings.save() }

            // Launch at login
            Toggle("Launch at login", isOn: $viewModel.settings.launchAtLogin)
                .onChange(of: viewModel.settings.launchAtLogin) { [weak viewModel] _, _ in
                    viewModel?.settings.save()
                    viewModel?.applyLaunchAtLogin()
                }

            // Show in menu bar
            Toggle("Show menu bar icon", isOn: $viewModel.settings.showMenuBar)
                .onChange(of: viewModel.settings.showMenuBar) { _, _ in viewModel.settings.save() }

            // Check for updates on launch
            Toggle("Check for updates on launch", isOn: $viewModel.settings.checkForUpdatesOnLaunch)
                .onChange(of: viewModel.settings.checkForUpdatesOnLaunch) { _, _ in viewModel.settings.save() }

            // Show welcome screen on next launch
            Toggle("Show welcome screen on next launch", isOn: Binding(
                get: { !viewModel.settings.hasSeenWelcome },
                set: { newValue in
                    viewModel.settings.hasSeenWelcome = !newValue
                    viewModel.settings.save()
                }
            ))

            Divider()

            // Update status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version \(viewModel.currentVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    updateStatusView
                }
                Spacer()
                Button("Check for Update") {
                    Task { await viewModel.checkForUpdateManual() }
                }
                .disabled(viewModel.updateState == .checking)
            }

            Spacer()

            // GitHub link
            HStack {
                Spacer()
                Link("View on GitHub", destination: URL(string: "https://github.com/Arthur-Ficial/apfel-quick")!)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(28)
        .frame(width: 560, height: 780)
        .background(.white)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch viewModel.updateState {
        case .checking:
            Text("Checking…").font(.system(size: 11)).foregroundStyle(.secondary)
        case .upToDate:
            Text("Up to date").font(.system(size: 11)).foregroundStyle(.green)
        case .updateAvailable(let v):
            Button("Update to \(v)") { [weak viewModel] in viewModel?.installUpdate() }
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        case .installing(let v):
            Text("Installing \(v)…").font(.system(size: 11)).foregroundStyle(.secondary)
        case .installed(let v):
            Text("Installed \(v)").font(.system(size: 11)).foregroundStyle(.green)
        case .error(let msg):
            Text(msg).font(.system(size: 11)).foregroundStyle(.red)
        case .idle:
            EmptyView()
        }
    }
}
