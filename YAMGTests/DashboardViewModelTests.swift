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
        XCTAssertEqual(viewModel.saveButtonTitleKey, "setup.config.update")
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
            storageDetector: fileSystemOnlyStorageDetector(),
            configPath: configPath
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.cliState, .unavailable)
        XCTAssertEqual(viewModel.configState, .missing(configPath))
        XCTAssertTrue(viewModel.shouldShowInstallGuide)
        XCTAssertEqual(viewModel.selectedStorageEngine, .fileSystem)
        XCTAssertEqual(viewModel.saveButtonTitleKey, "setup.config.create")
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

    func testSaveStorageConfigCreatesNewFileWithMackupSupportedFieldsOnly() throws {
        let editor = CapturingConfigEditor()
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(
                        engine: .dropbox,
                        detectedPath: nil,
                        isAvailable: false,
                        detail: "missing"
                    ),
                    MackupStorageAvailability(
                        engine: .googleDrive,
                        detectedPath: nil,
                        isAvailable: false,
                        detail: "missing"
                    ),
                    MackupStorageAvailability(
                        engine: .iCloud,
                        detectedPath: temporaryDirectory.appendingPathComponent("iCloud").path,
                        isAvailable: true,
                        detail: temporaryDirectory.appendingPathComponent("iCloud").path
                    ),
                    MackupStorageAvailability(
                        engine: .fileSystem,
                        detectedPath: nil,
                        isAvailable: true,
                        detail: "Choose"
                    )
                ]
            ),
            configPath: configPath
        )
        viewModel.selectStorageEngine(.iCloud)
        viewModel.selectStorageFolder(temporaryDirectory.appendingPathComponent("iCloud/Mackup"))

        viewModel.saveStorageConfig()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.fileURL, configPath)
        XCTAssertEqual(saved.storage, MackupStorage(engine: .iCloud, path: nil, directory: nil))
        XCTAssertEqual(saved.applicationsToSync, [])
        XCTAssertEqual(saved.applicationsToIgnore, [])
        XCTAssertEqual(viewModel.configState, .present(configPath))
        XCTAssertEqual(viewModel.setupState, .configSaved(configPath))
    }

    func testSaveStorageConfigRequiresStorageProviderAndFolder() {
        let editor = CapturingConfigEditor()
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            ),
            configPath: configPath
        )

        viewModel.saveStorageConfig()

        XCTAssertNil(editor.savedConfig)
        XCTAssertEqual(
            viewModel.setupState,
            .configSaveFailed("Choose an available storage provider and Mackup folder before saving the config.")
        )
    }

    func testSaveStorageConfigPreservesExistingApplicationLists() throws {
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try "[storage]\nengine = dropbox\n[applications_to_sync]\ngit\n[applications_to_ignore]\nxcode\n"
            .write(to: configPath, atomically: true, encoding: .utf8)

        let editor = MackupConfigEditor()
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            ),
            configPath: configPath
        )
        viewModel.selectStorageEngine(.fileSystem)
        viewModel.selectStorageFolder(temporaryDirectory.appendingPathComponent("Backup/Mackup"))

        viewModel.saveStorageConfig()

        let reloaded = try editor.load(path: configPath)
        XCTAssertEqual(reloaded.storage.engine, .fileSystem)
        XCTAssertEqual(reloaded.applicationsToSync, ["git"])
        XCTAssertEqual(reloaded.applicationsToIgnore, ["xcode"])
    }

    func testSaveStorageConfigWritesFileSystemPathAndDirectory() throws {
        let editor = CapturingConfigEditor()
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            ),
            configPath: configPath
        )
        viewModel.selectStorageEngine(.fileSystem)
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Sync/Mackup"))

        viewModel.saveStorageConfig()

        XCTAssertEqual(
            try XCTUnwrap(editor.savedConfig).storage,
            MackupStorage(engine: .fileSystem, path: "/Users/test/Sync", directory: "Mackup")
        )
    }

    func testSaveStorageConfigWritesAutomaticProviderRelativeDirectory() throws {
        let editor = CapturingConfigEditor()
        let configPath = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let viewModel = DashboardViewModel(
            detector: FakeExecutableResolver(
                report: MackupDetectionReport(status: .notFound, executableURL: nil, version: nil, checkedURLs: [])
            ),
            configEditor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: "/Users/test/Dropbox", isAvailable: true, detail: "/Users/test/Dropbox"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            ),
            configPath: configPath
        )
        viewModel.selectStorageEngine(.dropbox)
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Dropbox/Dotfiles/Mackup"))

        viewModel.saveStorageConfig()

        XCTAssertEqual(
            try XCTUnwrap(editor.savedConfig).storage,
            MackupStorage(engine: .dropbox, path: nil, directory: "Dotfiles/Mackup")
        )
    }
}

private func fileSystemOnlyStorageDetector() -> FakeStorageDetector {
    FakeStorageDetector(
        items: [
            MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
            MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
            MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
            MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
        ]
    )
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

private struct FakeStorageDetector: MackupStorageDetecting {
    let items: [MackupStorageAvailability]

    func availability() -> [MackupStorageAvailability] {
        items
    }
}
