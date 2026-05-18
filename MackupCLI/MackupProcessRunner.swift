import Foundation

enum ProcessOutputStream: Equatable {
    case stdout
    case stderr
}

struct ProcessResult: Equatable {
    let exitCode: Int32
    let terminationReason: Process.TerminationReason
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

    init(executableURL: URL, fileManager: FileManager = .default) {
        self.executableURL = executableURL
        self.fileManager = fileManager
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
