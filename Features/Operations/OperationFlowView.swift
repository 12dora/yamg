import SwiftUI

struct OperationFlowView: View {
    struct Layout {
        var panelHeight: CGFloat?
        var controlsWidth: CGFloat = 150
        var actionButtonWidth: CGFloat = 108
        var logMinWidth: CGFloat = 150
        var logMaxWidth: CGFloat = .infinity
        var logHeight: CGFloat?
        var logMaxHeight: CGFloat = .infinity
    }

    @StateObject private var viewModel: OperationFlowViewModel
    private let layout: Layout

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences(), layout: Layout = Layout()) {
        self.layout = layout
        _viewModel = StateObject(
            wrappedValue: OperationFlowViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configFilePath: preferences.configFilePath
            )
        )
    }

    init(viewModel: OperationFlowViewModel, layout: Layout = Layout()) {
        self.layout = layout
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("operations.backup")
                        Text("/")
                        Text("operations.restore")
                    }
                    .font(.headline)

                    Spacer(minLength: 8)

                    operationStatusBadge
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("operations.dry_run", isOn: $viewModel.dryRun)
                        .toggleStyle(.checkbox)
                    Toggle("operations.verbose", isOn: $viewModel.verbose)
                        .toggleStyle(.checkbox)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        viewModel.request(.backup)
                    } label: {
                        Label("operations.backup", systemImage: "arrow.up.doc")
                            .frame(width: layout.actionButtonWidth)
                    }
                    .disabled(isRunning)

                    Button {
                        viewModel.request(.restore)
                    } label: {
                        Label("operations.restore", systemImage: "arrow.down.doc")
                            .frame(width: layout.actionButtonWidth)
                    }
                    .disabled(isRunning)
                }

                Spacer(minLength: 0)
            }
            .frame(width: layout.controlsWidth, alignment: .topLeading)

            ScrollView {
                Text(viewModel.output.isEmpty ? " " : viewModel.output)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: layout.logMinWidth, maxWidth: layout.logMaxWidth, alignment: .topLeading)
            .frame(height: layout.logHeight, alignment: .topLeading)
            .frame(maxHeight: layout.logMaxHeight, alignment: .topLeading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(10)
        .frame(height: layout.panelHeight, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var operationStatusBadge: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .running:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .finished(_, let result):
            Label(
                result.exitCode == 0 ? "operations.status.success" : "operations.status.failure",
                systemImage: result.exitCode == 0 ? "checkmark.circle" : "exclamationmark.triangle"
            )
            .font(.caption)
            .lineLimit(1)
                .foregroundStyle(result.exitCode == 0 ? .green : .orange)
        case .failed:
            Label("operations.status.failure", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.red)
        }
    }

    private var isRunning: Bool {
        if case .running = viewModel.state {
            return true
        }
        return false
    }

}
