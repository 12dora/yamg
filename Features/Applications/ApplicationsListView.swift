import SwiftUI

struct ApplicationsListView: View {
    @StateObject private var viewModel: ApplicationsListViewModel
    @State private var selectedApplicationName: String?
    private let preferences: AppPreferencesStoring

    @MainActor
    init(preferences: AppPreferencesStoring = AppPreferences()) {
        self.preferences = preferences
        _viewModel = StateObject(
            wrappedValue: ApplicationsListViewModel(preferredCLIPath: preferences.preferredCLIPath)
        )
    }

    init(viewModel: ApplicationsListViewModel) {
        self.preferences = AppPreferences()
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusText)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label(LocalizationKey.refresh.localizedStringKey, systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state == .loading)
            }

            HStack(alignment: .top, spacing: 12) {
                content
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

                Divider()

                ApplicationDetailView(
                    selectedApplicationName: selectedApplicationName,
                    preferredCLIPath: preferences.preferredCLIPath
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.refresh()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            Text(String(localized: "status.not_checked"))
                .foregroundStyle(.secondary)
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .loaded(let applications):
            List(applications, selection: $selectedApplicationName) { application in
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.displayName)
                        .lineLimit(1)

                    if application.displayName != application.name {
                        Text(application.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .tag(application.name)
            }
            .frame(minHeight: 320)
            .onAppear {
                if selectedApplicationName == nil {
                    selectedApplicationName = applications.first?.name
                }
            }
            .onChange(of: applications) { newApplications in
                guard let selectedApplicationName else {
                    self.selectedApplicationName = newApplications.first?.name
                    return
                }

                if !newApplications.contains(where: { $0.name == selectedApplicationName }) {
                    self.selectedApplicationName = newApplications.first?.name
                }
            }
        case .empty:
            unavailableView(
                title: String(localized: "applications.empty"),
                systemImage: "tray",
                detail: String(localized: "applications.empty.detail")
            )
        case .failed(let message):
            unavailableView(
                title: String(localized: "applications.failed"),
                systemImage: "exclamationmark.triangle",
                detail: message
            )
        }
    }

    private func unavailableView(title: String, systemImage: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return String(localized: "status.not_checked")
        case .loading:
            return String(localized: "status.checking")
        case .loaded(let applications):
            return String(localized: "applications.count \(applications.count)")
        case .empty:
            return String(localized: "applications.empty")
        case .failed:
            return String(localized: "applications.failed")
        }
    }
}
