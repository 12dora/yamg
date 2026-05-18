import Foundation

struct RunRecord: Equatable, Identifiable {
    enum Status: Equatable {
        case running
        case finished(ProcessResult)
        case failed(String)
    }

    let id: UUID
    let command: MackupCommand
    let startedAt: Date
    var finishedAt: Date?
    var status: Status
}

struct ProcessLogEntry: Equatable, Identifiable {
    let id: UUID
    let runID: UUID
    let timestamp: Date
    let event: ProcessEvent
}

protocol ProcessLogPersisting {
    func createRun(command: MackupCommand) async throws -> RunRecord
    func append(_ event: ProcessEvent, to runID: UUID) async throws
    func finish(runID: UUID, result: ProcessResult) async throws
}

enum ProcessLogStoreError: Error, Equatable {
    case runNotFound(UUID)
}

actor ProcessLogStore: ProcessLogPersisting {
    private var runRecords: [UUID: RunRecord] = [:]
    private var runOrder: [UUID] = []
    private var logEntriesByRunID: [UUID: [ProcessLogEntry]] = [:]
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.now = now
        self.makeID = makeID
    }

    func createRun(command: MackupCommand) async throws -> RunRecord {
        let id = makeID()
        let record = RunRecord(
            id: id,
            command: command,
            startedAt: now(),
            finishedAt: nil,
            status: .running
        )

        runRecords[id] = record
        runOrder.append(id)
        logEntriesByRunID[id] = []

        return record
    }

    func append(_ event: ProcessEvent, to runID: UUID) async throws {
        guard runRecords[runID] != nil else {
            throw ProcessLogStoreError.runNotFound(runID)
        }

        let entry = ProcessLogEntry(
            id: makeID(),
            runID: runID,
            timestamp: now(),
            event: event
        )

        logEntriesByRunID[runID, default: []].append(entry)
    }

    func finish(runID: UUID, result: ProcessResult) async throws {
        guard var record = runRecords[runID] else {
            throw ProcessLogStoreError.runNotFound(runID)
        }

        record.finishedAt = now()
        record.status = .finished(result)
        runRecords[runID] = record
    }

    func fail(runID: UUID, message: String) async throws {
        guard var record = runRecords[runID] else {
            throw ProcessLogStoreError.runNotFound(runID)
        }

        record.finishedAt = now()
        record.status = .failed(message)
        runRecords[runID] = record
    }

    func runs() -> [RunRecord] {
        runOrder.compactMap { runRecords[$0] }
    }

    func run(id: UUID) -> RunRecord? {
        runRecords[id]
    }

    func entries(for runID: UUID) -> [ProcessLogEntry] {
        logEntriesByRunID[runID, default: []]
    }
}
