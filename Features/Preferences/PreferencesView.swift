import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel: PreferencesViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(wrappedValue: PreferencesViewModel(preferences: preferences))
    }

    init(viewModel: PreferencesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                settingRow(label: String(localized: "preferences.cli_path")) {
                    selectedPathRow(
                        text: viewModel.cliPath,
                        placeholder: String(localized: "preferences.cli_path.placeholder"),
                        systemImage: "terminal"
                    ) {
                        chooseFile { url in
                            viewModel.selectCLIPath(url)
                        }
                    }
                }

                detailRow(String(localized: "preferences.cli_path.detail"))

                settingRow(label: String(localized: "preferences.config_path")) {
                    selectedPathRow(
                        text: viewModel.configPath,
                        placeholder: String(localized: "preferences.config_path.placeholder"),
                        systemImage: "doc.text"
                    ) {
                        chooseConfigFile { url in
                            viewModel.selectConfigPath(url)
                        }
                    }
                }

                detailRow(String(localized: "preferences.config_path.detail"))
            }
            .frame(maxWidth: 760, alignment: .leading)

            HStack {
                Button(role: .destructive) {
                    viewModel.reset()
                } label: {
                    Label(String(localized: "action.reset"), systemImage: "arrow.counterclockwise")
                }

                Button {
                    viewModel.save()
                } label: {
                    Label(String(localized: "action.save"), systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()
                .frame(maxWidth: 760)

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "preferences.development.title"))
                    .font(.headline)
                Text(String(localized: "preferences.development.detail"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    viewModel.resetForFirstRunSimulation()
                } label: {
                    Label(String(localized: "preferences.development.reset_first_run"), systemImage: "arrow.counterclockwise.circle")
                }
            }
            .frame(maxWidth: 760, alignment: .leading)

            if viewModel.state == .saved {
                Label(String(localized: "preferences.saved"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            if viewModel.state == .reset {
                Label(String(localized: "preferences.reset_done"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }

            if viewModel.state == .developmentReset {
                Label(String(localized: "preferences.development.reset_done"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }

            if case .failed(let message) = viewModel.state {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }

    private func settingRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 150, height: 0)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func selectedPathRow(
        text: String,
        placeholder: String,
        systemImage: String,
        onChoose: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Label {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
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
                Label(String(localized: "action.choose"), systemImage: "folder")
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
