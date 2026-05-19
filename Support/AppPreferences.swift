import Foundation

protocol AppPreferencesStoring: AnyObject {
    var preferredCLIPath: URL? { get set }
    var configFilePath: URL? { get set }
    var showsLinkMode: Bool { get set }
}

final class AppPreferences: ObservableObject, AppPreferencesStoring {
    private enum Key {
        static let preferredCLIPath = "preferredCLIPath"
        static let configFilePath = "configFilePath"
        static let showsLinkMode = "showsLinkMode"
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
