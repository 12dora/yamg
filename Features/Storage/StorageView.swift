import SwiftUI

struct StorageView: View {
    @StateObject private var viewModel: StorageViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(
            wrappedValue: StorageViewModel(configFilePath: preferences.configFilePath)
        )
    }

    init(viewModel: StorageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusText)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    viewModel.load()
                } label: {
                    Label(LocalizationKey.refresh.localizedStringKey, systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state == .loading || viewModel.state == .saving)

                Button {
                    viewModel.save()
                } label: {
                    Label(String(localized: "action.save"), systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.state == .loading || viewModel.state == .saving || !viewModel.canSave)
            }

            VStack(alignment: .leading, spacing: 10) {
                storageEngineChooser

                settingRow(label: String(localized: "storage.folder")) {
                    selectedPathRow(
                        text: viewModel.storageFolderPath,
                        placeholder: String(localized: "storage.folder.placeholder"),
                        systemImage: "folder"
                    ) {
                        chooseFolder { url in
                            viewModel.selectStorageFolder(url)
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)

            storageDetail

            if case .failed(let message) = viewModel.state {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .task {
            if viewModel.state == .idle {
                viewModel.load()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.engine)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return String(localized: "status.not_checked")
        case .loading:
            return String(localized: "status.checking")
        case .editing:
            return configPathText
        case .saving:
            return String(localized: "storage.saving")
        case .saved:
            return String(localized: "storage.saved")
        case .failed:
            return String(localized: "storage.failed")
        }
    }

    private var configPathText: String {
        if let path = viewModel.configPath?.path {
            return path
        }
        return String(localized: "storage.config.pending")
    }

    private var storageEngineChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "storage.engine"))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(viewModel.storageAvailability) { item in
                    Button {
                        viewModel.selectEngine(item.engine)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.isAvailable ? "checkmark.circle" : "slash.circle")
                            Text(item.engine.displayName)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 112)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!item.isAvailable)
                    .help(item.detail)
                }
            }
        }
    }

    private var storageDetail: some View {
        Group {
            if let selectedAvailability = viewModel.selectedAvailability {
                Label(
                    selectedAvailability.detail,
                    systemImage: selectedAvailability.isAvailable ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(selectedAvailability.isAvailable ? Color.secondary : Color.orange)
                .textSelection(.enabled)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func settingRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)
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

    private func chooseFolder(onSelection: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            onSelection(url)
        }
    }
}
