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
    private let installedApplicationScanner: InstalledApplicationScanning?
    private let detector: MackupExecutableResolving
    private let parser: MackupApplicationListParser
    private let preferredCLIPath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning
    private let makeIsolatedListRunner: (URL) throws -> MackupCommandRunning

    init(preferredCLIPath: URL? = nil) {
        self.injectedRunner = nil
        self.installedApplicationScanner = InstalledApplicationScanner()
        self.detector = MackupDetector()
        self.parser = MackupApplicationListParser()
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
        self.makeIsolatedListRunner = { try MackupIsolatedListRunnerFactory.makeRunner(executableURL: $0) }
    }

    init(
        runner: MackupCommandRunning,
        parser: MackupApplicationListParser = MackupApplicationListParser(),
        preferredCLIPath: URL? = nil,
        makeIsolatedListRunner: @escaping (URL) throws -> MackupCommandRunning = {
            try MackupIsolatedListRunnerFactory.makeRunner(executableURL: $0)
        }
    ) {
        self.injectedRunner = runner
        self.installedApplicationScanner = nil
        self.detector = MackupDetector()
        self.parser = parser
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
        self.makeIsolatedListRunner = makeIsolatedListRunner
    }

    init(installedApplicationScanner: InstalledApplicationScanning) {
        self.injectedRunner = nil
        self.installedApplicationScanner = installedApplicationScanner
        self.detector = MackupDetector()
        self.parser = MackupApplicationListParser()
        self.preferredCLIPath = nil
        self.makeRunner = { MackupProcessRunner(executableURL: $0) }
        self.makeIsolatedListRunner = { try MackupIsolatedListRunnerFactory.makeRunner(executableURL: $0) }
    }

    init(
        detector: MackupExecutableResolving,
        parser: MackupApplicationListParser = MackupApplicationListParser(),
        preferredCLIPath: URL? = nil,
        makeRunner: @escaping (URL) -> MackupCommandRunning,
        makeIsolatedListRunner: @escaping (URL) throws -> MackupCommandRunning
    ) {
        self.injectedRunner = nil
        self.installedApplicationScanner = nil
        self.detector = detector
        self.parser = parser
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = makeRunner
        self.makeIsolatedListRunner = makeIsolatedListRunner
    }

    func refresh() async {
        state = .loading

        if let installedApplicationScanner {
            do {
                let applications = try installedApplicationScanner.scanInstalledApplications()
                state = applications.isEmpty ? .empty : .loaded(applications)
            } catch {
                state = .failed(error.localizedDescription)
            }
            return
        }

        do {
            let runner = try await resolvedRunner()
            let result = try await runList(using: runner)

            if let exitResult = result.exitResult, exitResult.exitCode != 0 {
                try await refreshWithIsolatedListRunner(afterFailure: result, fallbackRunner: runner)
                return
            }

            publish(stdout: result.stdout)
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

    private func refreshWithIsolatedListRunner(
        afterFailure failure: ListRunOutput,
        fallbackRunner: MackupCommandRunning
    ) async throws {
        let runner: MackupCommandRunning

        if injectedRunner != nil {
            runner = fallbackRunner
        } else {
            let report = await detector.detect(preferredPath: preferredCLIPath)
            guard report.status == .found, let executableURL = report.executableURL else {
                state = .failed(errorMessage(from: failure))
                return
            }

            runner = try makeIsolatedListRunner(executableURL)
        }

        let retry = try await runList(using: runner)
        if let exitResult = retry.exitResult, exitResult.exitCode != 0 {
            state = .failed(errorMessage(from: failure))
            return
        }

        publish(stdout: retry.stdout)
    }

    private func runList(using runner: MackupCommandRunning) async throws -> ListRunOutput {
        var stdout = ""
        var stderr = ""
        var exitResult: ProcessResult?

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

        return ListRunOutput(stdout: stdout, stderr: stderr, exitResult: exitResult)
    }

    private func publish(stdout: String) {
        do {
            let applications = try parser.parse(stdout)
            state = applications.isEmpty ? .empty : .loaded(applications)
        } catch MackupApplicationListParserError.noApplicationsFound {
            state = .empty
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func errorMessage(from result: ListRunOutput) -> String {
        let output = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        if let output {
            return output
        }

        let exitCode = result.exitResult?.exitCode ?? -1
        return "mackup list exited with status \(exitCode)."
    }
}

private struct ListRunOutput {
    var stdout: String
    var stderr: String
    var exitResult: ProcessResult?
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

private enum MackupIsolatedListRunnerFactory {
    static func makeRunner(executableURL: URL, fileManager: FileManager = .default) throws -> MackupCommandRunning {
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("YAMG-MackupList-\(UUID().uuidString)", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("storage", isDirectory: true)
        let configURL = rootURL.appendingPathComponent(".mackup.cfg")

        try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        let config = """
        [storage]
        engine = file_system
        path = \(storageURL.path)
        directory = Mackup
        """
        try config.write(to: configURL, atomically: true, encoding: .utf8)

        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = rootURL.path
        environment["MACKUP_CONFIG"] = nil
        environment["XDG_CONFIG_HOME"] = rootURL.appendingPathComponent(".config", isDirectory: true).path

        return MackupProcessRunner(
            executableURL: executableURL,
            fileManager: fileManager,
            launchEnvironment: ProcessLaunchEnvironment(
                environment: environment,
                temporaryDirectory: rootURL
            )
        )
    }
}
