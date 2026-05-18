import XCTest
@testable import YAMG

final class ProcessLogStoreTests: XCTestCase {
    func testCreateRunStoresRunningRecord() async throws {
        let ids = IDSequence([
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        ])
        let dates = DateSequence([Date(timeIntervalSince1970: 10)])
        let store = ProcessLogStore(now: dates.next, makeID: ids.next)

        let run = try await store.createRun(command: .backup())

        XCTAssertEqual(run.id, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(run.command, .backup())
        XCTAssertEqual(run.startedAt, Date(timeIntervalSince1970: 10))
        XCTAssertNil(run.finishedAt)
        XCTAssertEqual(run.status, .running)
    }

    func testAppendStoresEventsInOrder() async throws {
        let ids = IDSequence([
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        ])
        let dates = DateSequence([
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 11),
            Date(timeIntervalSince1970: 12)
        ])
        let store = ProcessLogStore(now: dates.next, makeID: ids.next)
        let run = try await store.createRun(command: .restore())

        try await store.append(.output("one", stream: .stdout), to: run.id)
        try await store.append(.output("two", stream: .stderr), to: run.id)

        let entries = await store.entries(for: run.id)
        XCTAssertEqual(entries.map(\.event), [
            .output("one", stream: .stdout),
            .output("two", stream: .stderr)
        ])
        XCTAssertEqual(entries.map(\.timestamp), [
            Date(timeIntervalSince1970: 11),
            Date(timeIntervalSince1970: 12)
        ])
    }

    func testFinishUpdatesRunResult() async throws {
        let ids = IDSequence([
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        ])
        let dates = DateSequence([
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 13)
        ])
        let store = ProcessLogStore(now: dates.next, makeID: ids.next)
        let run = try await store.createRun(command: .list())
        let result = ProcessResult(exitCode: 0, terminationReason: .exit)

        try await store.finish(runID: run.id, result: result)

        let updatedRun = await store.run(id: run.id)
        XCTAssertEqual(updatedRun?.finishedAt, Date(timeIntervalSince1970: 13))
        XCTAssertEqual(updatedRun?.status, .finished(result))
    }

    func testAppendThrowsForUnknownRun() async {
        let store = ProcessLogStore()
        let missingID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

        do {
            try await store.append(.output("orphan", stream: .stdout), to: missingID)
            XCTFail("Expected missing run error")
        } catch {
            XCTAssertEqual(error as? ProcessLogStoreError, .runNotFound(missingID))
        }
    }
}

private final class IDSequence: @unchecked Sendable {
    private var values: [UUID]

    init(_ values: [UUID]) {
        self.values = values
    }

    func next() -> UUID {
        values.removeFirst()
    }
}

private final class DateSequence: @unchecked Sendable {
    private var values: [Date]

    init(_ values: [Date]) {
        self.values = values
    }

    func next() -> Date {
        values.removeFirst()
    }
}
