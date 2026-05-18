import XCTest
@testable import YAMG

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testRefreshReportsAvailableCLIAndPresentConfig() async throws {
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try "[storage]\nengine = dropbox\n".write(to: configPath, atomically: true, encoding: .utf8)
        let executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mackup")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(
                    status: .found,
                    executableURL: executableURL,
                    version: MackupVersion(major: 0, minor: 10, patch: 3),
                    checkedURLs: [executableURL]
                )
            ),
            configPath: configPath
        )

        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.cliState,
            .available(path: executableURL, version: MackupVersion(major: 0, minor: 10, patch: 3))
        )
        XCTAssertEqual(viewModel.configState, .present(configPath))
    }

    func testRefreshReportsMissingCLIAndMissingConfig() async {
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(
                    status: .notFound,
                    executableURL: nil,
                    version: nil,
                    checkedURLs: []
                )
            ),
            configPath: configPath
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.cliState, .unavailable)
        XCTAssertEqual(viewModel.configState, .missing(configPath))
        XCTAssertTrue(viewModel.shouldShowInstallGuide)
    }

    func testRefreshReportsInvalidVersionOutput() async {
        let executableURL = URL(fileURLWithPath: "/usr/local/bin/mackup")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(
                    status: .invalidVersionOutput("Mackup unknown\n"),
                    executableURL: executableURL,
                    version: nil,
                    checkedURLs: [executableURL]
                )
            ),
            configPath: temporaryDirectory.appendingPathComponent(".mackup.cfg")
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.cliState, .invalidVersion(path: executableURL, output: "Mackup unknown\n"))
        XCTAssertFalse(viewModel.shouldShowInstallGuide)
    }

    func testInstallGuideOffersCopyableHomebrewAndPipxCommands() {
        XCTAssertEqual(
            MackupInstallGuide.mvp.options,
            [
                MackupInstallOption(
                    id: "homebrew",
                    title: "Homebrew",
                    command: "brew install mackup",
                    executableName: "brew",
                    arguments: ["install", "mackup"]
                ),
                MackupInstallOption(
                    id: "pipx",
                    title: "pipx",
                    command: "pipx install mackup",
                    executableName: "pipx",
                    arguments: ["install", "mackup"]
                )
            ]
        )
    }

    func testInstallSelectedMackupRunsOnlyChosenInstallerAndRefreshesDetection() async {
        let installer = FakeToolRunner(result: CommandLineToolResult(exitCode: 0, output: "ok\n"))
        let detector = SequenceExecutableResolver(
            reports: [
                MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: []),
                MackupDetectionReport(
                    status: .found,
                    executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/mackup"),
                    version: MackupVersion(major: 0, minor: 10, patch: 3),
                    checkedURLs: []
                )
            ]
        )
        let viewModel = DashboardViewModel(
            detector: detector,
            installer: installer,
            configPath: temporaryDirectory.appendingPathComponent(".mackup.cfg")
        )
        await viewModel.refresh()
        viewModel.selectedInstallOptionID = "pipx"

        await viewModel.installSelectedMackup()

        XCTAssertEqual(installer.calls, [ToolCall(executableName: "pipx", arguments: ["install", "mackup"])])
        XCTAssertEqual(viewModel.setupState, .installFinished("ok"))
        XCTAssertEqual(
            viewModel.cliState,
            .available(
                path: URL(fileURLWithPath: "/opt/homebrew/bin/mackup"),
                version: MackupVersion(major: 0, minor: 10, patch: 3)
            )
        )
    }

    func testInstallSelectedMackupReportsInstallerFailure() async {
        let installer = FakeToolRunner(result: CommandLineToolResult(exitCode: 1, output: "no brew\n"))
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            installer: installer,
            configPath: temporaryDirectory.appendingPathComponent(".mackup.cfg")
        )

        await viewModel.installSelectedMackup()

        XCTAssertEqual(viewModel.setupState, .installFailed("no brew"))
    }

    func testCreateDefaultConfigWritesMackupSupportedFieldsOnly() throws {
        let editor = CapturingConfigEditor()
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            configPath: configPath
        )
        viewModel.selectedStorageEngine = .iCloud

        viewModel.createDefaultConfig()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.fileURL, configPath)
        XCTAssertEqual(saved.storage, MackupStorage(engine: .iCloud, path: nil, directory: nil))
        XCTAssertEqual(saved.applicationsToSync, [])
        XCTAssertEqual(saved.applicationsToIgnore, [])
        XCTAssertEqual(viewModel.configState, .present(configPath))
        XCTAssertEqual(viewModel.setupState, .configCreated(configPath))
    }
}

private struct FakeExecutableResolver: MackupExecutableResolving {
    let report: MackupDetectionReport

    func detect(preferredPath: URL?) async -> MackupDetectionReport {
        report
    }
}

private final class SequenceExecutableResolver: MackupExecutableResolving {
    private var reports: [MackupDetectionReport]

    init(reports: [MackupDetectionReport]) {
        self.reports = reports
    }

    func detect(preferredPath: URL?) async -> MackupDetectionReport {
        if reports.count > 1 {
            return reports.removeFirst()
        }
        return reports[0]
    }
}

private struct ToolCall: Equatable {
    let executableName: String
    let arguments: [String]
}

private final class FakeToolRunner: CommandLineToolRunning {
    private(set) var calls: [ToolCall] = []
    private let result: CommandLineToolResult

    init(result: CommandLineToolResult) {
        self.result = result
    }

    func run(executableName: String, arguments: [String]) async throws -> CommandLineToolResult {
        calls.append(ToolCall(executableName: executableName, arguments: arguments))
        return result
    }
}

private final class CapturingConfigEditor: MackupConfigEditing {
    private(set) var savedConfig: MackupConfig?

    func load(path: URL?) throws -> MackupConfig {
        MackupConfig(
            fileURL: path ?? URL(fileURLWithPath: "/tmp/.mackup.cfg"),
            storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
            applicationsToSync: [],
            applicationsToIgnore: [],
            originalText: ""
        )
    }

    func save(_ config: MackupConfig) throws {
        savedConfig = config
    }
}
