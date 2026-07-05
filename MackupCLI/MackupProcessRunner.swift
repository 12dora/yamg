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
                // This early return happens before onTermination is registered, so
                // clean up the isolated temp directory here or it would be orphaned.
                if let temporaryDirectory = launchEnvironment.temporaryDirectory {
                    try? fileManager.removeItem(at: temporaryDirectory)
                }
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

            // Per-stream residual byte buffers. Decoding each read chunk in
            // isolation dropped the whole chunk whenever a multi-byte UTF-8
            // character straddled a read boundary. Instead we accumulate raw bytes
            // and only decode the longest complete-UTF-8 prefix, carrying the
            // trailing partial sequence into the next read. Only ever touched on
            // `queue`, so no extra locking is needed.
            var stdoutResidual = Data()
            var stderrResidual = Data()

            let emit: (Data, ProcessOutputStream, Bool) -> Void = { newData, stream, isFinal in
                let combined: Data
                switch stream {
                case .stdout:
                    stdoutResidual.append(newData)
                    combined = stdoutResidual
                case .stderr:
                    stderrResidual.append(newData)
                    combined = stderrResidual
                }

                guard !combined.isEmpty else { return }

                let text: String
                let consumed: Int
                if isFinal {
                    // Best-effort decode of whatever remains (U+FFFD substitution)
                    // so no trailing bytes are silently lost at end of stream.
                    text = String(decoding: combined, as: UTF8.self)
                    consumed = combined.count
                } else {
                    (text, consumed) = MackupProcessRunner.decodableUTF8Prefix(combined)
                }

                if consumed > 0 {
                    switch stream {
                    case .stdout: stdoutResidual.removeFirst(consumed)
                    case .stderr: stderrResidual.removeFirst(consumed)
                    }
                }

                if !text.isEmpty {
                    continuation.yield(.output(text, stream: stream))
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                queue.async { emit(data, .stdout, false) }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                queue.async { emit(data, .stderr, false) }
            }

            process.terminationHandler = { terminatedProcess in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Drain + finish must run on the same serial queue all output
                // is yielded through. Hopping onto the queue guarantees any
                // output blocks enqueued by earlier readability fires execute
                // before the .finished event. Late readability fires whose
                // queue.async slips in afterwards see a finished continuation
                // and their yields are silently dropped.
                queue.async {
                    emit(stdoutPipe.fileHandleForReading.availableData, .stdout, true)
                    emit(stderrPipe.fileHandleForReading.availableData, .stderr, true)

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

    /// Returns the longest prefix of `data` that is valid UTF-8, together with the
    /// number of bytes it consumed. Any trailing bytes of an incomplete multi-byte
    /// sequence (at most 3) are left unconsumed so they can be completed by the
    /// next read.
    private static func decodableUTF8Prefix(_ data: Data) -> (text: String, consumed: Int) {
        if data.isEmpty { return ("", 0) }

        if let whole = String(data: data, encoding: .utf8) {
            return (whole, data.count)
        }

        // A valid UTF-8 character is at most 4 bytes, so only the last 3 bytes can
        // be an incomplete trailing sequence — back off up to that far.
        var length = data.count
        let minLength = max(0, data.count - 3)
        while length > minLength {
            length -= 1
            if let prefix = String(data: data.prefix(length), encoding: .utf8) {
                return (prefix, length)
            }
        }

        // No valid boundary within the trailing 3 bytes: keep everything buffered
        // and wait for more bytes (or the best-effort final flush).
        return ("", 0)
    }
}
