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

        let syncedSet = Set(config.applicationsToSync)
        let syncables = matches.map { match in
            SyncableApplication(
                identifier: match.identifier,
                displayName: match.displayName,
                isSynced: syncedSet.contains(match.identifier)
            )
        }

        state = .loaded(syncables)
    }

    @discardableResult
    func setSync(identifier: String, isOn: Bool) -> Bool {
        guard case .loaded(var apps) = state,
              let index = apps.firstIndex(where: { $0.identifier == identifier }) else {
            return false
        }

        apps[index].isSynced = isOn

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

        var updatedSync = baseConfig.applicationsToSync.filter { $0 != identifier }
        if isOn {
            updatedSync.append(identifier)
        }
        updatedSync.sort()

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
            state = .loaded(apps)
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
}
