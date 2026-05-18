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
    }
}

private struct FakeExecutableResolver: MackupExecutableResolving {
    let report: MackupDetectionReport

    func detect(preferredPath: URL?) async -> MackupDetectionReport {
        report
    }
}
