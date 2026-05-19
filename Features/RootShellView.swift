import SwiftUI

struct RootShellView: View {
    @ObservedObject private var preferences: AppPreferences
    @State private var selection: AppSection? = .dashboard
    private let logStore: ProcessLogStore

    init(preferences: AppPreferences, logStore: ProcessLogStore) {
        self.preferences = preferences
        self.logStore = logStore
    }

    var body: some View {
        NavigationView {
            List(selection: $selection) {
                ForEach(visibleSections) { section in
                    sidebarRow(for: section)
                        .tag(section)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .accessibilityIdentifier("sidebar-\(section.rawValue)")
                }
            }
            .navigationTitle(LocalizationKey.appTitle.localizedStringKey)
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150, idealWidth: 170, maxWidth: 210)

            detailView
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    selection = .dashboard
                } label: {
                    Label(AppSection.dashboard.titleKey.localizedStringKey, systemImage: AppSection.dashboard.systemImageName)
                }
                .help(AppSection.dashboard.titleKey.localizedStringKey)

                Button {
                    selection = .applications
                } label: {
                    Label(AppSection.applications.titleKey.localizedStringKey, systemImage: AppSection.applications.systemImageName)
                }
                .help(AppSection.applications.titleKey.localizedStringKey)
            }
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 420, idealHeight: 460)
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
                .frame(width: 16)
            Text(section.titleKey.localizedStringKey)
                .lineLimit(1)
        }
            .font(.callout)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var detailView: some View {
        let section = selection ?? .dashboard

        if section == .dashboard {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(section)
                DashboardView(preferences: preferences, logStore: logStore)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .applications {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(section)
                ApplicationsListView(preferences: preferences)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .linkMode {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(section)
                LinkModeView(preferences: preferences)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .preferences {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(section)
                PreferencesView(preferences: preferences)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if section == .logs {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(section)
                LogsView(logStore: logStore)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(section)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: AppSection) -> some View {
        Text(section.titleKey.localizedStringKey)
            .font(.title3.weight(.semibold))
            .accessibilityIdentifier("section-title-\(section.rawValue)")

        Text(section.subtitleKey.localizedStringKey)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}

struct RootShellView_Previews: PreviewProvider {
    static var previews: some View {
        RootShellView(preferences: AppPreferences(), logStore: ProcessLogStore())
    }
}
