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
                .disabled(viewModel.state == .loading || viewModel.state == .saving)
            }

            VStack(alignment: .leading, spacing: 10) {
                settingRow(label: String(localized: "storage.engine")) {
                    Picker(String(localized: "storage.engine"), selection: $viewModel.engine) {
                        ForEach(MackupStorageEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                settingRow(label: String(localized: "storage.path")) {
                    selectedPathRow(
                        text: viewModel.path,
                        placeholder: String(localized: "storage.path.placeholder"),
                        systemImage: "folder"
                    ) {
                        chooseFolder { url in
                            viewModel.selectStoragePath(url)
                        }
                    }
                }

                settingRow(label: String(localized: "storage.directory")) {
                    selectedPathRow(
                        text: viewModel.directory,
                        placeholder: String(localized: "storage.directory.placeholder"),
                        systemImage: "folder.badge.gearshape"
                    ) {
                        chooseFolder { url in
                            viewModel.selectStorageDirectory(url)
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)

            if viewModel.engine != .fileSystem {
                Text(String(localized: "storage.path.auto_detected"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if viewModel.engine == .fileSystem {
                Text(String(localized: "storage.file_system.detail"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
