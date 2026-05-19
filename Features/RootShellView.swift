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
                ForEach(visibleSections) { section in
                    Button {
                        selection = section
                    } label: {
                        sidebarRow(for: section)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                    .listRowBackground((selection ?? .dashboard) == section ? Color.accentColor.opacity(0.16) : Color.clear)
                    .accessibilityIdentifier("sidebar-\(section.rawValue)")
                }
            }
            .navigationTitle(LocalizationKey.appTitle.localizedStringKey)
            .listStyle(SidebarListStyle())

            detailView
        }
        .frame(minWidth: 960, minHeight: 640)
        .onChange(of: preferences.showsLinkMode) { showsLinkMode in
            if !showsLinkMode, selection == .linkMode {
                selection = .dashboard
            }
        }
    }

    private var visibleSections: [AppSection] {
        AppSection.visibleSections(showsLinkMode: preferences.showsLinkMode)
    }

    private func sidebarRow(for section: AppSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImageName)
                .frame(width: 18)
            Text(section.titleKey.localizedStringKey)
            Spacer(minLength: 0)
        }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var detailView: some View {
        let section = selection ?? .dashboard

        if section == .dashboard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(section)
                DashboardView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .applications {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(section)
                ApplicationsListView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .linkMode {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(section)
                LinkModeView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .preferences {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(section)
                PreferencesView(preferences: preferences)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .logs {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(section)
                LogsView()
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
            .font(.title.weight(.semibold))
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
