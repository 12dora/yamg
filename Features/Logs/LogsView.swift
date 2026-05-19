import SwiftUI
import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published private(set) var runs: [RunRecord] = []

    private let logStore: ProcessLogPersisting
    private var updateTask: Task<Void, Never>?

    init(logStore: ProcessLogPersisting = ProcessLogStore()) {
        self.logStore = logStore
        startPolling()
    }

    deinit {
        updateTask?.cancel()
    }

    private func startPolling() {
        updateTask = Task {
            while !Task.isCancelled {
                await updateRuns()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func updateRuns() async {
        if let store = logStore as? ProcessLogStore {
            runs = store.runs()
        }
    }
}

struct LogsView: View {
    @StateObject private var viewModel: LogsViewModel

    init(logStore: ProcessLogPersisting = ProcessLogStore()) {
        _viewModel = StateObject(wrappedValue: LogsViewModel(logStore: logStore))
    }

    var body: some View {
        if viewModel.runs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(String(localized: "logs.empty"))
                    .font(.headline)
                Text(String(localized: "logs.empty.detail"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.runs.reversed()) { run in
                        runCard(run)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    @ViewBuilder
    private func runCard(_ run: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon(run.status))
                    .foregroundStyle(statusColor(run.status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(run.command.description)
                        .font(.headline)
                    Text(run.startedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(statusText(run.status))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor(run.status))
            }

            if let finishedAt = run.finishedAt {
                Text("Duration: \(formatDuration(from: run.startedAt, to: finishedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func statusIcon(_ status: RunRecord.Status) -> String {
        switch status {
        case .running:
            return "clock"
        case .finished(let result):
            return result.exitCode == 0 ? "checkmark.circle" : "exclamationmark.triangle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private func statusColor(_ status: RunRecord.Status) -> Color {
        switch status {
        case .running:
            return .secondary
        case .finished(let result):
            return result.exitCode == 0 ? .green : .orange
        case .failed:
            return .red
        }
    }

    private func statusText(_ status: RunRecord.Status) -> String {
        switch status {
        case .running:
            return String(localized: "status.running")
        case .finished(let result):
            return result.exitCode == 0 ? String(localized: "status.success") : String(localized: "status.failed")
        case .failed:
            return String(localized: "status.failed")
        }
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let seconds = Int(interval) % 60
        let minutes = (Int(interval) / 60) % 60
        let hours = Int(interval) / 3600

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}


