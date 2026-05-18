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
        VStack(alignment: .leading, spacing: 18) {
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
                Button {
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

            if viewModel.state == .saved {
                Label(String(localized: "preferences.saved"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            Spacer()
        }
    }
}
