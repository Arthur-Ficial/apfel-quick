import SwiftUI
import AppKit

/// Settings pane for enabling / disabling MCP servers attached to the
/// embedded apfel process. Changes take effect on the next app launch
/// (or on the next time the server is restarted) since they are passed
/// as command-line arguments to `apfel --serve`.
struct MCPServersEditor: View {
    @Bindable var viewModel: QuickViewModel
    @State private var selection: MCPServerConfig.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MCP Servers")
                    .font(.headline)
                Spacer()
                Text("Applied on next launch")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if viewModel.settings.mcpServers.isEmpty {
                Text("No MCP servers configured. Click + to add a local MCP script or binary.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                Table(viewModel.settings.mcpServers, selection: $selection) {
                    TableColumn("On") { config in
                        Toggle("", isOn: bindingForEnabled(config.id))
                            .labelsHidden()
                    }
                    .width(40)
                    TableColumn("Name") { config in
                        TextField("name", text: bindingForName(config.id))
                            .textFieldStyle(.plain)
                    }
                    .width(min: 80, max: 140)
                    TableColumn("Path") { config in
                        TextField("/path/to/server.py or script", text: bindingForPath(config.id))
                            .textFieldStyle(.plain)
                    }
                }
                .frame(minHeight: 140)
            }

            HStack {
                Button {
                    addRow()
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    pickPath()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Browse for an MCP server file")
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
        }
    }

    private func bindingForEnabled(_ id: MCPServerConfig.ID) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings.mcpServers.first(where: { $0.id == id })?.enabled ?? false },
            set: { newValue in
                if let index = viewModel.settings.mcpServers.firstIndex(where: { $0.id == id }) {
                    viewModel.settings.mcpServers[index].enabled = newValue
                    viewModel.settings.save()
                }
            }
        )
    }

    private func bindingForName(_ id: MCPServerConfig.ID) -> Binding<String> {
        Binding(
            get: { viewModel.settings.mcpServers.first(where: { $0.id == id })?.name ?? "" },
            set: { newValue in
                if let index = viewModel.settings.mcpServers.firstIndex(where: { $0.id == id }) {
                    viewModel.settings.mcpServers[index].name = newValue
                    viewModel.settings.save()
                }
            }
        )
    }

    private func bindingForPath(_ id: MCPServerConfig.ID) -> Binding<String> {
        Binding(
            get: { viewModel.settings.mcpServers.first(where: { $0.id == id })?.path ?? "" },
            set: { newValue in
                if let index = viewModel.settings.mcpServers.firstIndex(where: { $0.id == id }) {
                    viewModel.settings.mcpServers[index].path = newValue
                    viewModel.settings.save()
                }
            }
        )
    }

    private func addRow() {
        let new = MCPServerConfig(name: "new-server", path: "", enabled: true)
        viewModel.settings.mcpServers.append(new)
        viewModel.settings.save()
        selection = new.id
    }

    private func pickPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let new = MCPServerConfig(name: name, path: url.path, enabled: true)
            viewModel.settings.mcpServers.append(new)
            viewModel.settings.save()
            selection = new.id
        }
    }

    private func removeSelected() {
        guard let selection else { return }
        viewModel.settings.mcpServers.removeAll { $0.id == selection }
        viewModel.settings.save()
        self.selection = nil
    }
}
