import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    enum CLIState: Equatable {
        case unknown
        case checking
        case available(path: URL, version: MackupVersion)
        case unavailable
        case invalidVersion(path: URL, output: String)
        case failed(path: URL?, message: String)
    }

    enum ConfigState: Equatable {
        case unknown
        case present(URL)
        case missing(URL)
    }

    enum SetupState: Equatable {
        case idle
        case installing(String)
        case installFinished(String)
        case installFailed(String)
        case creatingConfig
        case configCreated(URL)
        case configCreateFailed(String)
    }

    @Published private(set) var cliState: CLIState = .unknown
    @Published private(set) var configState: ConfigState = .unknown
    @Published var selectedInstallOptionID: String
    @Published var selectedStorageEngine: MackupStorageEngine = .dropbox
    @Published var selectedStorageFolderPath: String = ""
    @Published private(set) var storageAvailability: [MackupStorageAvailability] = []
    @Published private(set) var setupState: SetupState = .idle

    let installGuide: MackupInstallGuide

    private let detector: MackupExecutableResolving
    private let fileManager: FileManager
    private let installer: CommandLineToolRunning
    private let configEditor: MackupConfigEditing
    private let storageDetector: MackupStorageDetecting
    let preferredCLIPath: URL?
    let configPath: URL

    init(
        detector: MackupExecutableResolving = MackupDetector(),
        fileManager: FileManager = .default,
        installer: CommandLineToolRunning = CommandLineToolRunner(),
        configEditor: MackupConfigEditing = MackupConfigEditor(),
        storageDetector: MackupStorageDetecting = MackupStorageDetector(),
        preferredCLIPath: URL? = nil,
        configPath: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg"),
        installGuide: MackupInstallGuide = .mvp
    ) {
        self.detector = detector
        self.fileManager = fileManager
        self.installer = installer
        self.configEditor = configEditor
        self.storageDetector = storageDetector
        self.preferredCLIPath = preferredCLIPath
        self.configPath = configPath
        self.installGuide = installGuide
        self.selectedInstallOptionID = installGuide.options.first?.id ?? ""
        refreshStorageAvailability()
    }

    func refresh() async {
        cliState = .checking
        configState = configState(for: configPath)
        refreshStorageAvailability()

        let report = await detector.detect(preferredPath: preferredCLIPath)
        cliState = cliState(from: report)
    }

    var shouldShowInstallGuide: Bool {
        switch cliState {
        case .unavailable:
            return true
        case .unknown, .checking, .available, .invalidVersion, .failed:
            return false
        }
    }

    var shouldShowConfigWizard: Bool {
        switch configState {
        case .missing:
            return true
        case .unknown, .present:
            return false
        }
    }

    var selectedInstallOption: MackupInstallOption? {
        installGuide.options.first { $0.id == selectedInstallOptionID }
    }

    var selectedStorageAvailability: MackupStorageAvailability? {
        storageAvailability.first { $0.engine == selectedStorageEngine }
    }

    var canCreateConfig: Bool {
        guard let selectedStorageAvailability, selectedStorageAvailability.isAvailable else {
            return false
        }

        guard !selectedStorageFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if selectedStorageEngine == .fileSystem {
            return true
        }

        return automaticStorageDirectory() != nil
    }

    func installSelectedMackup() async {
        guard let option = selectedInstallOption else {
            return
        }

        setupState = .installing(option.title)

        do {
            let result = try await installer.run(
                executableName: option.executableName,
                arguments: option.arguments
            )

            if result.exitCode == 0 {
                setupState = .installFinished(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
                await refresh()
            } else {
                setupState = .installFailed(nonEmpty(result.output, fallback: "\(option.command) exited with status \(result.exitCode)."))
            }
        } catch {
            setupState = .installFailed(error.localizedDescription)
        }
    }

    func createDefaultConfig() {
        guard canCreateConfig else {
            setupState = .configCreateFailed("Choose an available storage provider and Mackup folder before creating the config.")
            return
        }

        setupState = .creatingConfig

        do {
            let config = MackupConfig(
                fileURL: configPath,
                storage: storageFromSelection(),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
            try configEditor.save(config)
            configState = .present(configPath)
            setupState = .configCreated(configPath)
        } catch {
            setupState = .configCreateFailed(error.localizedDescription)
        }
    }

    func selectStorageEngine(_ engine: MackupStorageEngine) {
        guard engine == .fileSystem || storageAvailability.first(where: { $0.engine == engine })?.isAvailable == true else {
            return
        }

        selectedStorageEngine = engine

        if engine == .fileSystem {
            return
        }

        if let detectedPath = storageAvailability.first(where: { $0.engine == engine })?.detectedPath {
            selectedStorageFolderPath = URL(fileURLWithPath: detectedPath)
                .appendingPathComponent("Mackup", isDirectory: true)
                .standardizedFileURL
                .path
        }
    }

    func selectStorageFolder(_ url: URL) {
        selectedStorageFolderPath = url.standardizedFileURL.path
    }

    private func configState(for url: URL) -> ConfigState {
        if fileManager.fileExists(atPath: url.path) {
            return .present(url)
        }
        return .missing(url)
    }

    private func cliState(from report: MackupDetectionReport) -> CLIState {
        switch report.status {
        case .found:
            if let executableURL = report.executableURL, let version = report.version {
                return .available(path: executableURL, version: version)
            }
            return .failed(path: report.executableURL, message: "Mackup detection returned an incomplete success report.")
        case .notFound:
            return .unavailable
        case .invalidVersionOutput(let output):
            return .invalidVersion(path: report.executableURL, output: output)
        case .failed(let message):
            return .failed(path: report.executableURL, message: message)
        }
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func refreshStorageAvailability() {
        storageAvailability = storageDetector.availability()

        if storageAvailability.first(where: { $0.engine == selectedStorageEngine })?.isAvailable != true,
           let fallback = storageAvailability.first(where: \.isAvailable) {
            selectedStorageEngine = fallback.engine
        }

        if selectedStorageFolderPath.isEmpty,
           let detectedPath = storageAvailability.first(where: { $0.engine == selectedStorageEngine })?.detectedPath {
            selectedStorageFolderPath = URL(fileURLWithPath: detectedPath)
                .appendingPathComponent("Mackup", isDirectory: true)
                .standardizedFileURL
                .path
        }
    }

    private func storageFromSelection() -> MackupStorage {
        let selectedURL = URL(fileURLWithPath: selectedStorageFolderPath)
        let directory = selectedURL.lastPathComponent
        let rootPath = selectedURL.deletingLastPathComponent().path

        switch selectedStorageEngine {
        case .dropbox, .googleDrive, .iCloud:
            let directory = automaticStorageDirectory()
            return MackupStorage(
                engine: selectedStorageEngine,
                path: nil,
                directory: directory == "Mackup" ? nil : directory
            )
        case .fileSystem:
            return MackupStorage(
                engine: selectedStorageEngine,
                path: rootPath,
                directory: directory
            )
        }
    }

    private func automaticStorageDirectory() -> String? {
        guard let detectedPath = selectedStorageAvailability?.detectedPath else {
            return nil
        }

        let selectedPath = URL(fileURLWithPath: selectedStorageFolderPath).standardizedFileURL.path
        let rootPath = URL(fileURLWithPath: detectedPath).standardizedFileURL.path
        let relativePath: String

        if selectedPath.hasPrefix(rootPath + "/") {
            relativePath = String(selectedPath.dropFirst(rootPath.count + 1))
        } else {
            return nil
        }

        return relativePath.isEmpty ? nil : relativePath
    }
}

private extension DashboardViewModel.CLIState {
    static func invalidVersion(path: URL?, output: String) -> DashboardViewModel.CLIState {
        if let path {
            return .invalidVersion(path: path, output: output)
        }
        return .failed(path: nil, message: "Mackup version output could not be parsed.")
    }
}
