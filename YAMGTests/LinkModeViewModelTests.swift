import XCTest
@testable import YAMG

@MainActor
final class LinkModeViewModelTests: XCTestCase {
    func testDoesNotRequestOperationWithoutRiskAcknowledgement() {
        let runner = LinkModeFakeRunner(events: [])
        let viewModel = LinkModeViewModel(runner: runner)

        viewModel.requestSelectedOperation()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(runner.commands, [])
    }

    func testLinkInstallRequiresConfirmationAndRunsAllowedCommand() async {
        let runner = LinkModeFakeRunner(
            events: [
                .output("installing\n", stream: .stdout),
                .finished(ProcessResult(exitCode: 0, terminationReason: .exit))
            ]
        )
        let logStore = ProcessLogStore(
            makeID: LinkModeIDSequence([
                UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
            ]).next
        )
        let viewModel = LinkModeViewModel(runner: runner, logStore: logStore)
        viewModel.acknowledgedRisk = true

        viewModel.requestSelectedOperation()
        XCTAssertEqual(viewModel.state, .confirming(.install))

        await viewModel.confirm()

        XCTAssertEqual(runner.commands, [.linkInstall()])
        XCTAssertEqual(viewModel.output, "installing\n")
        XCTAssertEqual(
            viewModel.state,
            .finished(.install, ProcessResult(exitCode: 0, terminationReason: .exit))
        )
        let runs = await logStore.runs()
        XCTAssertEqual(runs.first?.command, .linkInstall())
    }

    func testLinkAndUninstallMapToExplicitAdvancedCommands() async {
        let runner = LinkModeFakeRunner(
            events: [.finished(ProcessResult(exitCode: 0, terminationReason: .exit))]
        )
        let configPath = URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg")
        let viewModel = LinkModeViewModel(runner: runner, configFilePath: configPath)
        viewModel.acknowledgedRisk = true
        viewModel.verbose = true

        viewModel.selectedOperation = .link
        viewModel.requestSelectedOperation()
        await viewModel.confirm()

        viewModel.selectedOperation = .uninstall
        viewModel.requestSelectedOperation()
        await viewModel.confirm()

        XCTAssertEqual(
            runner.commands,
            [
                .link(options: .init(verbose: true, configFile: configPath)),
                .linkUninstall(options: .init(verbose: true, configFile: configPath))
            ]
        )
    }

    func testCancelConfirmationDoesNotRunCommand() {
        let runner = LinkModeFakeRunner(events: [])
        let viewModel = LinkModeViewModel(runner: runner)
        viewModel.acknowledgedRisk = true

        viewModel.requestSelectedOperation()
        viewModel.cancelConfirmation()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(runner.commands, [])
    }
}

private final class LinkModeFakeRunner: MackupCommandRunning {
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

private final class LinkModeIDSequence: @unchecked Sendable {
    private var values: [UUID]

    init(_ values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        values.removeFirst()
    }
}
