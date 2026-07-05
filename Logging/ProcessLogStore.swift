import Foundation
import Combine

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
    func fail(runID: UUID, message: String) async throws
}

enum ProcessLogStoreError: Error, Equatable {
    case runNotFound(UUID)
}

@MainActor
final class ProcessLogStore: ProcessLogPersisting, ObservableObject {
    nonisolated static let defaultMaxRuns = 100
    nonisolated static let defaultMaxEntriesPerRun = 5_000

    @Published private(set) var runRecords: [UUID: RunRecord] = [:]
    private var runOrder: [UUID] = []
    private var logEntriesByRunID: [UUID: [ProcessLogEntry]] = [:]
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let maxRuns: Int
    private let maxEntriesPerRun: Int

    nonisolated init(
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        maxRuns: Int = ProcessLogStore.defaultMaxRuns,
        maxEntriesPerRun: Int = ProcessLogStore.defaultMaxEntriesPerRun
    ) {
        self.now = now
        self.makeID = makeID
        self.maxRuns = max(1, maxRuns)
        self.maxEntriesPerRun = max(1, maxEntriesPerRun)
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
        evictOldRunsIfNeeded()

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

        // logEntriesByRunID is not @Published (to avoid churn), so notify observers
        // manually — otherwise the Logs detail view never refreshes while a run's
        // output streams in and only updates when the run finishes.
        objectWillChange.send()
        logEntriesByRunID[runID, default: []].append(entry)
        if logEntriesByRunID[runID, default: []].count > maxEntriesPerRun {
            let overflow = logEntriesByRunID[runID, default: []].count - maxEntriesPerRun
            logEntriesByRunID[runID]?.removeFirst(overflow)
        }
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

    private func evictOldRunsIfNeeded() {
        while runOrder.count > maxRuns {
            let evicted = runOrder.removeFirst()
            runRecords.removeValue(forKey: evicted)
            logEntriesByRunID.removeValue(forKey: evicted)
        }
    }
}
