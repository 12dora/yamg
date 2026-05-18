import XCTest
@testable import YAMG

final class MackupProcessRunnerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testRunnerStreamsStdoutStderrAndExitCode() async throws {
        let script = try makeExecutableScript(
            """
            #!/bin/sh
            printf 'stdout:%s\\n' "$1"
            printf 'stderr:%s\\n' "$2" >&2
            exit 7
            """
        )
        let runner = MackupProcessRunner(executableURL: script)

        let events = try await collectEvents(from: runner.run(try .show(application: "vim")))

        XCTAssertTrue(events.contains(.output("stdout:show\n", stream: .stdout)))
        XCTAssertTrue(events.contains(.output("stderr:vim\n", stream: .stderr)))
        XCTAssertEqual(events.last, .finished(ProcessResult(exitCode: 7, terminationReason: .exit)))
    }

    func testRunnerPassesConfigFlagBeforeCommandArguments() async throws {
        let script = try makeExecutableScript(
            """
            #!/bin/sh
            printf '%s|%s\\n' "$1" "$2"
            """
        )
        let runner = MackupProcessRunner(executableURL: script)
        let command = MackupCommand.backup(
            options: .init(configFile: URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg"))
        )

        let events = try await collectEvents(from: runner.run(command))

        XCTAssertTrue(events.contains(.output("--config-file=/tmp/yamg/.mackup.cfg|backup\n", stream: .stdout)))
        XCTAssertEqual(events.last, .finished(ProcessResult(exitCode: 0, terminationReason: .exit)))
    }

    func testRunnerPassesLaunchEnvironmentAndCleansTemporaryDirectory() async throws {
        let script = try makeExecutableScript(
            """
            #!/bin/sh
            printf 'HOME=%s\\n' "$HOME"
            """
        )
        let runnerTemporaryDirectory = temporaryDirectory
            .appendingPathComponent("runner-home", isDirectory: true)
        try FileManager.default.createDirectory(at: runnerTemporaryDirectory, withIntermediateDirectories: true)
        let runner = MackupProcessRunner(
            executableURL: script,
            launchEnvironment: ProcessLaunchEnvironment(
                environment: ["HOME": runnerTemporaryDirectory.path],
                temporaryDirectory: runnerTemporaryDirectory
            )
        )

        let events = try await collectEvents(from: runner.run(.list()))

        XCTAssertTrue(events.contains(.output("HOME=\(runnerTemporaryDirectory.path)\n", stream: .stdout)))
        XCTAssertEqual(events.last, .finished(ProcessResult(exitCode: 0, terminationReason: .exit)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: runnerTemporaryDirectory.path))
    }

    func testCurrentLaunchEnvironmentIncludesProcessEnvironment() {
        XCTAssertEqual(ProcessLaunchEnvironment.current.environment, ProcessInfo.processInfo.environment)
        XCTAssertNil(ProcessLaunchEnvironment.current.temporaryDirectory)
    }

    func testRunnerFailsForMissingExecutable() async {
        let runner = MackupProcessRunner(
            executableURL: temporaryDirectory.appendingPathComponent("missing-mackup")
        )

        do {
            _ = try await collectEvents(from: runner.run(.list()))
            XCTFail("Expected missing executable error")
        } catch {
            XCTAssertEqual(
                error as? MackupProcessRunnerError,
                .executableNotFound(temporaryDirectory.appendingPathComponent("missing-mackup"))
            )
        }
    }

    private func makeExecutableScript(_ contents: String) throws -> URL {
        let script = temporaryDirectory.appendingPathComponent("fake-mackup-\(UUID().uuidString)")
        try contents.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: script.path
        )
        return script
    }

    private func collectEvents(
        from stream: AsyncThrowingStream<ProcessEvent, Error>
    ) async throws -> [ProcessEvent] {
        var events: [ProcessEvent] = []

        for try await event in stream {
            events.append(event)
        }

        return events
    }
}
