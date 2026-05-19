import Foundation

@MainActor
final class OperationFlowViewModel: ObservableObject {
    enum Operation: Equatable {
        case backup
        case restore
    }

    enum State: Equatable {
        case idle
        case running(Operation)
        case finished(Operation, ProcessResult)
        case failed(Operation?, String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var output: String = ""
    @Published var dryRun: Bool = false
    @Published var verbose: Bool = false

    private let injectedRunner: MackupCommandRunning?
    private let detector: MackupExecutableResolving
    private let logStore: ProcessLogPersisting
    private let preferredCLIPath: URL?
    private let configFilePath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning
    private var activeTask: Task<Void, Never>?

    init(
        runner: MackupCommandRunning? = nil,
        detector: MackupExecutableResolving = MackupDetector(),
        logStore: ProcessLogPersisting = ProcessLogStore(),
        preferredCLIPath: URL? = nil,
        configFilePath: URL? = nil,
        makeRunner: @escaping (URL) -> MackupCommandRunning = { MackupProcessRunner(executableURL: $0) }
    ) {
        self.injectedRunner = runner
        self.detector = detector
        self.logStore = logStore
        self.preferredCLIPath = preferredCLIPath
        self.configFilePath = configFilePath
        self.makeRunner = makeRunner
    }

    func request(_ operation: Operation) {
        guard !isRunning else {
            return
        }

        // Flip state synchronously on the main actor so a rapid second call sees
        // .running before its guard check, preventing the double-launch race.
        state = .running(operation)
        output = ""

        activeTask = Task { [weak self] in
            await self?.run(operation)
        }
    }

    private func run(_ operation: Operation) async {
        do {
            let command = command(for: operation)
            let run = try await logStore.createRun(command: command)
            let runner = try await resolvedRunner()

            for try await event in runner.run(command) {
                try await logStore.append(event, to: run.id)

                switch event {
                case .output(let text, _):
                    output += text
                case .finished(let result):
                    try await logStore.finish(runID: run.id, result: result)
                    state = .finished(operation, result)
                }
            }
        } catch {
            state = .failed(operation, error.localizedDescription)
        }
    }

    private func command(for operation: Operation) -> MackupCommand {
        let options = MackupCommand.Options(
            dryRun: dryRun,
            verbose: verbose,
            forceAnswer: .yes,
            configFile: configFilePath
        )

        switch operation {
        case .backup:
            return .backup(options: options)
        case .restore:
            return .restore(options: options)
        }
    }

    private func resolvedRunner() async throws -> MackupCommandRunning {
        if let injectedRunner {
            return injectedRunner
        }

        let report = await detector.detect(preferredPath: preferredCLIPath)
        guard report.status == .found, let executableURL = report.executableURL else {
            throw OperationFlowError.mackupUnavailable(report.status.userFacingDescription)
        }

        return makeRunner(executableURL)
    }

    private var isRunning: Bool {
        if case .running = state {
            return true
        }
        return false
    }
}

private enum OperationFlowError: LocalizedError, Equatable {
    case mackupUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .mackupUnavailable(let message):
            return message
        }
    }
}
