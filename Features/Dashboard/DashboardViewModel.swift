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

    @Published private(set) var cliState: CLIState = .unknown
    @Published private(set) var configState: ConfigState = .unknown

    private let detector: MackupExecutableResolving
    private let fileManager: FileManager
    private let preferredCLIPath: URL?
    private let configPath: URL

    init(
        detector: MackupExecutableResolving = MackupDetector(),
        fileManager: FileManager = .default,
        preferredCLIPath: URL? = nil,
        configPath: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
    ) {
        self.detector = detector
        self.fileManager = fileManager
        self.preferredCLIPath = preferredCLIPath
        self.configPath = configPath
    }

    func refresh() async {
        cliState = .checking
        configState = configState(for: configPath)

        let report = await detector.detect(preferredPath: preferredCLIPath)
        cliState = cliState(from: report)
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
}

private extension DashboardViewModel.CLIState {
    static func invalidVersion(path: URL?, output: String) -> DashboardViewModel.CLIState {
        if let path {
            return .invalidVersion(path: path, output: output)
        }
        return .failed(path: nil, message: "Mackup version output could not be parsed.")
    }
}
