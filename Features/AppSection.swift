import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case storage
    case linkMode
    case logs
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "section.dashboard.title"
        case .applications:
            return "section.applications.title"
        case .storage:
            return "section.storage.title"
        case .linkMode:
            return "section.link_mode.title"
        case .logs:
            return "section.logs.title"
        case .preferences:
            return "section.preferences.title"
        }
    }

    var titleKey: LocalizationKey {
        switch self {
        case .dashboard:
            return .dashboardTitle
        case .applications:
            return .applicationsTitle
        case .storage:
            return .storageTitle
        case .linkMode:
            return .linkModeTitle
        case .logs:
            return .logsTitle
        case .preferences:
            return .preferencesTitle
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            return "rectangle.grid.2x2"
        case .applications:
            return "tray.full"
        case .storage:
            return "externaldrive"
        case .linkMode:
            return "link.badge.plus"
        case .logs:
            return "doc.text.magnifyingglass"
        case .preferences:
            return "gearshape"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "section.dashboard.subtitle"
        case .applications:
            return "section.applications.subtitle"
        case .storage:
            return "section.storage.subtitle"
        case .linkMode:
            return "section.link_mode.subtitle"
        case .logs:
            return "section.logs.subtitle"
        case .preferences:
            return "section.preferences.subtitle"
        }
    }

    var subtitleKey: LocalizationKey {
        switch self {
        case .dashboard:
            return .dashboardSubtitle
        case .applications:
            return .applicationsSubtitle
        case .storage:
            return .storageSubtitle
        case .linkMode:
            return .linkModeSubtitle
        case .logs:
            return .logsSubtitle
        case .preferences:
            return .preferencesSubtitle
        }
    }
}
