import SwiftUI

struct OperationFlowView: View {
    @StateObject private var viewModel: OperationFlowViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(
            wrappedValue: OperationFlowViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configFilePath: preferences.configFilePath
            )
        )
    }

    init(viewModel: OperationFlowViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("operations.dry_run", isOn: $viewModel.dryRun)
                Toggle("operations.verbose", isOn: $viewModel.verbose)
            }

            HStack {
                Button {
                    viewModel.request(.backup)
                } label: {
                    Label("operations.backup", systemImage: "arrow.up.doc")
                }
                .disabled(isRunning)

                Button {
                    viewModel.request(.restore)
                } label: {
                    Label("operations.restore", systemImage: "arrow.down.doc")
                }
                .disabled(isRunning)
            }

            confirmationView

            if !viewModel.output.isEmpty {
                ScrollView {
                    Text(viewModel.output)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 720, minHeight: 120, maxHeight: 220)
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    @ViewBuilder
    private var confirmationView: some View {
        switch viewModel.state {
        case .idle:
            Text("operations.idle")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .confirming(let operation):
            VStack(alignment: .leading, spacing: 10) {
                Label(confirmationText(for: operation), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)

                HStack {
                    Button(role: .cancel) {
                        viewModel.cancelConfirmation()
                    } label: {
                        Text("action.cancel")
                    }

                    Button {
                        Task {
                            await viewModel.confirm()
                        }
                    } label: {
                        Text("action.confirm")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        case .running(let operation):
            Label(runningText(for: operation), systemImage: "clock")
                .foregroundStyle(.secondary)
        case .finished(let operation, let result):
            Label(finishedText(for: operation, result: result), systemImage: result.exitCode == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(result.exitCode == 0 ? .green : .orange)
        case .failed(_, let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    private var isRunning: Bool {
        if case .running = viewModel.state {
            return true
        }
        return false
    }

    private func confirmationText(for operation: OperationFlowViewModel.Operation) -> LocalizedStringKey {
        switch operation {
        case .backup:
            return viewModel.dryRun
                ? "operations.confirm.backup_dry_run"
                : "operations.confirm.backup"
        case .restore:
            return viewModel.dryRun
                ? "operations.confirm.restore_dry_run"
                : "operations.confirm.restore"
        }
    }

    private func runningText(for operation: OperationFlowViewModel.Operation) -> LocalizedStringKey {
        switch operation {
        case .backup:
            return "operations.running.backup"
        case .restore:
            return "operations.running.restore"
        }
    }

    private func finishedText(for operation: OperationFlowViewModel.Operation, result: ProcessResult) -> String {
        let operationName: String.LocalizationValue
        switch operation {
        case .backup:
            operationName = "operations.backup"
        case .restore:
            operationName = "operations.restore"
        }

        if result.exitCode == 0 {
            return "\(String(localized: operationName)) completed successfully."
        }
        return "\(String(localized: operationName)) exited with status \(result.exitCode)."
    }
}
