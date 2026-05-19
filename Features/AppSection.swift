import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case linkMode
    case logs
    case preferences

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .dashboard:
            return .dashboardTitle
        case .applications:
            return .applicationsTitle
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
        case .linkMode:
            return "link.badge.plus"
        case .logs:
            return "doc.text.magnifyingglass"
        case .preferences:
            return "gearshape"
        }
    }

    var subtitleKey: LocalizationKey {
        switch self {
        case .dashboard:
            return .dashboardSubtitle
        case .applications:
            return .applicationsSubtitle
        case .linkMode:
            return .linkModeSubtitle
        case .logs:
            return .logsSubtitle
        case .preferences:
            return .preferencesSubtitle
        }
    }

    static func visibleSections(showsLinkMode: Bool) -> [AppSection] {
        allCases.filter { section in
            section != .linkMode || showsLinkMode
        }
    }
}
