import Foundation

@MainActor
final class PreferencesViewModel: ObservableObject {
    enum State: Equatable {
        case editing
        case saved
        case reset
        case failed(String)
    }

    @Published var cliPath: String { didSet { markEdited() } }
    @Published var configPath: String { didSet { markEdited() } }
    @Published var showsLinkMode: Bool { didSet { markEdited() } }
    @Published var preferredLanguage: AppLanguage
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
        self.preferredLanguage = preferences.preferredLanguage
    }

    /// Reloads the editable fields from the shared store. Called when the pane
    /// appears so a long-lived Settings window can't overwrite newer values that
    /// another Preferences surface saved while it was hidden.
    func reloadFromStore() {
        cliPath = preferences.preferredCLIPath?.path ?? ""
        configPath = preferences.configFilePath?.path ?? ""
        showsLinkMode = preferences.showsLinkMode
        preferredLanguage = preferences.preferredLanguage
        state = .editing
    }

    private func markEdited() {
        // Clear a stale "Saved"/"Reset done" indicator once the user edits again,
        // so it never claims the currently-shown values are persisted when they
        // are not.
        if state != .editing {
            state = .editing
        }
    }

    func save() {
        let cliURL = normalizedURL(from: cliPath)

        if let cliURL, !isExecutable(cliURL) {
            // Carry the localization key (not an English literal) so the message
            // follows the in-app language when rendered via LocalizedStringKey.
            state = .failed("preferences.cli_path.invalid")
            return
        }

        preferences.preferredCLIPath = cliURL
        preferences.configFilePath = normalizedURL(from: configPath)
        preferences.showsLinkMode = showsLinkMode
        preferences.preferredLanguage = preferredLanguage
        state = .saved
    }

    func applyPreferredLanguage() {
        preferences.preferredLanguage = preferredLanguage
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

    private func isExecutable(_ url: URL) -> Bool {
        fileManager.isExecutableFile(atPath: url.path)
    }
}
