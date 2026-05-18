import XCTest
@testable import YAMG

@MainActor
final class OperationFlowViewModelTests: XCTestCase {
    func testBackupDryRunRequiresConfirmationAndRunsCommand() async throws {
        let runner = OperationFakeRunner(
            events: [
                .output("preview\n", stream: .stdout),
                .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
            ]
        )
        let logStore = ProcessLogStore(
            makeID: OperationIDSequence([
                UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            ]).next
        )
        let viewModel = OperationFlowViewModel(runner: runner, logStore: logStore)

        viewModel.request(.backup)
        XCTAssertEqual(viewModel.state, .confirming(.backup))

        await viewModel.confirm()

        XCTAssertEqual(runner.commands, [.backup(options: .init(dryRun: true))])
        XCTAssertEqual(viewModel.output, "preview\n")
        XCTAssertEqual(
            viewModel.state,
            .finished(.backup, ProcessResult(exitCode: 0, terminationReason: .exit))
        )
        let runs = await logStore.runs()
        XCTAssertEqual(runs.first?.command, .backup(options: .init(dryRun: true)))
    }

    func testRestoreCanRunWithoutDryRunAfterConfirmation() async {
        let runner = OperationFakeRunner(
            events: [.finished(ProcessResult(exitCode: 0, terminationReason: .exit))]
        )
        let viewModel = OperationFlowViewModel(runner: runner)
        viewModel.dryRun = false

        viewModel.request(.restore)
        await viewModel.confirm()

        XCTAssertEqual(runner.commands, [.restore()])
    }

    func testOperationUsesPreferredConfigPathInCommand() async {
        let runner = OperationFakeRunner(
            events: [.finished(ProcessResult(exitCode: 0, terminationReason: .exit))]
        )
        let configPath = URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg")
        let viewModel = OperationFlowViewModel(runner: runner, configFilePath: configPath)

        viewModel.request(.backup)
        await viewModel.confirm()

        XCTAssertEqual(
            runner.commands,
            [.backup(options: .init(dryRun: true, configFile: configPath))]
        )
    }

    func testCancelConfirmationDoesNotRunCommand() {
        let runner = OperationFakeRunner(events: [])
        let viewModel = OperationFlowViewModel(runner: runner)

        viewModel.request(.restore)
        viewModel.cancelConfirmation()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(runner.commands, [])
    }

    func testRunnerFailurePublishesFailedState() async {
        let viewModel = OperationFlowViewModel(
            runner: OperationFailingRunner(error: OperationTestError.expected)
        )

        viewModel.request(.backup)
        await viewModel.confirm()

        if case .failed(.backup, _) = viewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed backup state")
        }
    }
}

private final class OperationFakeRunner: MackupCommandRunning {
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

private struct OperationFailingRunner: MackupCommandRunning {
    let error: Error

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

private enum OperationTestError: Error {
    case expected
}

private final class OperationIDSequence: @unchecked Sendable {
    private var values: [UUID]

    init(_ values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        values.removeFirst()
    }
}
