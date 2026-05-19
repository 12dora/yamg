import SwiftUI

struct DashboardView: View {
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("scheduled_backup.enabled")
                        .font(.headline)
                    Text("scheduled_backup.interval")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    ScheduledBackupView()
                }
                .frame(maxWidth: 780, alignment: .leading)

                Divider()
                    .frame(maxWidth: 780)

                OperationFlowView(
                    viewModel: OperationFlowViewModel(
                        logStore: logStore,
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
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var configEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                Label(LocalizedStringKey(viewModel.saveButtonTitleKey), systemImage: "square.and.arrow.down")
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

    @ViewBuilder
    private var setupStateView: some View {
        switch viewModel.setupState {
        case .idle:
            EmptyView()
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
        case .savingConfig:
            Label("setup.config.saving", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .configSaved(let url):
            Label("setup.config.saved \(url.path)", systemImage: "checkmark.circle")
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
        stateText: LocalizedStringKey,
        detailText: LocalizedStringKey
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
}

struct ScheduledBackupView: View {
    @StateObject private var viewModel: ScheduledBackupViewModel

    init(manager: ScheduledBackupManaging = ScheduledBackupManager()) {
        _viewModel = StateObject(wrappedValue: ScheduledBackupViewModel(manager: manager))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("scheduled_backup.enabled", isOn: $viewModel.isEnabled)
                    .toggleStyle(.checkbox)

                if viewModel.isEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("scheduled_backup.interval")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Stepper(
                                value: $viewModel.intervalMinutes,
                                in: 5...1440,
                                step: 5
                            ) {
                                Text("\(viewModel.intervalMinutes) min")
                                    .font(.body.monospaced())
                            }

                            Spacer()

                            Text(formatInterval(viewModel.intervalMinutes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            if viewModel.isInstalled {
                Label("scheduled_backup.installed", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.save()
                } label: {
                    Label("action.save", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.state == .saving)

                if case .failed(let message) = viewModel.state {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if case .saved = viewModel.state {
                Label("scheduled_backup.saved", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "scheduled_backup.interval_minutes \(minutes)")
        } else if minutes < 1440 {
            let hours = minutes / 60
            return String(localized: "scheduled_backup.interval_hours \(hours)")
        } else {
            let days = minutes / 1440
            return String(localized: "scheduled_backup.interval_days \(days)")
        }
    }
}
