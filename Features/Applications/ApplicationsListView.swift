import SwiftUI

struct ApplicationsListView: View {
    @StateObject private var viewModel: ApplicationsListViewModel

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: ApplicationsListViewModel())
    }

    init(viewModel: ApplicationsListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            content
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.refresh()
            }
        }
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
            List(applications) { application in
                Text(application.name)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 320)
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
