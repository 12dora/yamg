import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel: PreferencesViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(wrappedValue: PreferencesViewModel(preferences: preferences))
    }

    init(viewModel: PreferencesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                TextField(String(localized: "preferences.cli_path"), text: $viewModel.cliPath)
                    .textFieldStyle(.roundedBorder)
                Text(String(localized: "preferences.cli_path.detail"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField(String(localized: "preferences.config_path"), text: $viewModel.configPath)
                    .textFieldStyle(.roundedBorder)
                Text(String(localized: "preferences.config_path.detail"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 680)

            HStack {
                Button(role: .destructive) {
                    viewModel.reset()
                } label: {
                    Label(String(localized: "action.reset"), systemImage: "arrow.counterclockwise")
                }

                Button {
                    viewModel.save()
                } label: {
                    Label(String(localized: "action.save"), systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()
                .frame(maxWidth: 680)

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "preferences.development.title"))
                    .font(.headline)
                Text(String(localized: "preferences.development.detail"))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    viewModel.resetForFirstRunSimulation()
                } label: {
                    Label(String(localized: "preferences.development.reset_first_run"), systemImage: "arrow.counterclockwise.circle")
                }
            }
            .frame(maxWidth: 680, alignment: .leading)

            if viewModel.state == .saved {
                Label(String(localized: "preferences.saved"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            if viewModel.state == .reset {
                Label(String(localized: "preferences.reset_done"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }

            if viewModel.state == .developmentReset {
                Label(String(localized: "preferences.development.reset_done"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
            }

            if case .failed(let message) = viewModel.state {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }
}
