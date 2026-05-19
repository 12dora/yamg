import XCTest
@testable import YAMG

@MainActor
final class OperationFlowViewModelTests: XCTestCase {
    func testBackupDryRunRunsCommandImmediately() async throws {
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
        viewModel.dryRun = true

        viewModel.request(.backup)
        await waitUntil {
            if case .finished(.backup, _) = viewModel.state {
                return true
            }
            return false
        }

        XCTAssertEqual(runner.commands, [.backup(options: .init(dryRun: true, forceAnswer: .yes))])
        XCTAssertEqual(viewModel.output, "preview\n")
        XCTAssertEqual(
            viewModel.state,
            .finished(.backup, ProcessResult(exitCode: 0, terminationReason: .exit))
        )
        let runs = await logStore.runs()
        XCTAssertEqual(runs.first?.command, .backup(options: .init(dryRun: true, forceAnswer: .yes)))
    }

    func testRestoreCanRunWithoutDryRunImmediately() async {
        let runner = OperationFakeRunner(
            events: [.finished(ProcessResult(exitCode: 0, terminationReason: .exit))]
        )
        let viewModel = OperationFlowViewModel(runner: runner)
        viewModel.dryRun = false

        viewModel.request(.restore)
        await waitUntil {
            !runner.commands.isEmpty
        }

        XCTAssertEqual(runner.commands, [.restore(options: .init(forceAnswer: .yes))])
    }

    func testOperationUsesPreferredConfigPathInCommand() async {
        let runner = OperationFakeRunner(
            events: [.finished(ProcessResult(exitCode: 0, terminationReason: .exit))]
        )
        let configPath = URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg")
        let viewModel = OperationFlowViewModel(runner: runner, configFilePath: configPath)

        viewModel.request(.backup)
        await waitUntil {
            !runner.commands.isEmpty
        }

        XCTAssertEqual(
            runner.commands,
            [.backup(options: .init(forceAnswer: .yes, configFile: configPath))]
        )
    }

    func testRequestWhileRunningDoesNotStartAnotherCommand() async {
        let runner = OperationSuspendingRunner()
        let viewModel = OperationFlowViewModel(runner: runner)

        viewModel.request(.restore)
        await waitUntil {
            !runner.commands.isEmpty
        }
        viewModel.request(.backup)

        XCTAssertEqual(runner.commands, [.restore(options: .init(forceAnswer: .yes))])
    }

    func testRunnerFailurePublishesFailedState() async {
        let viewModel = OperationFlowViewModel(
            runner: OperationFailingRunner(error: OperationTestError.expected)
        )

        viewModel.request(.backup)
        await waitUntil {
            if case .failed(.backup, _) = viewModel.state {
                return true
            }
            return false
        }

        if case .failed(.backup, _) = viewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed backup state")
        }
    }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @MainActor @escaping () -> Bool
) async {
    let start = DispatchTime.now().uptimeNanoseconds

    while await !condition(), DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
        try? await Task.sleep(nanoseconds: 10_000_000)
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

private final class OperationSuspendingRunner: MackupCommandRunning {
    private(set) var commands: [MackupCommand] = []

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        commands.append(command)

        return AsyncThrowingStream { _ in }
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
