import SwiftUI

/// Settings pane for managing saved prompts (aliases) and the command prefix.
struct SavedPromptsEditor: View {
    @Bindable var viewModel: QuickViewModel
    @State private var selection: SavedPrompt.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Prompts")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Prefix:")
                    .foregroundStyle(.secondary)
                TextField("/", text: $viewModel.settings.savedPromptPrefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .onChange(of: viewModel.settings.savedPromptPrefix) { _, newValue in
                        if newValue.isEmpty {
                            viewModel.settings.savedPromptPrefix = "/"
                        }
                        viewModel.settings.save()
                    }
                Text("Type this + an alias to expand, e.g. \(viewModel.settings.savedPromptPrefix)translate")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Table(viewModel.settings.savedPrompts, selection: $selection) {
                TableColumn("Alias") { prompt in
                    TextField(
                        "alias",
                        text: bindingForAlias(prompt.id)
                    )
                    .textFieldStyle(.plain)
                }
                .width(min: 80, max: 140)
                TableColumn("Prompt") { prompt in
                    TextField(
                        "Full prompt sent to apfel",
                        text: bindingForPrompt(prompt.id)
                    )
                    .textFieldStyle(.plain)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button {
                    addRow()
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Spacer()
                Button("Restore defaults") {
                    viewModel.settings.savedPrompts = SavedPrompt.defaults
                    viewModel.settings.save()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            }
        }
    }

    private func bindingForAlias(_ id: SavedPrompt.ID) -> Binding<String> {
        Binding(
            get: { viewModel.settings.savedPrompts.first(where: { $0.id == id })?.alias ?? "" },
            set: { newValue in
                if let index = viewModel.settings.savedPrompts.firstIndex(where: { $0.id == id }) {
                    viewModel.settings.savedPrompts[index].alias = newValue
                    viewModel.settings.save()
                }
            }
        )
    }

    private func bindingForPrompt(_ id: SavedPrompt.ID) -> Binding<String> {
        Binding(
            get: { viewModel.settings.savedPrompts.first(where: { $0.id == id })?.prompt ?? "" },
            set: { newValue in
                if let index = viewModel.settings.savedPrompts.firstIndex(where: { $0.id == id }) {
                    viewModel.settings.savedPrompts[index].prompt = newValue
                    viewModel.settings.save()
                }
            }
        )
    }

    private func addRow() {
        let new = SavedPrompt(alias: "new", prompt: "Your prompt here.")
        viewModel.settings.savedPrompts.append(new)
        viewModel.settings.save()
        selection = new.id
    }

    private func removeSelected() {
        guard let selection else { return }
        viewModel.settings.savedPrompts.removeAll { $0.id == selection }
        viewModel.settings.save()
        self.selection = nil
    }
}
