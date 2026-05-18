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
    @Published private(set) var setupState: SetupState = .idle

    let installGuide: MackupInstallGuide

    private let detector: MackupExecutableResolving
    private let fileManager: FileManager
    private let installer: CommandLineToolRunning
    private let configEditor: MackupConfigEditing
    let preferredCLIPath: URL?
    let configPath: URL

    init(
        detector: MackupExecutableResolving = MackupDetector(),
        fileManager: FileManager = .default,
        installer: CommandLineToolRunning = CommandLineToolRunner(),
        configEditor: MackupConfigEditing = MackupConfigEditor(),
        preferredCLIPath: URL? = nil,
        configPath: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg"),
        installGuide: MackupInstallGuide = .mvp
    ) {
        self.detector = detector
        self.fileManager = fileManager
        self.installer = installer
        self.configEditor = configEditor
        self.preferredCLIPath = preferredCLIPath
        self.configPath = configPath
        self.installGuide = installGuide
        self.selectedInstallOptionID = installGuide.options.first?.id ?? ""
    }

    func refresh() async {
        cliState = .checking
        configState = configState(for: configPath)

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
        setupState = .creatingConfig

        do {
            let config = MackupConfig(
                fileURL: configPath,
                storage: MackupStorage(engine: selectedStorageEngine, path: nil, directory: nil),
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
}

private extension DashboardViewModel.CLIState {
    static func invalidVersion(path: URL?, output: String) -> DashboardViewModel.CLIState {
        if let path {
            return .invalidVersion(path: path, output: output)
        }
        return .failed(path: nil, message: "Mackup version output could not be parsed.")
    }
}
