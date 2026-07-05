import Foundation

@MainActor
final class ApplicationsListViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded([SyncableApplication])
        case empty
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var isSyncAllMode: Bool = true

    /// True when the list is loaded and nothing is synced — used to disable the
    /// "Sync none" button (mirroring how isSyncAllMode disables "Sync all").
    var isSyncNoneMode: Bool {
        guard case .loaded(let apps) = state else { return false }
        return !isSyncAllMode && apps.allSatisfy { !$0.isSynced }
    }

    private let installedScanner: InstalledApplicationScanning
    private let catalog: MackupSupportedApplicationCataloging
    private let configEditor: MackupConfigEditing
    private let configFilePath: URL?
    private var loadedConfig: MackupConfig?
    private var lastSupportedIdentifiers: [String] = []

    init(
        installedScanner: InstalledApplicationScanning = InstalledApplicationScanner(),
        catalog: MackupSupportedApplicationCataloging? = nil,
        configEditor: MackupConfigEditing = MackupConfigEditor(),
        configFilePath: URL? = nil,
        preferredCLIPath: URL? = nil
    ) {
        self.installedScanner = installedScanner
        self.catalog = catalog ?? MackupSupportedApplicationCatalog(preferredCLIPath: preferredCLIPath)
        self.configEditor = configEditor
        self.configFilePath = configFilePath
    }

    func refresh() async {
        state = .loading

        let installed: [MackupApplication]
        do {
            installed = try installedScanner.scanInstalledApplications()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        let supportedIdentifiers: [String]
        do {
            supportedIdentifiers = try await catalog.supportedApplicationIdentifiers()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        let config: MackupConfig
        do {
            config = try configEditor.load(path: configFilePath)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        loadedConfig = config
        lastSupportedIdentifiers = supportedIdentifiers

        let matches = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: supportedIdentifiers,
            installed: installed
        )

        guard !matches.isEmpty else {
            state = .empty
            return
        }

        let isSyncAll = config.applicationsToSync.isEmpty
        let syncedSet = Set(config.applicationsToSync)
        let syncables = matches.map { match in
            SyncableApplication(
                identifier: match.identifier,
                displayName: match.displayName,
                isSynced: isSyncAll || syncedSet.contains(match.identifier)
            )
        }

        isSyncAllMode = isSyncAll
        state = .loaded(syncables)
    }

    @discardableResult
    func setSync(identifier: String, isOn: Bool) -> Bool {
        guard case .loaded(var apps) = state,
              let index = apps.firstIndex(where: { $0.identifier == identifier }) else {
            return false
        }

        let baseConfig: MackupConfig
        if let loadedConfig {
            baseConfig = loadedConfig
        } else {
            do {
                baseConfig = try configEditor.load(path: configFilePath)
            } catch {
                state = .failed(error.localizedDescription)
                return false
            }
        }

        let updatedSync: [String]
        if !isOn && isSyncAllMode {
            // Expand sync-all into an explicit list excluding the app being turned off.
            updatedSync = apps.compactMap { $0.identifier == identifier ? nil : $0.identifier }.sorted()
        } else {
            var list = baseConfig.applicationsToSync.filter { $0 != identifier }
            if isOn { list.append(identifier) }
            updatedSync = list.sorted()
        }

        var updatedIgnore = baseConfig.applicationsToIgnore
        // Re-enabling an app must lift any bulk "ignore everything" a prior
        // deselectAll wrote, otherwise the re-enabled app stays ignored.
        if isOn {
            updatedIgnore.removeAll { $0 == identifier }
        }

        // An empty applications_to_sync means "sync everything" to mackup — the
        // opposite of what turning off the last synced app intends. Translate it
        // the same way deselectAll() does: keep the sync list empty but move every
        // supported app into applications_to_ignore so mackup syncs nothing.
        let syncNothing = updatedSync.isEmpty
        if syncNothing {
            updatedIgnore = Array(Set(updatedIgnore).union(lastSupportedIdentifiers)).sorted()
        }

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: updatedSync,
            applicationsToIgnore: updatedIgnore,
            originalText: baseConfig.originalText
        )

        do {
            try configEditor.save(updatedConfig)
            loadedConfig = updatedConfig

            apps[index].isSynced = isOn
            if syncNothing {
                for i in apps.indices { apps[i].isSynced = false }
            }
            // setSync always yields an explicit list (or an explicit "sync nothing"),
            // never mackup's implicit sync-all.
            isSyncAllMode = false
            state = .loaded(apps)
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    func deselectAll() {
        guard case .loaded(var apps) = state else { return }

        let baseConfig: MackupConfig
        if let loadedConfig {
            baseConfig = loadedConfig
        } else {
            guard let loaded = try? configEditor.load(path: configFilePath) else { return }
            baseConfig = loaded
        }

        // mackup's empty applications_to_sync means "sync all". To make the UI's
        // "deselect all" actually result in zero apps being synced, place every
        // supported app in applications_to_ignore.
        let mergedIgnore = Array(Set(baseConfig.applicationsToIgnore).union(lastSupportedIdentifiers)).sorted()

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: [],
            applicationsToIgnore: mergedIgnore,
            originalText: baseConfig.originalText
        )

        guard (try? configEditor.save(updatedConfig)) != nil else { return }
        loadedConfig = updatedConfig

        for i in apps.indices { apps[i].isSynced = false }
        isSyncAllMode = false
        state = .loaded(apps)
    }

    func selectAll() {
        guard case .loaded(var apps) = state else { return }

        let baseConfig: MackupConfig
        if let loadedConfig {
            baseConfig = loadedConfig
        } else {
            guard let loaded = try? configEditor.load(path: configFilePath) else { return }
            baseConfig = loaded
        }

        // Reverse the deselectAll() bulk-ignore: remove every supported identifier
        // from the ignore list so mackup actually syncs everything.
        let supportedSet = Set(lastSupportedIdentifiers)
        let prunedIgnore = baseConfig.applicationsToIgnore.filter { !supportedSet.contains($0) }

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: [],
            applicationsToIgnore: prunedIgnore,
            originalText: baseConfig.originalText
        )

        guard (try? configEditor.save(updatedConfig)) != nil else { return }
        loadedConfig = updatedConfig

        for i in apps.indices { apps[i].isSynced = true }
        isSyncAllMode = true
        state = .loaded(apps)
    }
}
