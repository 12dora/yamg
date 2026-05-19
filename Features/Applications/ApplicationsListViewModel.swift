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

    private let installedScanner: InstalledApplicationScanning
    private let catalog: MackupSupportedApplicationCataloging
    private let configEditor: MackupConfigEditing
    private let configFilePath: URL?
    private var loadedConfig: MackupConfig?

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

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: updatedSync,
            applicationsToIgnore: baseConfig.applicationsToIgnore,
            originalText: baseConfig.originalText
        )

        do {
            try configEditor.save(updatedConfig)
            loadedConfig = updatedConfig

            apps[index].isSynced = isOn
            let newSyncAll = updatedSync.isEmpty
            if newSyncAll {
                for i in apps.indices { apps[i].isSynced = true }
            }
            isSyncAllMode = newSyncAll
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

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: [],
            applicationsToIgnore: baseConfig.applicationsToIgnore,
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

        let updatedConfig = MackupConfig(
            fileURL: baseConfig.fileURL,
            storage: baseConfig.storage,
            applicationsToSync: [],
            applicationsToIgnore: baseConfig.applicationsToIgnore,
            originalText: baseConfig.originalText
        )

        guard (try? configEditor.save(updatedConfig)) != nil else { return }
        loadedConfig = updatedConfig

        for i in apps.indices { apps[i].isSynced = true }
        isSyncAllMode = true
        state = .loaded(apps)
    }
}
