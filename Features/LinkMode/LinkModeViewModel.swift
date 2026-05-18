import Foundation

@MainActor
final class LinkModeViewModel: ObservableObject {
    enum Operation: String, CaseIterable, Equatable, Identifiable {
        case install
        case link
        case uninstall

        var id: String { rawValue }
    }

    enum State: Equatable {
        case idle
        case confirming(Operation)
        case running(Operation)
        case finished(Operation, ProcessResult)
        case failed(Operation?, String)
    }

    @Published var selectedOperation: Operation = .install
    @Published var acknowledgedRisk: Bool = false
    @Published var verbose: Bool = false
    @Published private(set) var state: State = .idle
    @Published private(set) var output: String = ""

    private let injectedRunner: MackupCommandRunning?
    private let detector: MackupExecutableResolving
    private let logStore: ProcessLogPersisting
    private let preferredCLIPath: URL?
    private let configFilePath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning

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

    func requestSelectedOperation() {
        guard acknowledgedRisk, !isRunning else {
            return
        }

        state = .confirming(selectedOperation)
    }

    func cancelConfirmation() {
        if case .confirming = state {
            state = .idle
        }
    }

    func confirm() async {
        guard case .confirming(let operation) = state else {
            return
        }

        await run(operation)
    }

    private func run(_ operation: Operation) async {
        state = .running(operation)
        output = ""

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
            verbose: verbose,
            configFile: configFilePath
        )

        switch operation {
        case .install:
            return .linkInstall(options: options)
        case .link:
            return .link(options: options)
        case .uninstall:
            return .linkUninstall(options: options)
        }
    }

    private func resolvedRunner() async throws -> MackupCommandRunning {
        if let injectedRunner {
            return injectedRunner
        }

        let report = await detector.detect(preferredPath: preferredCLIPath)
        guard report.status == .found, let executableURL = report.executableURL else {
            throw LinkModeError.mackupUnavailable(report.status.userFacingDescription)
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

private enum LinkModeError: LocalizedError, Equatable {
    case mackupUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .mackupUnavailable(let message):
            return message
        }
    }
}
