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
    }

    func save() {
        preferences.preferredCLIPath = normalizedURL(from: cliPath)
        preferences.configFilePath = normalizedURL(from: configPath)
        state = .saved
    }

    func reset() {
        do {
            let targetConfigPath = normalizedURL(from: configPath)
                ?? preferences.configFilePath
                ?? defaultConfigPath

            if fileManager.fileExists(atPath: targetConfigPath.path) {
                try fileManager.removeItem(at: targetConfigPath)
            }

            preferences.preferredCLIPath = nil
            preferences.configFilePath = nil
            cliPath = ""
            configPath = ""
            state = .reset
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func resetForFirstRunSimulation() {
        preferences.resetForFirstRunSimulation()
        cliPath = preferences.preferredCLIPath?.path ?? ""
        configPath = preferences.configFilePath?.path ?? ""
        state = .developmentReset
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
    }
}
