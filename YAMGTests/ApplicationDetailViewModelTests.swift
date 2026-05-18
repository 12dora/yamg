import XCTest
@testable import YAMG

@MainActor
final class ApplicationDetailViewModelTests: XCTestCase {
    func testLoadRunsMackupShowAndLoadsDetail() async {
        let runner = DetailFakeMackupCommandRunner(
            events: [
                .output("Name: Git\nConfiguration files:\n - .gitconfig\n", stream: .stdout),
                .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
            ]
        )
        let viewModel = ApplicationDetailViewModel(runner: runner)

        await viewModel.load(applicationName: "git")

        XCTAssertEqual(runner.commands, [try MackupCommand.show(application: "git")])
        XCTAssertEqual(
            viewModel.state,
            .loaded(
                MackupApplicationDetail(
                    applicationName: "git",
                    displayName: "Git",
                    configurationFiles: [".gitconfig"]
                )
            )
        )
    }

    func testLoadReportsNonZeroExitAsFailure() async {
        let viewModel = ApplicationDetailViewModel(
            runner: DetailFakeMackupCommandRunner(
                events: [
                    .output("Unsupported application: nope\n", stream: .stderr),
                    .finished(ProcessResult(exitCode: 1, terminationReason: .exit))
                ]
            )
        )

        await viewModel.load(applicationName: "nope")

        XCTAssertEqual(
            viewModel.state,
            .failed(applicationName: "nope", message: "Unsupported application: nope")
        )
    }

    func testLoadReportsParserFailure() async {
        let viewModel = ApplicationDetailViewModel(
            runner: DetailFakeMackupCommandRunner(
                events: [
                    .output("Configuration files:\n - .gitconfig\n", stream: .stdout),
                    .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
                ]
            )
        )

        await viewModel.load(applicationName: "git")

        if case .failed(let applicationName, _) = viewModel.state {
            XCTAssertEqual(applicationName, "git")
        } else {
            XCTFail("Expected failed state")
        }
    }
}

private final class DetailFakeMackupCommandRunner: MackupCommandRunning {
    private(set) var commands: [MackupCommand] = []
    private let events: [ProcessEvent]

    init(events: [ProcessEvent]) {
        self.events = events
    }

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        commands.append(command)

        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
