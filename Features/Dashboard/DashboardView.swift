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

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences(), logStore: ProcessLogPersisting = ProcessLogStore()) {
        self.preferences = preferences
        self.logStore = logStore
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configPath: preferences.configFilePath
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
            )
        )
    }

    init(viewModel: DashboardViewModel, logStore: ProcessLogPersisting = ProcessLogStore()) {
        self.preferences = AppPreferences()
        self.logStore = logStore
        _viewModel = StateObject(wrappedValue: viewModel)
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

            ScheduledBackupView()

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
                viewModel: OperationFlowViewModel(
                    logStore: logStore,
                    preferredCLIPath: viewModel.preferredCLIPath,
                    configFilePath: viewModel.configPath
                ),
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

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let home = fileManager.homeDirectoryForCurrentUser
        self.launchAgentPath = home.appendingPathComponent("Library/LaunchAgents/\(launchAgentName).plist")
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

    private func installLaunchAgent(intervalMinutes: Int) throws {
        let plistContent = createLaunchAgentPlist(intervalMinutes: intervalMinutes)

        do {
            let parentDir = launchAgentPath.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try plistContent.write(to: launchAgentPath, atomically: true, encoding: .utf8)
        } catch {
            throw ScheduledBackupError.launchAgentCreationFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", launchAgentPath.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ScheduledBackupError.launchAgentCreationFailed("Failed to load launch agent: \(error.localizedDescription)")
        }
    }

    private func uninstallLaunchAgent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", launchAgentPath.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ScheduledBackupError.launchAgentRemovalFailed("Failed to unload launch agent: \(error.localizedDescription)")
        }

        do {
            try fileManager.removeItem(at: launchAgentPath)
        } catch {
            throw ScheduledBackupError.launchAgentRemovalFailed("Failed to remove launch agent file: \(error.localizedDescription)")
        }
    }

    private func createLaunchAgentPlist(intervalMinutes: Int) -> String {
        let intervalSeconds = intervalMinutes * 60
        let mackupPath = "/opt/homebrew/bin/mackup"

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentName)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(mackupPath)</string>
                <string>backup</string>
                <string>--force</string>
            </array>
            <key>StartInterval</key>
            <integer>\(intervalSeconds)</integer>
            <key>StandardOutPath</key>
            <string>\(NSHomeDirectory())/Library/Logs/YAMG/backup.log</string>
            <key>StandardErrorPath</key>
            <string>\(NSHomeDirectory())/Library/Logs/YAMG/backup-error.log</string>
        </dict>
        </plist>
        """
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

        do {
            try manager.setConfig(config)
            isInstalled = manager.isLaunchAgentInstalled()
            state = .saved
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        save()
    }

    func setIntervalMinutes(_ intervalMinutes: Int) {
        self.intervalMinutes = intervalMinutes
        save()
    }
}

struct ScheduledBackupView: View {
    @StateObject private var viewModel: ScheduledBackupViewModel

    init(manager: ScheduledBackupManaging = ScheduledBackupManager()) {
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
