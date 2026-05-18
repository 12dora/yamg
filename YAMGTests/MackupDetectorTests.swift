import XCTest
@testable import YAMG

final class MackupDetectorTests: XCTestCase {
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

    func testVersionParserAcceptsMackupVersionOutput() {
        XCTAssertEqual(
            MackupVersionParser.parse("Mackup 0.10.3\n"),
            MackupVersion(major: 0, minor: 10, patch: 3)
        )
    }

    func testVersionParserAcceptsNoiseAroundVersion() {
        XCTAssertEqual(
            MackupVersionParser.parse("warning\nMackup version 1.2.30\n"),
            MackupVersion(major: 1, minor: 2, patch: 30)
        )
    }

    func testVersionParserRejectsIncompleteVersion() {
        XCTAssertNil(MackupVersionParser.parse("Mackup 0.10"))
    }

    func testDetectUsesPreferredPathBeforeCandidates() async throws {
        let preferred = try makeExecutable(named: "preferred-mackup")
        let fallback = try makeExecutable(named: "fallback-mackup")
        let detector = MackupDetector(
            candidateURLs: [fallback],
            runnerFactory: { _ in FakeCommandRunner(events: [.output("Mackup 0.10.3\n", stream: .stdout)]) }
        )

        let report = await detector.detect(preferredPath: preferred)

        XCTAssertEqual(report.status, .found)
        XCTAssertEqual(report.executableURL, preferred)
        XCTAssertEqual(report.version, MackupVersion(major: 0, minor: 10, patch: 3))
        XCTAssertEqual(report.checkedURLs, [preferred, fallback])
    }

    func testDetectReportsNotFoundWhenNoCandidateIsExecutable() async {
        let missing = temporaryDirectory.appendingPathComponent("missing-mackup")
        let detector = MackupDetector(candidateURLs: [missing])

        let report = await detector.detect(preferredPath: nil)

        XCTAssertEqual(report.status, .notFound)
        XCTAssertNil(report.executableURL)
        XCTAssertNil(report.version)
        XCTAssertEqual(report.checkedURLs, [missing])
    }

    func testDetectReportsInvalidVersionOutput() async throws {
        let executable = try makeExecutable(named: "mackup")
        let detector = MackupDetector(
            candidateURLs: [executable],
            runnerFactory: { _ in FakeCommandRunner(events: [.output("not a version\n", stream: .stdout)]) }
        )

        let report = await detector.detect(preferredPath: nil)

        XCTAssertEqual(report.status, .invalidVersionOutput("not a version\n"))
        XCTAssertEqual(report.executableURL, executable)
        XCTAssertNil(report.version)
    }

    func testDetectReportsNonZeroVersionCommandExit() async throws {
        let executable = try makeExecutable(named: "mackup")
        let detector = MackupDetector(
            candidateURLs: [executable],
            runnerFactory: { _ in
                FakeCommandRunner(
                    events: [.finished(ProcessResult(exitCode: 12, terminationReason: .exit))]
                )
            }
        )

        let report = await detector.detect(preferredPath: nil)

        XCTAssertEqual(report.status, .failed("mackup --version exited with code 12"))
        XCTAssertEqual(report.executableURL, executable)
        XCTAssertNil(report.version)
    }

    private func makeExecutable(named name: String) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        try "#!/bin/sh\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
        return url
    }
}

private struct FakeCommandRunner: MackupCommandRunning {
    let events: [ProcessEvent]

    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }

            if !events.contains(where: { event in
                if case .finished = event {
                    return true
                }
                return false
            }) {
                continuation.yield(.finished(ProcessResult(exitCode: 0, terminationReason: .exit)))
            }

            continuation.finish()
        }
    }
}
