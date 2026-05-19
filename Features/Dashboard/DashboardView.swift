import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    private let preferences: AppPreferencesStoring

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        self.preferences = preferences
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configPath: preferences.configFilePath
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
            )
        )
    }

    init(viewModel: DashboardViewModel) {
        self.preferences = AppPreferences()
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    statusRow(
                        title: LocalizationKey.onboardingCLIStatus.localizedStringKey,
                        systemImage: cliIconName,
                        stateText: cliStatusText,
                        detailText: cliDetailText
                    )

                    Divider()

                    statusRow(
                        title: LocalizationKey.onboardingConfigStatus.localizedStringKey,
                        systemImage: configIconName,
                        stateText: configStatusText,
                        detailText: configDetailText
                    )
                }
                .frame(maxWidth: 780, alignment: .leading)

                Divider()
                    .frame(maxWidth: 720)

                if viewModel.shouldShowInstallGuide {
                    installGuide

                    Divider()
                        .frame(maxWidth: 780)
                }

                configEditor

                Divider()
                    .frame(maxWidth: 780)

                OperationFlowView(
                    viewModel: OperationFlowViewModel(
                        preferredCLIPath: viewModel.preferredCLIPath,
                        configFilePath: viewModel.configPath
                    )
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            if viewModel.cliState == .unknown {
                await viewModel.refresh()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.cliState)
        .animation(.easeInOut(duration: 0.18), value: viewModel.configState)
        .animation(.easeInOut(duration: 0.18), value: viewModel.setupState)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationKey.onboardingTitle.localizedStringKey)
                    .font(.title2.weight(.semibold))
                Text(LocalizationKey.onboardingSubtitle.localizedStringKey)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label(LocalizationKey.refresh.localizedStringKey, systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.cliState == .checking)
        }
    }

    private var installGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "install.title"))
                .font(.headline)
            Text(String(localized: "install.detail"))
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(String(localized: "install.method"), selection: $viewModel.selectedInstallOptionID) {
                ForEach(viewModel.installGuide.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            if let option = viewModel.selectedInstallOption {
                HStack(spacing: 10) {
                    Text(option.command)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(option.command, forType: .string)
                    } label: {
                        Label(String(localized: "action.copy"), systemImage: "doc.on.doc")
                    }

                    Button {
                        Task {
                            await viewModel.installSelectedMackup()
                        }
                    } label: {
                        Label(String(localized: "install.run"), systemImage: "arrow.down.circle")
                    }
                    .disabled(isInstalling)
                }
            }

            setupStateView
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var configEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "setup.config.title"))
                .font(.headline)
            Text(String(localized: "setup.config.detail"))
                .font(.callout)
                .foregroundStyle(.secondary)

            storageEngineChooser

            selectedPathRow(
                text: viewModel.selectedStorageFolderPath,
                placeholder: String(localized: "storage.folder.placeholder"),
                systemImage: "folder"
            ) {
                chooseFolder { url in
                    viewModel.selectStorageFolder(url)
                }
            }
            .frame(maxWidth: 700)

            if let selectedAvailability = viewModel.selectedStorageAvailability {
                Label(
                    selectedAvailability.detail,
                    systemImage: selectedAvailability.isAvailable ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(selectedAvailability.isAvailable ? Color.secondary : Color.orange)
                .textSelection(.enabled)
            }

            Button {
                viewModel.saveStorageConfig()
            } label: {
                Label(String(localized: String.LocalizationValue(viewModel.saveButtonTitleKey)), systemImage: "square.and.arrow.down")
            }
            .disabled(isSavingConfig || !viewModel.canSaveConfig)

            setupStateView
        }
        .frame(maxWidth: 780, alignment: .leading)
    }

    private var storageEngineChooser: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.storageAvailability) { item in
                Button {
                    viewModel.selectStorageEngine(item.engine)
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

    @ViewBuilder
    private var setupStateView: some View {
        switch viewModel.setupState {
        case .idle:
            EmptyView()
        case .installing(let method):
            Label(String(localized: "install.running \(method)"), systemImage: "clock")
                .foregroundStyle(.secondary)
        case .installFinished(let output):
            Label(output.isEmpty ? String(localized: "install.finished") : output, systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .installFailed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .savingConfig:
            Label(String(localized: "setup.config.saving"), systemImage: "clock")
                .foregroundStyle(.secondary)
        case .configSaved(let url):
            Label(String(localized: "setup.config.saved \(url.path)"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .configSaveFailed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    private var isInstalling: Bool {
        if case .installing = viewModel.setupState {
            return true
        }
        return false
    }

    private var isSavingConfig: Bool {
        if case .savingConfig = viewModel.setupState {
            return true
        }
        return false
    }

    private func statusRow(
        title: LocalizedStringKey,
        systemImage: String,
        stateText: String,
        detailText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(stateText)
                    .font(.body.weight(.medium))
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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

    private var cliIconName: String {
        switch viewModel.cliState {
        case .available:
            return "checkmark.circle"
        case .checking:
            return "clock"
        case .unknown:
            return "questionmark.circle"
        case .unavailable, .invalidVersion, .failed:
            return "exclamationmark.triangle"
        }
    }

    private var cliStatusText: String {
        switch viewModel.cliState {
        case .unknown:
            return String(localized: "status.not_checked")
        case .checking:
            return String(localized: "status.checking")
        case .available(_, let version):
            return String(localized: "onboarding.cli.available \(version.description)")
        case .unavailable:
            return String(localized: "onboarding.cli.unavailable")
        case .invalidVersion:
            return String(localized: "onboarding.cli.invalid_version")
        case .failed:
            return String(localized: "onboarding.cli.failed")
        }
    }

    private var cliDetailText: String {
        switch viewModel.cliState {
        case .available(let path, _):
            return path.path
        case .invalidVersion(let path, let output):
            return "\(path.path): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .failed(let path, let message):
            if let path {
                return "\(path.path): \(message)"
            }
            return message
        case .unavailable:
            return String(localized: "onboarding.cli.unavailable.detail")
        case .checking, .unknown:
            return String(localized: "onboarding.cli.pending.detail")
        }
    }

    private var configIconName: String {
        switch viewModel.configState {
        case .present:
            return "doc.text"
        case .missing:
            return "doc.badge.plus"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var configStatusText: String {
        switch viewModel.configState {
        case .unknown:
            return String(localized: "status.not_checked")
        case .present:
            return String(localized: "onboarding.config.present")
        case .missing:
            return String(localized: "onboarding.config.missing")
        }
    }

    private var configDetailText: String {
        switch viewModel.configState {
        case .present(let path), .missing(let path):
            return path.path
        case .unknown:
            return String(localized: "onboarding.config.pending.detail")
        }
    }
}
