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
        VStack(alignment: .leading, spacing: 14) {
            settingField(
                label: String(localized: "preferences.cli_path"),
                detail: String(localized: "preferences.cli_path.detail")
            ) {
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

            settingField(
                label: String(localized: "preferences.config_path"),
                detail: String(localized: "preferences.config_path.detail")
            ) {
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Toggle(String(localized: "preferences.show_link_mode"), isOn: $viewModel.showsLinkMode)
                        .toggleStyle(.checkbox)

                    if viewModel.showsLinkMode {
                        Label(String(localized: "link_mode.high_risk"), systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.showsLinkMode {
                    Text(String(localized: "link_mode.warning"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 10) {
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

                stateLabel
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch viewModel.state {
        case .saved:
            Label(String(localized: "preferences.saved"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .reset:
            Label(String(localized: "preferences.reset_done"), systemImage: "checkmark.circle")
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
        label: String,
        detail: String,
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
