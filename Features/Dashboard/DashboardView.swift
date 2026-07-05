import SwiftUI

struct DashboardView: View {
    private enum Layout {
        static let sectionSpacing: CGFloat = 10
        static let panelSpacing: CGFloat = 10

        static let headerWidth: CGFloat? = nil
        static let headerMaxWidth: CGFloat = .infinity
        static let headerHeight: CGFloat? = nil

        static let statusPanelWidth: CGFloat? = nil
        static let statusPanelMaxWidth: CGFloat = .infinity
        static let statusPanelHeight: CGFloat? = nil

        static let installGuideWidth: CGFloat? = nil
        static let installGuideMaxWidth: CGFloat = .infinity
        static let installGuideHeight: CGFloat? = nil
        static let installMethodPickerMaxWidth: CGFloat = 360

        static let configEditorWidth: CGFloat? = nil
        static let configEditorMaxWidth: CGFloat = .infinity
        static let configEditorHeight: CGFloat? = nil
        static let storageEngineButtonMinWidth: CGFloat = 112
        static let selectedPathMinWidth: CGFloat = 180

        static let scheduledBackupPanelWidth: CGFloat = 150
        static let scheduledBackupPanelHeight: CGFloat = 150

        static let operationPanelWidth: CGFloat? = nil
        static let operationPanelMaxWidth: CGFloat = .infinity
        static let operationPanelHeight: CGFloat = 150
        static let operationControlsWidth: CGFloat = 150
        static let operationActionButtonWidth: CGFloat = 108
        static let operationLogMinWidth: CGFloat = 150
        static let operationLogMaxWidth: CGFloat = .infinity
        static let operationLogHeight: CGFloat? = nil
        static let operationLogMaxHeight: CGFloat = .infinity

        static let statusIconWidth: CGFloat = 20
    }

    @StateObject private var viewModel: DashboardViewModel
    private let preferences: AppPreferencesStoring
    private let logStore: ProcessLogPersisting
    // Injected by the owning shell so it persists across navigation; a fresh one
    // is created only for standalone/preview use.
    private let operationFlowViewModel: OperationFlowViewModel

    @MainActor
    init(
        preferences: AppPreferencesStoring = AppPreferences(),
        logStore: ProcessLogPersisting = ProcessLogStore(),
        operationFlowViewModel: OperationFlowViewModel? = nil
    ) {
        self.preferences = preferences
        self.logStore = logStore
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configPath: preferences.configFilePath
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
            )
        )
        self.operationFlowViewModel = operationFlowViewModel ?? OperationFlowViewModel(
            logStore: logStore,
            preferredCLIPath: preferences.preferredCLIPath,
            configFilePath: preferences.configFilePath
        )
    }

    @MainActor
    init(viewModel: DashboardViewModel, logStore: ProcessLogPersisting = ProcessLogStore()) {
        self.preferences = AppPreferences()
        self.logStore = logStore
        _viewModel = StateObject(wrappedValue: viewModel)
        self.operationFlowViewModel = OperationFlowViewModel(logStore: logStore)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                header

                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    statusPanel
                    if viewModel.shouldShowInstallGuide {
                        installGuide
                    }
                    configEditor
                    backupAndRestorePanels
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
                    .font(.headline)
                Text(LocalizationKey.onboardingSubtitle.localizedStringKey)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        .frame(width: Layout.headerWidth, height: Layout.headerHeight)
        .frame(maxWidth: Layout.headerMaxWidth)
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .frame(width: Layout.statusPanelWidth, height: Layout.statusPanelHeight, alignment: .topLeading)
        .frame(maxWidth: Layout.statusPanelMaxWidth, alignment: .topLeading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var backupPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("scheduled_backup.enabled")
                .font(.headline)

            ScheduledBackupView(preferences: preferences)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .frame(height: Layout.scheduledBackupPanelHeight, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var backupAndRestorePanels: some View {
        HStack(alignment: .top, spacing: Layout.panelSpacing) {
            backupPanel
                .frame(width: Layout.scheduledBackupPanelWidth, alignment: .topLeading)

            OperationFlowView(
                viewModel: operationFlowViewModel,
                layout: OperationFlowView.Layout(
                    panelHeight: Layout.operationPanelHeight,
                    controlsWidth: Layout.operationControlsWidth,
                    actionButtonWidth: Layout.operationActionButtonWidth,
                    logMinWidth: Layout.operationLogMinWidth,
                    logMaxWidth: Layout.operationLogMaxWidth,
                    logHeight: Layout.operationLogHeight,
                    logMaxHeight: Layout.operationLogMaxHeight
                )
            )
            .frame(width: Layout.operationPanelWidth, alignment: .topLeading)
            .frame(maxWidth: Layout.operationPanelMaxWidth, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var installGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("install.title")
                .font(.headline)
            Text("install.detail")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("install.method", selection: $viewModel.selectedInstallOptionID) {
                ForEach(viewModel.installGuide.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: Layout.installMethodPickerMaxWidth)

            if let option = viewModel.selectedInstallOption {
                VStack(alignment: .leading, spacing: 8) {
                    installCommand(option)
                    installActions
                }
            }
        }
        .frame(width: Layout.installGuideWidth, height: Layout.installGuideHeight, alignment: .topLeading)
        .frame(maxWidth: Layout.installGuideMaxWidth, alignment: .topLeading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func installCommand(_ option: MackupInstallOption) -> some View {
        Text(option.command)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var installActions: some View {
        HStack(spacing: 8) {
            Button {
                NSPasteboard.general.clearContents()
                if let option = viewModel.selectedInstallOption {
                    NSPasteboard.general.setString(option.command, forType: .string)
                }
            } label: {
                Label("action.copy", systemImage: "doc.on.doc")
            }

            Button {
                Task {
                    await viewModel.installSelectedMackup()
                }
            } label: {
                Label("install.run", systemImage: "arrow.down.circle")
            }
            .disabled(isInstalling)
        }
    }

    private var configEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("setup.config.title")
                .font(.headline)
            Text("setup.config.detail")
                .font(.callout)
                .foregroundStyle(.secondary)

            storageEngineChooser

            selectedPathRow(
                text: viewModel.selectedStorageFolderPath,
                placeholder: "storage.folder.placeholder",
                systemImage: "folder"
            ) {
                chooseFolder { url in
                    viewModel.selectStorageFolder(url)
                }
            }

            if let selectedAvailability = viewModel.selectedStorageAvailability {
                Label(
                    selectedAvailability.detail,
                    systemImage: selectedAvailability.isAvailable ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(selectedAvailability.isAvailable ? Color.secondary : Color.orange)
                .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.saveStorageConfig()
                } label: {
                    Label(LocalizedStringKey(viewModel.saveButtonTitleKey), systemImage: "square.and.arrow.down")
                }
                .disabled(isSavingConfig || !viewModel.canSaveConfig)

                if let reasonKey = viewModel.saveConfigDisabledReasonKey {
                    Label(LocalizedStringKey(reasonKey), systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                configSaveStatusView
            }

            setupErrorStateView
        }
        .frame(width: Layout.configEditorWidth, height: Layout.configEditorHeight, alignment: .topLeading)
        .frame(maxWidth: Layout.configEditorMaxWidth, alignment: .topLeading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var storageEngineChooser: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.storageAvailability) { item in
                let isSelected = item.engine == viewModel.selectedStorageEngine

                Button {
                    viewModel.selectStorageEngine(item.engine)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: storageEngineIcon(for: item, isSelected: isSelected))
                        Text(item.engine.displayName)
                            .lineLimit(1)
                    }
                    .frame(minWidth: Layout.storageEngineButtonMinWidth)
                }
                .buttonStyle(.borderedProminent)
                .tint(isSelected ? .accentColor : .gray)
                .disabled(!item.isAvailable)
                .help(item.detail)
            }
        }
    }

    private func storageEngineIcon(for item: MackupStorageAvailability, isSelected: Bool) -> String {
        if isSelected {
            return "checkmark.circle.fill"
        }

        return item.isAvailable ? "circle" : "slash.circle"
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
            .frame(minWidth: Layout.selectedPathMinWidth, maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var configSaveStatusView: some View {
        switch viewModel.setupState {
        case .savingConfig:
            Label("setup.config.saving", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .configSaved(let url):
            Label("setup.config.saved \(url.path)", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        case .idle, .installing, .installFinished, .installFailed, .configSaveFailed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var setupErrorStateView: some View {
        switch viewModel.setupState {
        case .installing(let method):
            Label("install.running \(method)", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .installFinished(let output):
            Label(output.isEmpty ? LocalizedStringKey("install.finished") : LocalizedStringKey(output), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .textSelection(.enabled)
        case .installFailed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .configSaveFailed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        case .idle, .savingConfig, .configSaved:
            EmptyView()
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
        stateText: LocalizedStringKey,
        detailText: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: Layout.statusIconWidth)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(stateText)
                    .font(.callout.weight(.medium))
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
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

    private var cliStatusText: LocalizedStringKey {
        switch viewModel.cliState {
        case .unknown:
            return "status.not_checked"
        case .checking:
            return "status.checking"
        case .available(_, let version):
            return "onboarding.cli.available \(version.description)"
        case .unavailable:
            return "onboarding.cli.unavailable"
        case .invalidVersion:
            return "onboarding.cli.invalid_version"
        case .failed:
            return "onboarding.cli.failed"
        }
    }

    private var cliDetailText: LocalizedStringKey {
        switch viewModel.cliState {
        case .available(let path, _):
            return LocalizedStringKey(path.path)
        case .invalidVersion(let path, let output):
            return LocalizedStringKey("\(path.path): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .failed(let path, let message):
            if let path {
                return LocalizedStringKey("\(path.path): \(message)")
            }
            return LocalizedStringKey(message)
        case .unavailable:
            return "onboarding.cli.unavailable.detail"
        case .checking, .unknown:
            return "onboarding.cli.pending.detail"
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

    private var configStatusText: LocalizedStringKey {
        switch viewModel.configState {
        case .unknown:
            return "status.not_checked"
        case .present:
            return "onboarding.config.present"
        case .missing:
            return "onboarding.config.missing"
        }
    }

    private var configDetailText: LocalizedStringKey {
        switch viewModel.configState {
        case .present(let path), .missing(let path):
            return LocalizedStringKey(path.path)
        case .unknown:
            return "onboarding.config.pending.detail"
        }
    }
}

// MARK: - Scheduled Backup

struct ScheduledBackupConfig: Equatable {
    let isEnabled: Bool
    let intervalMinutes: Int

    init(isEnabled: Bool = false, intervalMinutes: Int = 60) {
        self.isEnabled = isEnabled
        self.intervalMinutes = max(5, intervalMinutes)
    }
}

protocol ScheduledBackupManaging {
    func getConfig() -> ScheduledBackupConfig
    func setConfig(_ config: ScheduledBackupConfig) throws
    func isLaunchAgentInstalled() -> Bool
}

enum ScheduledBackupError: Error, Equatable {
    case launchAgentCreationFailed(String)
    case launchAgentRemovalFailed(String)
}

final class ScheduledBackupManager: ScheduledBackupManaging {
    private let fileManager: FileManager
    private let launchAgentName = "com.yamg.backup"
    private let launchAgentPath: URL
    private let mackupPathProvider: () -> URL?
    private let candidateMackupPaths: [URL]

    init(
        fileManager: FileManager = .default,
        mackupPathProvider: @escaping () -> URL? = { nil },
        candidateMackupPaths: [URL] = MackupDetector.defaultCandidateURLs
    ) {
        self.fileManager = fileManager
        let home = fileManager.homeDirectoryForCurrentUser
        self.launchAgentPath = home.appendingPathComponent("Library/LaunchAgents/\(launchAgentName).plist")
        self.mackupPathProvider = mackupPathProvider
        self.candidateMackupPaths = candidateMackupPaths
    }

    private func resolveMackupPath() -> URL {
        if let preferred = mackupPathProvider(),
           fileManager.isExecutableFile(atPath: preferred.path) {
            return preferred
        }
        for candidate in candidateMackupPaths
        where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        // Last-resort fallback so the plist is still well-formed; the agent will
        // fail loudly via StandardErrorPath instead of being silently broken.
        return candidateMackupPaths.first ?? URL(fileURLWithPath: "/usr/local/bin/mackup")
    }

    func getConfig() -> ScheduledBackupConfig {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "scheduledBackup.enabled")
        let intervalMinutes = defaults.integer(forKey: "scheduledBackup.intervalMinutes")

        return ScheduledBackupConfig(
            isEnabled: isEnabled,
            intervalMinutes: intervalMinutes > 0 ? intervalMinutes : 60
        )
    }

    func setConfig(_ config: ScheduledBackupConfig) throws {
        let defaults = UserDefaults.standard
        defaults.set(config.isEnabled, forKey: "scheduledBackup.enabled")
        defaults.set(config.intervalMinutes, forKey: "scheduledBackup.intervalMinutes")

        if config.isEnabled {
            try installLaunchAgent(intervalMinutes: config.intervalMinutes)
        } else {
            try uninstallLaunchAgent()
        }
    }

    func isLaunchAgentInstalled() -> Bool {
        fileManager.fileExists(atPath: launchAgentPath.path)
    }

    private var logDirectoryPath: String {
        "\(NSHomeDirectory())/Library/Logs/YAMG"
    }

    private func installLaunchAgent(intervalMinutes: Int) throws {
        let plistData: Data
        do {
            plistData = try createLaunchAgentPlistData(intervalMinutes: intervalMinutes)
        } catch {
            throw ScheduledBackupError.launchAgentCreationFailed(error.localizedDescription)
        }

        // Unload any previous agent first; launchctl ignores parameter changes
        // for an already-loaded label, so a fresh load() against the same path
        // would silently keep the old interval/path.
        runLaunchctl(arguments: ["unload", launchAgentPath.path])

        do {
            let parentDir = launchAgentPath.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            // launchd does not create intermediate directories for the log redirect
            // targets, so create ~/Library/Logs/YAMG or the agent can never write
            // its stdout/stderr logs (defeating the "fail loudly" fallback above).
            try fileManager.createDirectory(atPath: logDirectoryPath, withIntermediateDirectories: true)
            try plistData.write(to: launchAgentPath, options: .atomic)
        } catch {
            throw ScheduledBackupError.launchAgentCreationFailed(error.localizedDescription)
        }

        // Check the exit status: launchctl returning non-zero (e.g. a rejected
        // plist) must surface as a failure instead of the UI reporting success.
        let status = runLaunchctl(arguments: ["load", launchAgentPath.path])
        if status != 0 {
            throw ScheduledBackupError.launchAgentCreationFailed("launchctl load exited with status \(status).")
        }
    }

    @discardableResult
    private func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func uninstallLaunchAgent() throws {
        runLaunchctl(arguments: ["unload", launchAgentPath.path])

        // Removing an agent that was never installed should be a no-op success,
        // not a spurious error shown when the user toggles off something that was
        // never on (e.g. UserDefaults says enabled but the plist is absent).
        guard fileManager.fileExists(atPath: launchAgentPath.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: launchAgentPath)
        } catch {
            throw ScheduledBackupError.launchAgentRemovalFailed("Failed to remove launch agent file: \(error.localizedDescription)")
        }
    }

    private func createLaunchAgentPlistData(intervalMinutes: Int) throws -> Data {
        // Serialize a real plist dictionary rather than interpolating into an XML
        // template: paths containing &, <, or > (a legitimate mackup path or home
        // directory) would otherwise produce malformed XML that launchctl rejects.
        let plist: [String: Any] = [
            "Label": launchAgentName,
            "ProgramArguments": [resolveMackupPath().path, "backup", "--force"],
            "StartInterval": intervalMinutes * 60,
            "StandardOutPath": "\(logDirectoryPath)/backup.log",
            "StandardErrorPath": "\(logDirectoryPath)/backup-error.log"
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}

@MainActor
final class ScheduledBackupViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var intervalMinutes: Int
    @Published private(set) var state: State = .idle
    @Published private(set) var isInstalled: Bool

    enum State: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private let manager: ScheduledBackupManaging
    private var pendingIntervalSave: Task<Void, Never>?
    private let intervalSaveDebounceNanoseconds: UInt64 = 450_000_000
    private var saveTask: Task<Void, Never>?
    private var saveGeneration = 0

    init(manager: ScheduledBackupManaging = ScheduledBackupManager()) {
        self.manager = manager
        let config = manager.getConfig()
        self.isEnabled = config.isEnabled
        self.intervalMinutes = config.intervalMinutes
        self.isInstalled = manager.isLaunchAgentInstalled()
    }

    func save() {
        state = .saving

        let config = ScheduledBackupConfig(
            isEnabled: isEnabled,
            intervalMinutes: intervalMinutes
        )

        let manager = self.manager
        // Serialize saves: each awaits the previous so the external side effects
        // (plist write, launchctl load/unload, UserDefaults) run strictly FIFO —
        // otherwise a quick enable→disable could interleave and leave the on-disk
        // agent in a state that contradicts the user's final intent. A generation
        // token ensures only the most recent save publishes UI state.
        saveGeneration += 1
        let generation = saveGeneration
        let previousSave = saveTask
        saveTask = Task { [weak self] in
            await previousSave?.value

            // setConfig writes the plist and blocks on launchctl via
            // waitUntilExit(); run it off the main actor so the UI never freezes.
            let outcome: (installed: Bool, error: String?) = await Task.detached {
                do {
                    try manager.setConfig(config)
                    return (manager.isLaunchAgentInstalled(), nil)
                } catch {
                    return (false, error.localizedDescription)
                }
            }.value

            guard let self, generation == self.saveGeneration else { return }
            if let message = outcome.error {
                self.state = .failed(message)
            } else {
                self.isInstalled = outcome.installed
                self.state = .saved
            }
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        pendingIntervalSave?.cancel()
        pendingIntervalSave = nil
        save()
    }

    func setIntervalMinutes(_ intervalMinutes: Int) {
        self.intervalMinutes = intervalMinutes
        // Stepper clicks fire rapidly; coalesce them so we hit launchctl once
        // when the user finishes clicking, not on every step.
        pendingIntervalSave?.cancel()
        pendingIntervalSave = Task { [weak self, debounce = intervalSaveDebounceNanoseconds] in
            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled, let self else { return }
            self.save()
        }
    }
}

struct ScheduledBackupView: View {
    @StateObject private var viewModel: ScheduledBackupViewModel

    init(manager: ScheduledBackupManaging = ScheduledBackupManager()) {
        _viewModel = StateObject(wrappedValue: ScheduledBackupViewModel(manager: manager))
    }

    @MainActor
    init(preferences: AppPreferencesStoring) {
        let manager = ScheduledBackupManager(
            mackupPathProvider: { preferences.preferredCLIPath }
        )
        _viewModel = StateObject(wrappedValue: ScheduledBackupViewModel(manager: manager))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    "scheduled_backup.enabled",
                    isOn: Binding(
                        get: { viewModel.isEnabled },
                        set: { viewModel.setEnabled($0) }
                    )
                )
                    .toggleStyle(.checkbox)

                VStack(alignment: .leading, spacing: 6) {
                    Text("scheduled_backup.interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Stepper(
                            value: Binding(
                                get: { viewModel.intervalMinutes },
                                set: { viewModel.setIntervalMinutes($0) }
                            ),
                            in: 5...1440,
                            step: 5
                        ) {
                            Text("\(viewModel.intervalMinutes) min")
                                .font(.body.monospaced())
                        }
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .opacity(viewModel.isEnabled ? 1 : 0.45)
                .disabled(!viewModel.isEnabled)
            }

            if case .failed(let message) = viewModel.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

}
