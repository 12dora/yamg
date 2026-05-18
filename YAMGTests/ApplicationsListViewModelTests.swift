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
