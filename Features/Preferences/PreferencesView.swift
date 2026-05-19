import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel: PreferencesViewModel
    @State private var isResetConfirmationPresented = false

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(wrappedValue: PreferencesViewModel(preferences: preferences))
    }

    init(viewModel: PreferencesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingField(
                label: "preferences.cli_path",
                detail: "preferences.cli_path.detail"
            ) {
                selectedPathRow(
                    text: viewModel.cliPath,
                    placeholder: "preferences.cli_path.placeholder",
                    systemImage: "terminal"
                ) {
                    chooseFile { url in
                        viewModel.selectCLIPath(url)
                    }
                }
            }

            settingField(
                label: "preferences.config_path",
                detail: "preferences.config_path.detail"
            ) {
                selectedPathRow(
                    text: viewModel.configPath,
                    placeholder: "preferences.config_path.placeholder",
                    systemImage: "doc.text"
                ) {
                    chooseConfigFile { url in
                        viewModel.selectConfigPath(url)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Toggle("preferences.show_link_mode", isOn: $viewModel.showsLinkMode)
                        .toggleStyle(.checkbox)

                    if viewModel.showsLinkMode {
                        Label("link_mode.high_risk", systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.showsLinkMode {
                    Text("link_mode.warning")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            settingField(
                label: "preferences.language",
                detail: ""
            ) {
                Picker("preferences.language", selection: $viewModel.preferredLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayNameKey).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.preferredLanguage) { _ in
                    viewModel.applyPreferredLanguage()
                }
            }

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    isResetConfirmationPresented = true
                } label: {
                    Label("action.reset", systemImage: "arrow.counterclockwise")
                }

                Button {
                    viewModel.save()
                } label: {
                    Label("action.save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)

                stateLabel
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
        .confirmationDialog(
            "preferences.reset.confirm_title",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("preferences.reset.confirm_action", role: .destructive) {
                viewModel.reset()
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("preferences.reset.confirm_message")
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch viewModel.state {
        case .saved:
            Label("preferences.saved", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .reset:
            Label("preferences.reset_done", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .editing:
            EmptyView()
        }
    }

    private func settingField<Content: View>(
        label: LocalizedStringKey,
        detail: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .foregroundStyle(.primary)
            content()
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func selectedPathRow(
        text: String,
        placeholder: LocalizedStringKey,
        systemImage: String,
        onChoose: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Label {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(text)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))

            Button {
                onChoose()
            } label: {
                Label("action.choose", systemImage: "folder")
            }
        }
    }

    private func chooseFile(onSelection: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            onSelection(url)
        }
    }

    private func chooseConfigFile(onSelection: (URL) -> Void) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = ".mackup.cfg"

        if panel.runModal() == .OK, let url = panel.url {
            onSelection(url)
        }
    }
}
