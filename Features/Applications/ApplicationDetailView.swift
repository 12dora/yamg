import SwiftUI

struct ApplicationDetailView: View {
    let selectedApplicationName: String?
    @StateObject private var viewModel: ApplicationDetailViewModel

    @MainActor
    init(selectedApplicationName: String?, preferredCLIPath: URL? = nil) {
        self.selectedApplicationName = selectedApplicationName
        _viewModel = StateObject(
            wrappedValue: ApplicationDetailViewModel(preferredCLIPath: preferredCLIPath)
        )
    }

    init(selectedApplicationName: String?, viewModel: ApplicationDetailViewModel) {
        self.selectedApplicationName = selectedApplicationName
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if let selectedApplicationName {
                detailContent
                    .task(id: selectedApplicationName) {
                        await viewModel.load(applicationName: selectedApplicationName)
                    }
            } else {
                unavailableView(
                    title: "application.detail.placeholder",
                    systemImage: "sidebar.right",
                    detail: "application.detail.placeholder.detail"
                )
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading(let applicationName):
            VStack(alignment: .leading, spacing: 12) {
                Text(applicationName)
                    .font(.title3.weight(.semibold))
                ProgressView()
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .loaded(let detail):
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.displayName)
                        .font(.title3.weight(.semibold))
                    Text(detail.applicationName)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Divider()

                Text("application.detail.configuration_files")
                    .font(.headline)

                if detail.configurationFiles.isEmpty {
                    Text("application.detail.no_files")
                        .foregroundStyle(.secondary)
                } else {
                    List(detail.configurationFiles, id: \.self) { file in
                        Text(file)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220)
                }
            }
            .frame(maxWidth: 320, maxHeight: .infinity, alignment: .topLeading)
        case .failed(let applicationName, let message):
            unavailableView(
                title: LocalizedStringKey(applicationName),
                systemImage: "exclamationmark.triangle",
                detail: LocalizedStringKey(message)
            )
        }
    }

    private func unavailableView(title: LocalizedStringKey, systemImage: String, detail: LocalizedStringKey) -> some View {
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
        .frame(maxWidth: 320, minHeight: 180, alignment: .top)
    }
}
