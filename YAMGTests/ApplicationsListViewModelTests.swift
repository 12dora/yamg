import XCTest
@testable import YAMG

@MainActor
final class ApplicationsListViewModelTests: XCTestCase {
    func testRefreshLoadsApplicationsFromListOutput() async {
        let viewModel = ApplicationsListViewModel(
            runner: FakeMackupCommandRunner(
                events: [
                    .output("Supported applications:\n - git\n", stream: .stdout),
                    .output(" - zsh\n", stream: .stdout),
                    .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
                ]
            )
        )

        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.state,
            .loaded([
                MackupApplication(name: "git"),
                MackupApplication(name: "zsh")
            ])
        )
    }

    func testRefreshReportsNonZeroExitAsFailure() async {
        let viewModel = ApplicationsListViewModel(
            runner: FakeMackupCommandRunner(
                events: [
                    .output("boom\n", stream: .stderr),
                    .finished(ProcessResult(exitCode: 1, terminationReason: .exit))
                ]
            )
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .failed("boom"))
    }

    func testRefreshRetriesInIsolatedListEnvironmentWhenUserConfigBreaksList() async {
        let executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mackup")
        var primaryURLs: [URL] = []
        var isolatedURLs: [URL] = []
        let viewModel = ApplicationsListViewModel(
            detector: FakeApplicationsExecutableResolver(
                report: MackupDetectionReport(
                    status: .found,
                    executableURL: executableURL,
                    version: MackupVersion(major: 0, minor: 10, patch: 3),
                    checkedURLs: [executableURL]
                )
            ),
            makeRunner: { url in
                primaryURLs.append(url)
                return FakeMackupCommandRunner(
                    events: [
                        .output("Error: Unable to find your Google Drive install =(\n", stream: .stderr),
                        .finished(ProcessResult(exitCode: 1, terminationReason: .exit))
                    ]
                )
            },
            makeIsolatedListRunner: { url in
                isolatedURLs.append(url)
                return FakeMackupCommandRunner(
                    events: [
                        .output("Supported applications:\n - git\n - raycast\n", stream: .stdout),
                        .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
                    ]
                )
            }
        )

        await viewModel.refresh()

        XCTAssertEqual(primaryURLs, [executableURL])
        XCTAssertEqual(isolatedURLs, [executableURL])
        XCTAssertEqual(
            viewModel.state,
            .loaded([
                MackupApplication(name: "git"),
                MackupApplication(name: "raycast")
            ])
        )
    }

    func testRefreshReportsEmptyList() async {
        let viewModel = ApplicationsListViewModel(
            runner: FakeMackupCommandRunner(
                events: [
                    .output("Supported applications:\n", stream: .stdout),
                    .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
                ]
            )
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .empty)
    }
}

private struct FakeApplicationsExecutableResolver: MackupExecutableResolving {
    let report: MackupDetectionReport

    func detect(preferredPath: URL?) async -> MackupDetectionReport {
        report
    }
}

private struct FakeMackupCommandRunner: MackupCommandRunning {
    let events: [ProcessEvent]

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        XCTAssertEqual(command, MackupCommand.list())

        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
