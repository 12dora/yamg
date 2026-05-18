import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case storage
    case logs
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .applications:
            return "Applications"
        case .storage:
            return "Storage"
        case .logs:
            return "Logs"
        case .preferences:
            return "Preferences"
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
        case .logs:
            return "doc.text.magnifyingglass"
        case .preferences:
            return "gearshape"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "Status, recent runs, and quick actions."
        case .applications:
            return "Supported apps from Mackup list and show."
        case .storage:
            return "Storage engine and directory settings."
        case .logs:
            return "Streamed stdout and stderr history."
        case .preferences:
            return "CLI path, config path, and UI preferences."
        }
    }
}
