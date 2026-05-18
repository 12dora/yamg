import Foundation

enum ProcessOutputStream: Equatable {
    case stdout
    case stderr
}

struct ProcessResult: Equatable {
    let exitCode: Int32
    let terminationReason: Process.TerminationReason
}

struct ProcessLaunchEnvironment: Equatable {
    var environment: [String: String]
    var temporaryDirectory: URL?

    static let current = ProcessLaunchEnvironment(environment: ProcessInfo.processInfo.environment)
}

enum ProcessEvent: Equatable {
    case output(String, stream: ProcessOutputStream)
    case finished(ProcessResult)
}

enum MackupProcessRunnerError: Error, Equatable {
    case executableNotFound(URL)
}

protocol MackupCommandRunning {
    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error>
}

final class MackupProcessRunner: MackupCommandRunning {
    private let executableURL: URL
    private let fileManager: FileManager
    private let launchEnvironment: ProcessLaunchEnvironment

    init(
        executableURL: URL,
        fileManager: FileManager = .default,
        launchEnvironment: ProcessLaunchEnvironment = .current
    ) {
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.launchEnvironment = launchEnvironment
    }

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            guard fileManager.isExecutableFile(atPath: executableURL.path) else {
                continuation.finish(throwing: MackupProcessRunnerError.executableNotFound(executableURL))
                return
            }

            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let queue = DispatchQueue(label: "app.yamg.mackup-process-runner")

            process.executableURL = executableURL
            process.arguments = command.arguments
            process.environment = launchEnvironment.environment
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let yieldOutput: (FileHandle, ProcessOutputStream) -> Void = { handle, stream in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                    return
                }

                queue.async {
                    continuation.yield(.output(output, stream: stream))
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                yieldOutput(handle, .stdout)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                yieldOutput(handle, .stderr)
            }

            process.terminationHandler = { terminatedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                yieldOutput(stdoutPipe.fileHandleForReading, .stdout)
                yieldOutput(stderrPipe.fileHandleForReading, .stderr)

                queue.async {
                    if let temporaryDirectory = self.launchEnvironment.temporaryDirectory {
                        try? self.fileManager.removeItem(at: temporaryDirectory)
                    }

                    continuation.yield(
                        .finished(
                            ProcessResult(
                                exitCode: terminatedProcess.terminationStatus,
                                terminationReason: terminatedProcess.terminationReason
                            )
                        )
                    )
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if process.isRunning {
                    process.terminate()
                }

                if let temporaryDirectory = self.launchEnvironment.temporaryDirectory {
                    try? self.fileManager.removeItem(at: temporaryDirectory)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish(throwing: error)
            }
        }
    }
}
