import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
    enum State: Equatable {
        case editing
        case saved
        case reset
        case developmentReset
        case failed(String)
    }

    @Published var cliPath: String
    @Published var configPath: String
    @Published var showsLinkMode: Bool
    @Published private(set) var state: State = .editing

    private let preferences: AppPreferencesStoring
    private let fileManager: FileManager
    private let defaultConfigPath: URL

    init(
        preferences: AppPreferencesStoring = AppPreferences(),
        fileManager: FileManager = .default,
        defaultConfigPath: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mackup.cfg")
    ) {
        self.preferences = preferences
        self.fileManager = fileManager
        self.defaultConfigPath = defaultConfigPath
        self.cliPath = preferences.preferredCLIPath?.path ?? ""
        self.configPath = preferences.configFilePath?.path ?? ""
        self.showsLinkMode = preferences.showsLinkMode
    }

    func save() {
        preferences.preferredCLIPath = normalizedURL(from: cliPath)
        preferences.configFilePath = normalizedURL(from: configPath)
        preferences.showsLinkMode = showsLinkMode
        state = .saved
    }

    func reset() {
        do {
            let configPathsToDelete = uniqueURLs([
                normalizedURL(from: configPath),
                preferences.configFilePath,
                defaultConfigPath
            ])

            for configPath in configPathsToDelete where fileManager.fileExists(atPath: configPath.path) {
                try fileManager.removeItem(at: configPath)
            }

            preferences.preferredCLIPath = nil
            preferences.configFilePath = nil
            preferences.showsLinkMode = false
            cliPath = ""
            configPath = ""
            showsLinkMode = false
            state = .reset
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetForFirstRunSimulation() {
        preferences.resetForFirstRunSimulation()
        cliPath = preferences.preferredCLIPath?.path ?? ""
        configPath = preferences.configFilePath?.path ?? ""
        showsLinkMode = preferences.showsLinkMode
        state = .developmentReset
    }

    func selectCLIPath(_ url: URL) {
        cliPath = url.path
    }

    func selectConfigPath(_ url: URL) {
        configPath = url.path
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
    }

    private func uniqueURLs(_ urls: [URL?]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for url in urls.compactMap({ $0 }) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else {
                continue
            }

            seen.insert(path)
            result.append(url)
        }

        return result
    }
}
