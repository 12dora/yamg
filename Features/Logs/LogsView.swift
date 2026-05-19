import SwiftUI

struct LogsView: View {
    private let store: ProcessLogPersisting

    init(logStore: ProcessLogPersisting) {
        self.store = logStore
    }

    var body: some View {
        Group {
            if let store = store as? ProcessLogStore {
                LogsContentView(store: store)
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("logs.unavailable", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            Text("logs.unavailable.detail")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct LogsContentView: View {
    @ObservedObject var store: ProcessLogStore
    @State private var selectedRunID: UUID?

    var body: some View {
        let runs = store.runs().reversed()

        Group {
            if runs.isEmpty {
                emptyRunsView
            } else {
                List(selection: $selectedRunID) {
                    ForEach(Array(runs)) { run in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(run.command.description)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(run.startedAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tag(run.id)
                    }
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedRunID == nil {
                selectedRunID = runs.first?.id
            }
        }
    }

    private var emptyRunsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("logs.empty", systemImage: "tray")
                .font(.headline)
            Text("logs.empty.detail")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var logDetail: some View {
        if let selectedRunID, let run = store.run(id: selectedRunID) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(run.command.description)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    statusLabel(for: run)
                }

                ScrollView {
                    Text(logText(for: selectedRunID))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusLabel(for run: RunRecord) -> some View {
        switch run.status {
        case .running:
            Label("status.running", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .finished(let result):
            Label("status.finished \(result.exitCode)", systemImage: result.exitCode == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(result.exitCode == 0 ? .green : .orange)
        case .failed:
            Label("status.failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    private func logText(for runID: UUID) -> String {
        let entries = store.entries(for: runID)

        guard !entries.isEmpty else {
            return String(localized: "logs.no_output")
        }

        return entries.map { entry in
            switch entry.event {
            case .output(let text, let stream):
                return "[\(label(for: stream))] \(text)"
            case .finished(let result):
                return "[exit] \(result.exitCode)"
            }
        }
        .joined(separator: "\n")
    }

    private func label(for stream: ProcessOutputStream) -> String {
        switch stream {
        case .stdout:
            return "stdout"
        case .stderr:
            return "stderr"
        }
    }
}
