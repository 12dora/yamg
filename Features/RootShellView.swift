import SwiftUI

struct RootShellView: View {
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImageName)
                    .tag(section as AppSection?)
            }
            .navigationTitle("YAMG")
            .listStyle(SidebarListStyle())

            detailView
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    @ViewBuilder
    private var detailView: some View {
        let section = selection ?? .dashboard

        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(.largeTitle.weight(.semibold))

            Text(section.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct RootShellView_Previews: PreviewProvider {
    static var previews: some View {
        RootShellView()
    }
}
