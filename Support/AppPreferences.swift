import Foundation

protocol AppPreferencesStoring: AnyObject {
    var preferredCLIPath: URL? { get set }
    var configFilePath: URL? { get set }
    func resetForFirstRunSimulation()
}

final class AppPreferences: ObservableObject, AppPreferencesStoring {
    private enum Key {
        static let preferredCLIPath = "preferredCLIPath"
        static let configFilePath = "configFilePath"
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

    func resetForFirstRunSimulation() {
        let missingConfigURL = defaultsDirectory()
            .appendingPathComponent("YAMG")
            .appendingPathComponent("Development")
            .appendingPathComponent("missing-first-run.mackup.cfg")

        preferredCLIPath = nil
        configFilePath = missingConfigURL
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

    private func defaultsDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
