import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                preferredCLIPath: preferences.preferredCLIPath,
                configPath: preferences.configFilePath
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
            )
        )
    }

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            VStack(alignment: .leading, spacing: 16) {
                statusRow(
                    title: LocalizationKey.onboardingCLIStatus.localizedStringKey,
                    systemImage: cliIconName,
                    stateText: cliStatusText,
                    detailText: cliDetailText
                )

                Divider()

                statusRow(
                    title: LocalizationKey.onboardingConfigStatus.localizedStringKey,
                    systemImage: configIconName,
                    stateText: configStatusText,
                    detailText: configDetailText
                )
            }
            .frame(maxWidth: 720, alignment: .leading)

            Divider()
                .frame(maxWidth: 720)

            if viewModel.shouldShowInstallGuide {
                installGuide

                Divider()
                    .frame(maxWidth: 720)
            }

            OperationFlowView(
                viewModel: OperationFlowViewModel(
                    preferredCLIPath: viewModel.preferredCLIPath,
                    configFilePath: viewModel.configPath
                )
            )

            Spacer()
        }
        .task {
            if viewModel.cliState == .unknown {
                await viewModel.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationKey.onboardingTitle.localizedStringKey)
                    .font(.title2.weight(.semibold))
                Text(LocalizationKey.onboardingSubtitle.localizedStringKey)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Label(LocalizationKey.refresh.localizedStringKey, systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.cliState == .checking)
        }
    }

    private var installGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "install.title"))
                .font(.headline)
            Text(String(localized: "install.detail"))
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(viewModel.installGuide.options) { option in
                HStack(spacing: 10) {
                    Text(option.title)
                        .font(.callout.weight(.medium))
                        .frame(width: 88, alignment: .leading)

                    Text(option.command)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(option.command, forType: .string)
                    } label: {
                        Label(String(localized: "action.copy"), systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func statusRow(
        title: LocalizedStringKey,
        systemImage: String,
        stateText: String,
        detailText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(stateText)
                    .font(.body.weight(.medium))
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var cliIconName: String {
        switch viewModel.cliState {
        case .available:
            return "checkmark.circle"
        case .checking:
            return "clock"
        case .unknown:
            return "questionmark.circle"
        case .unavailable, .invalidVersion, .failed:
            return "exclamationmark.triangle"
        }
    }

    private var cliStatusText: String {
        switch viewModel.cliState {
        case .unknown:
            return String(localized: "status.not_checked")
        case .checking:
            return String(localized: "status.checking")
        case .available(_, let version):
            return String(localized: "onboarding.cli.available \(version.description)")
        case .unavailable:
            return String(localized: "onboarding.cli.unavailable")
        case .invalidVersion:
            return String(localized: "onboarding.cli.invalid_version")
        case .failed:
            return String(localized: "onboarding.cli.failed")
        }
    }

    private var cliDetailText: String {
        switch viewModel.cliState {
        case .available(let path, _):
            return path.path
        case .invalidVersion(let path, let output):
            return "\(path.path): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .failed(let path, let message):
            if let path {
                return "\(path.path): \(message)"
            }
            return message
        case .unavailable:
            return String(localized: "onboarding.cli.unavailable.detail")
        case .checking, .unknown:
            return String(localized: "onboarding.cli.pending.detail")
        }
    }

    private var configIconName: String {
        switch viewModel.configState {
        case .present:
            return "doc.text"
        case .missing:
            return "doc.badge.plus"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var configStatusText: String {
        switch viewModel.configState {
        case .unknown:
            return String(localized: "status.not_checked")
        case .present:
            return String(localized: "onboarding.config.present")
        case .missing:
            return String(localized: "onboarding.config.missing")
        }
    }

    private var configDetailText: String {
        switch viewModel.configState {
        case .present(let path), .missing(let path):
            return path.path
        case .unknown:
            return String(localized: "onboarding.config.pending.detail")
        }
    }
}
