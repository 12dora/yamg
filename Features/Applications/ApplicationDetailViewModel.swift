import Foundation

@MainActor
final class ApplicationDetailViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading(String)
        case loaded(MackupApplicationDetail)
        case failed(applicationName: String, message: String)
    }

    @Published private(set) var state: State = .idle

    private let injectedRunner: MackupCommandRunning?
    private let detector: MackupExecutableResolving
    private let parser: MackupApplicationDetailParser
    private let preferredCLIPath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning

    init(preferredCLIPath: URL? = nil) {
        self.injectedRunner = nil
        self.detector = MackupDetector()
        self.parser = MackupApplicationDetailParser()
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
    }

    init(
        runner: MackupCommandRunning,
        parser: MackupApplicationDetailParser = MackupApplicationDetailParser(),
        preferredCLIPath: URL? = nil
    ) {
        self.injectedRunner = runner
        self.detector = MackupDetector()
        self.parser = parser
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
    }

    func load(applicationName: String) async {
        state = .loading(applicationName)

        var stdout = ""
        var stderr = ""
        var exitResult: ProcessResult?

        do {
            let runner = try await resolvedRunner()
            let command = try MackupCommand.show(application: applicationName)

            for try await event in runner.run(command) {
                switch event {
                case .output(let output, .stdout):
                    stdout += output
                case .output(let output, .stderr):
                    stderr += output
                case .finished(let result):
                    exitResult = result
                }
            }

            // `.task(id: selectedApplicationName)` cancels this load when the
            // selection changes. A consumer-cancelled AsyncThrowingStream ends
            // without throwing, so without this check we would parse the partial
            // output and overwrite the newer selection's state with the old app's.
            if Task.isCancelled { return }

            if let exitResult, exitResult.exitCode != 0 {
                state = .failed(
                    applicationName: applicationName,
                    message: errorMessage(stdout: stdout, stderr: stderr, exitCode: exitResult.exitCode)
                )
                return
            }

            let detail = try parser.parse(stdout, applicationName: applicationName)
            state = .loaded(detail)
        } catch {
            // Cancellation can surface here (e.g. parse of truncated output) — don't
            // clobber the newer selection's state with a stale failure.
            if Task.isCancelled { return }
            state = .failed(applicationName: applicationName, message: error.localizedDescription)
        }
    }

    private func resolvedRunner() async throws -> MackupCommandRunning {
        if let injectedRunner {
            return injectedRunner
        }

        let report = await detector.detect(preferredPath: preferredCLIPath)
        guard report.status == .found, let executableURL = report.executableURL else {
            throw ApplicationDetailError.mackupUnavailable(report.status.userFacingDescription)
        }

        return makeRunner(executableURL)
    }

    private func errorMessage(stdout: String, stderr: String, exitCode: Int32) -> String {
        let output = [stderr, stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        if let output {
            return output
        }

        return "mackup show exited with status \(exitCode)."
    }
}

private enum ApplicationDetailError: LocalizedError, Equatable {
    case mackupUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .mackupUnavailable(let message):
            return message
        }
    }
}
