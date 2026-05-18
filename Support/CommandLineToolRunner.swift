import Foundation

struct CommandLineToolResult: Equatable {
    let exitCode: Int32
    let output: String
}

protocol CommandLineToolRunning {
    func run(executableName: String, arguments: [String]) async throws -> CommandLineToolResult
}

enum CommandLineToolRunnerError: LocalizedError, Equatable {
    case executableNotFound(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "\(name) was not found in common install locations."
        }
    }
}

final class CommandLineToolRunner: CommandLineToolRunning {
    private let fileManager: FileManager
    private let candidateDirectories: [String]

    init(
        fileManager: FileManager = .default,
        candidateDirectories: [String] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
    ) {
        self.fileManager = fileManager
        self.candidateDirectories = candidateDirectories
    }

    func run(executableName: String, arguments: [String]) async throws -> CommandLineToolResult {
        guard let executableURL = executableURL(named: executableName) else {
            throw CommandLineToolRunnerError.executableNotFound(executableName)
        }

        return try await run(executableURL: executableURL, arguments: arguments)
    }

    private func executableURL(named name: String) -> URL? {
        candidateDirectories
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func run(executableURL: URL, arguments: [String]) async throws -> CommandLineToolResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let queue = DispatchQueue(label: "app.yamg.command-line-tool-runner")
            var output = Data()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let appendOutput: (Data) -> Void = { data in
                guard !data.isEmpty else {
                    return
                }

                queue.async {
                    output.append(data)
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                appendOutput(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                appendOutput(handle.availableData)
            }

            process.terminationHandler = { terminatedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                appendOutput(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                appendOutput(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                queue.async {
                    let outputText = String(data: output, encoding: .utf8) ?? ""
                    continuation.resume(
                        returning: CommandLineToolResult(
                            exitCode: terminatedProcess.terminationStatus,
                            output: outputText
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
