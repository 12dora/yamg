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
    @Published var path: String = ""
    @Published var directory: String = ""
    @Published private(set) var configPath: URL?

    private let editor: MackupConfigEditing
    private let configFilePath: URL?
    private var loadedConfig: MackupConfig?

    init(
        editor: MackupConfigEditing = MackupConfigEditor(),
        configFilePath: URL? = nil
    ) {
        self.editor = editor
        self.configFilePath = configFilePath
    }

    func load() {
        state = .loading

        do {
            let config = try editor.load(path: configFilePath)
            loadedConfig = config
            configPath = config.fileURL
            engine = config.storage.engine
            path = config.storage.path ?? ""
            directory = config.storage.directory ?? ""
            state = .editing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func save() {
        state = .saving

        do {
            var config = try currentConfig()
            config.storage = MackupStorage(
                engine: engine,
                path: normalizedOptional(path),
                directory: normalizedOptional(directory)
            )
            try editor.save(config)
            loadedConfig = config
            configPath = config.fileURL
            state = .saved
        } catch {
            state = .failed(error.localizedDescription)
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

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
