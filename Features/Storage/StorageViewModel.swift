import Foundation

@MainActor
final class StorageViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case editing
        case saving
        case saved
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var engine: MackupStorageEngine = .dropbox
    @Published var storageFolderPath: String = ""
    @Published private(set) var storageAvailability: [MackupStorageAvailability] = []
    @Published private(set) var configPath: URL?

    private let editor: MackupConfigEditing
    private let storageDetector: MackupStorageDetecting
    private let configFilePath: URL?
    private var loadedConfig: MackupConfig?

    var selectedAvailability: MackupStorageAvailability? {
        storageAvailability.first { $0.engine == engine }
    }

    var canSave: Bool {
        guard let selectedAvailability, selectedAvailability.isAvailable else {
            return false
        }

        guard !storageFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if engine == .fileSystem {
            return true
        }

        return automaticStorageDirectory() != nil
    }

    init(
        editor: MackupConfigEditing = MackupConfigEditor(),
        storageDetector: MackupStorageDetecting = MackupStorageDetector(),
        configFilePath: URL? = nil
    ) {
        self.editor = editor
        self.storageDetector = storageDetector
        self.configFilePath = configFilePath
    }

    func load() {
        state = .loading

        do {
            storageAvailability = storageDetector.availability()
            let config = try editor.load(path: configFilePath)
            loadedConfig = config
            configPath = config.fileURL
            engine = config.storage.engine
            storageFolderPath = storageFolderPath(for: config.storage)
            state = .editing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func save() {
        state = .saving

        do {
            var config = try currentConfig()
            config.storage = storageFromSelection()
            try editor.save(config)
            loadedConfig = config
            configPath = config.fileURL
            state = .saved
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func selectStorageFolder(_ url: URL) {
        storageFolderPath = url.standardizedFileURL.path
    }

    func selectEngine(_ engine: MackupStorageEngine) {
        guard engine == .fileSystem || storageAvailability.first(where: { $0.engine == engine })?.isAvailable == true else {
            return
        }

        self.engine = engine

        if engine == .fileSystem {
            return
        }

        if let detectedPath = storageAvailability.first(where: { $0.engine == engine })?.detectedPath {
            storageFolderPath = URL(fileURLWithPath: detectedPath)
                .appendingPathComponent("Mackup", isDirectory: true)
                .standardizedFileURL
                .path
        }
    }

    private func currentConfig() throws -> MackupConfig {
        if let loadedConfig {
            return loadedConfig
        }

        let config = try editor.load(path: configFilePath)
        loadedConfig = config
        return config
    }

    private func storageFolderPath(for storage: MackupStorage) -> String {
        let directory = storage.directory ?? "Mackup"

        if let path = storage.path, !path.isEmpty {
            return URL(fileURLWithPath: path)
                .appendingPathComponent(directory, isDirectory: true)
                .standardizedFileURL
                .path
        }

        if let detectedPath = storageAvailability.first(where: { $0.engine == storage.engine })?.detectedPath {
            return URL(fileURLWithPath: detectedPath)
                .appendingPathComponent(directory, isDirectory: true)
                .standardizedFileURL
                .path
        }

        return ""
    }

    private func storageFromSelection() -> MackupStorage {
        let selectedURL = URL(fileURLWithPath: storageFolderPath)
        let directory = selectedURL.lastPathComponent
        let rootPath = selectedURL.deletingLastPathComponent().path

        switch engine {
        case .dropbox, .googleDrive, .iCloud:
            let directory = automaticStorageDirectory()
            return MackupStorage(
                engine: engine,
                path: nil,
                directory: directory == "Mackup" ? nil : directory
            )
        case .fileSystem:
            return MackupStorage(
                engine: engine,
                path: rootPath,
                directory: directory
            )
        }
    }

    private func automaticStorageDirectory() -> String? {
        guard let detectedPath = selectedAvailability?.detectedPath else {
            return nil
        }

        let selectedPath = URL(fileURLWithPath: storageFolderPath).standardizedFileURL.path
        let rootPath = URL(fileURLWithPath: detectedPath).standardizedFileURL.path
        let relativePath: String

        if selectedPath.hasPrefix(rootPath + "/") {
            relativePath = String(selectedPath.dropFirst(rootPath.count + 1))
        } else {
            return nil
        }

        return relativePath.isEmpty ? nil : relativePath
    }
}
