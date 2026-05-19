import Foundation

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system:
            return String(localized: "language.system")
        case .english:
            return String(localized: "language.english")
        case .simplifiedChinese:
            return String(localized: "language.simplified_chinese")
        }
    }
}

protocol AppPreferencesStoring: AnyObject {
    var preferredCLIPath: URL? { get set }
    var configFilePath: URL? { get set }
    var showsLinkMode: Bool { get set }
    var preferredLanguage: AppLanguage { get set }
}

final class AppPreferences: ObservableObject, AppPreferencesStoring {
    private enum Key {
        static let preferredCLIPath = "preferredCLIPath"
        static let configFilePath = "configFilePath"
        static let showsLinkMode = "showsLinkMode"
        static let preferredLanguage = "preferredLanguage"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferredCLIPath: URL? {
        get {
            url(forKey: Key.preferredCLIPath)
        }
        set {
            set(newValue, forKey: Key.preferredCLIPath)
        }
    }

    var configFilePath: URL? {
        get {
            url(forKey: Key.configFilePath)
        }
        set {
            set(newValue, forKey: Key.configFilePath)
        }
    }

    var showsLinkMode: Bool {
        get {
            defaults.bool(forKey: Key.showsLinkMode)
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Key.showsLinkMode)
        }
    }

    var preferredLanguage: AppLanguage {
        get {
            let rawValue = defaults.string(forKey: Key.preferredLanguage) ?? AppLanguage.system.rawValue
            return AppLanguage(rawValue: rawValue) ?? .system
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: Key.preferredLanguage)
        }
    }

    private func url(forKey key: String) -> URL? {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    private func set(_ url: URL?, forKey key: String) {
        objectWillChange.send()

        if let url {
            defaults.set(url.path, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
