import Foundation

@MainActor
final class ApplicationsListViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([MackupApplication])
        case empty
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let injectedRunner: MackupCommandRunning?
    private let detector: MackupExecutableResolving
    private let parser: MackupApplicationListParser
    private let preferredCLIPath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning

    init(preferredCLIPath: URL? = nil) {
        self.injectedRunner = nil
        self.detector = MackupDetector()
        self.parser = MackupApplicationListParser()
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
    }

    init(
        runner: MackupCommandRunning,
        parser: MackupApplicationListParser = MackupApplicationListParser(),
        preferredCLIPath: URL? = nil
    ) {
        self.injectedRunner = runner
        self.detector = MackupDetector()
        self.parser = parser
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
    }

    func refresh() async {
        state = .loading

        var stdout = ""
        var stderr = ""
        var exitResult: ProcessResult?

        do {
            let runner = try await resolvedRunner()

            for try await event in runner.run(MackupCommand.list()) {
                switch event {
                case .output(let output, .stdout):
                    stdout += output
                case .output(let output, .stderr):
                    stderr += output
                case .finished(let result):
                    exitResult = result
                }
            }

            if let exitResult, exitResult.exitCode != 0 {
                state = .failed(errorMessage(stdout: stdout, stderr: stderr, exitCode: exitResult.exitCode))
                return
            }

            let applications = try parser.parse(stdout)
            state = applications.isEmpty ? .empty : .loaded(applications)
        } catch MackupApplicationListParserError.noApplicationsFound {
            state = .empty
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func resolvedRunner() async throws -> MackupCommandRunning {
        if let injectedRunner {
            return injectedRunner
        }

        let report = await detector.detect(preferredPath: preferredCLIPath)
        guard report.status == .found, let executableURL = report.executableURL else {
            throw ApplicationsListError.mackupUnavailable(report.status.userFacingDescription)
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

        return "mackup list exited with status \(exitCode)."
    }
}

private enum ApplicationsListError: LocalizedError, Equatable {
    case mackupUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .mackupUnavailable(let message):
            return message
        }
    }
}
