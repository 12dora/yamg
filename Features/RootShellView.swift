import SwiftUI

struct RootShellView: View {
    @ObservedObject private var preferences: AppPreferences
    @State private var selection: AppSection? = .dashboard

    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(AppSection.allCases) { section in
                    sidebarRow(for: section)
                    .listRowBackground((selection ?? .dashboard) == section ? Color.accentColor.opacity(0.16) : Color.clear)
                    .accessibilityIdentifier("sidebar-\(section.rawValue)")
                }
            }
            .navigationTitle(LocalizationKey.appTitle.localizedStringKey)
            .listStyle(SidebarListStyle())

            detailView
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private func sidebarRow(for section: AppSection) -> some View {
        Label(section.titleKey.localizedStringKey, systemImage: section.systemImageName)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = section
            }
    }

    @ViewBuilder
    private var detailView: some View {
        let section = selection ?? .dashboard

        if section == .dashboard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                DashboardView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .applications {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                ApplicationsListView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .storage {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                StorageView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .linkMode {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                LinkModeView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .preferences {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                PreferencesView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: AppSection) -> some View {
        Text(section.titleKey.localizedStringKey)
            .font(.largeTitle.weight(.semibold))
            .accessibilityIdentifier("section-title-\(section.rawValue)")

        Text(section.subtitleKey.localizedStringKey)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}

struct RootShellView_Previews: PreviewProvider {
    static var previews: some View {
        RootShellView()
    }
}
