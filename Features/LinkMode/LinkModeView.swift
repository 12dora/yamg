import SwiftUI

struct LinkModeView: View {
    @StateObject private var viewModel: LinkModeViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(
            wrappedValue: LinkModeViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configFilePath: preferences.configFilePath
            )
        )
    }

    init(viewModel: LinkModeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "link_mode.warning"), systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text(String(localized: "link_mode.detail"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 820, alignment: .leading)

                guide
                commandGuide

                Picker(String(localized: "link_mode.operation"), selection: $viewModel.selectedOperation) {
                    ForEach(LinkModeViewModel.Operation.allCases) { operation in
                        Text(title(for: operation)).tag(operation)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)

                Toggle(String(localized: "operations.verbose"), isOn: $viewModel.verbose)
                Toggle(String(localized: "link_mode.acknowledge"), isOn: $viewModel.acknowledgedRisk)
                    .toggleStyle(.checkbox)

                Button {
                    viewModel.requestSelectedOperation()
                } label: {
                    Label(String(localized: "link_mode.request"), systemImage: "link")
                }
                .disabled(!viewModel.acknowledgedRisk || isRunning)

                confirmationView

                if !viewModel.output.isEmpty {
                    ScrollView {
                        Text(viewModel.output)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: 820, minHeight: 120, maxHeight: 260)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedOperation)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 6) {
            guideRow(
                title: String(localized: "link_mode.guide.install.title"),
                detail: String(localized: "link_mode.guide.install.detail")
            )
            guideRow(
                title: String(localized: "link_mode.guide.link.title"),
                detail: String(localized: "link_mode.guide.link.detail")
            )
            guideRow(
                title: String(localized: "link_mode.guide.uninstall.title"),
                detail: String(localized: "link_mode.guide.uninstall.detail")
            )
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private var commandGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            commandGuideRow(
                command: "mackup link install",
                detail: String(localized: "link_mode.command.install.detail")
            )
            commandGuideRow(
                command: "mackup link",
                detail: String(localized: "link_mode.command.link.detail")
            )
            commandGuideRow(
                command: "mackup link uninstall",
                detail: String(localized: "link_mode.command.uninstall.detail")
            )
        }
        .font(.callout)
        .frame(maxWidth: 820, alignment: .leading)
    }

    private func guideRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.callout.weight(.semibold))
                .frame(width: 112, alignment: .leading)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func commandGuideRow(command: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(width: 180, alignment: .leading)
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var confirmationView: some View {
        switch viewModel.state {
        case .idle:
            Text(String(localized: "link_mode.idle"))
                .font(.callout)
                .foregroundStyle(.secondary)
        case .confirming(let operation):
            VStack(alignment: .leading, spacing: 10) {
                Label(confirmText(for: operation), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)

                HStack {
                    Button(role: .cancel) {
                        viewModel.cancelConfirmation()
                    } label: {
                        Text(String(localized: "action.cancel"))
                    }

                    Button {
                        Task {
                            await viewModel.confirm()
                        }
                    } label: {
                        Text(String(localized: "action.confirm"))
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

    private func title(for operation: LinkModeViewModel.Operation) -> String {
        switch operation {
        case .install:
            return String(localized: "link_mode.install")
        case .link:
            return String(localized: "link_mode.link")
        case .uninstall:
            return String(localized: "link_mode.uninstall")
        }
    }

    private func confirmText(for operation: LinkModeViewModel.Operation) -> String {
        switch operation {
        case .install:
            return String(localized: "link_mode.confirm.install")
        case .link:
            return String(localized: "link_mode.confirm.link")
        case .uninstall:
            return String(localized: "link_mode.confirm.uninstall")
        }
    }

    private func runningText(for operation: LinkModeViewModel.Operation) -> String {
        "\(title(for: operation))..."
    }

    private func finishedText(for operation: LinkModeViewModel.Operation, result: ProcessResult) -> String {
        if result.exitCode == 0 {
            return "\(title(for: operation)) completed successfully."
        }
        return "\(title(for: operation)) exited with status \(result.exitCode)."
    }
}
