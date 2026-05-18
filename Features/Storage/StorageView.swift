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
        VStack(alignment: .leading, spacing: 14) {
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

            Form {
                Picker(String(localized: "storage.engine"), selection: $viewModel.engine) {
                    ForEach(MackupStorageEngine.allCases, id: \.self) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    TextField(String(localized: "storage.path"), text: $viewModel.path)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        chooseFolder { url in
                            viewModel.selectStoragePath(url)
                        }
                    } label: {
                        Label(String(localized: "action.choose"), systemImage: "folder")
                    }
                }

                HStack(spacing: 8) {
                    TextField(String(localized: "storage.directory"), text: $viewModel.directory)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        chooseFolder { url in
                            viewModel.selectStorageDirectory(url)
                        }
                    } label: {
                        Label(String(localized: "action.choose"), systemImage: "folder")
                    }
                }

                if viewModel.engine == .fileSystem {
                    Text(String(localized: "storage.file_system.detail"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 680)

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
