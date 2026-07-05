import Foundation

protocol MackupSupportedApplicationCataloging {
    func supportedApplicationIdentifiers() async throws -> [String]
}

enum MackupSupportedApplicationCatalogError: LocalizedError, Equatable {
    case mackupUnavailable(String)
    case listFailed(String)

    var errorDescription: String? {
        switch self {
        case .mackupUnavailable(let message), .listFailed(let message):
            return message
        }
    }
}

final class MackupSupportedApplicationCatalog: MackupSupportedApplicationCataloging {
    private let detector: MackupExecutableResolving
    private let parser: MackupApplicationListParser
    private let preferredCLIPath: URL?
    private let makeRunner: (URL) -> MackupCommandRunning
    private let makeIsolatedListRunner: (URL) throws -> MackupCommandRunning

    init(
        detector: MackupExecutableResolving = MackupDetector(),
        parser: MackupApplicationListParser = MackupApplicationListParser(),
        preferredCLIPath: URL? = nil,
        makeRunner: @escaping (URL) -> MackupCommandRunning = { MackupProcessRunner(executableURL: $0) },
        makeIsolatedListRunner: @escaping (URL) throws -> MackupCommandRunning = {
            try MackupIsolatedListRunnerFactory.makeRunner(executableURL: $0)
        }
    ) {
        self.detector = detector
        self.parser = parser
        self.preferredCLIPath = preferredCLIPath
        self.makeRunner = makeRunner
        self.makeIsolatedListRunner = makeIsolatedListRunner
    }

    func supportedApplicationIdentifiers() async throws -> [String] {
        let report = await detector.detect(preferredPath: preferredCLIPath)
        guard report.status == .found, let executableURL = report.executableURL else {
            throw MackupSupportedApplicationCatalogError.mackupUnavailable(report.status.userFacingDescription)
        }

        let runner = makeRunner(executableURL)
        let primary = try await runList(using: runner)

        if let result = primary.exitResult, result.exitCode != 0 {
            let isolatedRunner = try makeIsolatedListRunner(executableURL)
            let retry = try await runList(using: isolatedRunner)
            if let retryResult = retry.exitResult, retryResult.exitCode != 0 {
                throw MackupSupportedApplicationCatalogError.listFailed(errorMessage(from: primary))
            }
            return try parseIdentifiers(from: retry.stdout)
        }

        return try parseIdentifiers(from: primary.stdout)
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

    private func parseIdentifiers(from stdout: String) throws -> [String] {
        do {
            let apps = try parser.parse(stdout)
            return apps.map(\.name)
        } catch MackupApplicationListParserError.noApplicationsFound {
            return []
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

enum MackupIsolatedListRunnerFactory {
    static func makeRunner(executableURL: URL, fileManager: FileManager = .default) throws -> MackupCommandRunning {
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("YAMG-MackupList-\(UUID().uuidString)", isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("storage", isDirectory: true)
        let configURL = rootURL.appendingPathComponent(".mackup.cfg")

        try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        // Ownership of temp-dir cleanup passes to the returned runner. If we throw
        // before handing it off (e.g. config.write fails after the mkdir), remove
        // the partially-created directory so it isn't orphaned under NSTemporaryDirectory.
        var handedOff = false
        defer {
            if !handedOff {
                try? fileManager.removeItem(at: rootURL)
            }
        }

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

        let runner = MackupProcessRunner(
            executableURL: executableURL,
            fileManager: fileManager,
            launchEnvironment: ProcessLaunchEnvironment(
                environment: environment,
                temporaryDirectory: rootURL
            )
        )
        handedOff = true
        return runner
    }
}
