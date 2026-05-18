import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
    enum State: Equatable {
        case editing
        case saved
        case developmentReset
    }

    @Published var cliPath: String
    @Published var configPath: String
    @Published private(set) var state: State = .editing

    private let preferences: AppPreferencesStoring

    init(preferences: AppPreferencesStoring = AppPreferences()) {
        self.preferences = preferences
        self.cliPath = preferences.preferredCLIPath?.path ?? ""
        self.configPath = preferences.configFilePath?.path ?? ""
    }

    func save() {
        preferences.preferredCLIPath = normalizedURL(from: cliPath)
        preferences.configFilePath = normalizedURL(from: configPath)
        state = .saved
    }

    func reset() {
        cliPath = ""
        configPath = ""
        save()
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
