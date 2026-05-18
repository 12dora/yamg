import XCTest
@testable import YAMG

@MainActor
final class StorageViewModelTests: XCTestCase {
    func testLoadPublishesStorageFields() {
        let configURL = URL(fileURLWithPath: "/tmp/.mackup.cfg")
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: configURL,
                storage: MackupStorage(engine: .fileSystem, path: "/Sync", directory: "Mackup"),
                applicationsToSync: ["git"],
                applicationsToIgnore: ["xcode"],
                originalText: ""
            )
        )
        let viewModel = StorageViewModel(
            editor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: "/Dropbox", isAvailable: true, detail: "/Dropbox"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: "/Users/test/iCloud", isAvailable: true, detail: "/Users/test/iCloud"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )

        viewModel.load()

        XCTAssertEqual(viewModel.state, StorageViewModel.State.editing)
        XCTAssertEqual(viewModel.configPath, configURL)
        XCTAssertEqual(viewModel.engine, MackupStorageEngine.fileSystem)
        XCTAssertEqual(viewModel.storageFolderPath, "/Sync/Mackup")
        XCTAssertEqual(editor.loadedPath, nil)
    }

    func testLoadUsesPreferredConfigPath() {
        let preferredConfigPath = URL(fileURLWithPath: "/tmp/custom/.mackup.cfg")
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: preferredConfigPath,
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = StorageViewModel(editor: editor, configFilePath: preferredConfigPath)

        viewModel.load()

        XCTAssertEqual(editor.loadedPath, preferredConfigPath)
    }

    func testSaveWritesOnlyStorageFieldsOnLoadedConfig() throws {
        let configURL = URL(fileURLWithPath: "/tmp/.mackup.cfg")
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: configURL,
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: ["git"],
                applicationsToIgnore: ["xcode"],
                originalText: "[storage]\nengine = dropbox\n"
            )
        )
        let viewModel = StorageViewModel(
            editor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: "/Users/test/Dropbox", isAvailable: true, detail: "/Users/test/Dropbox"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: "/Users/test/iCloud", isAvailable: true, detail: "/Users/test/iCloud"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )
        viewModel.load()
        viewModel.selectEngine(MackupStorageEngine.iCloud)
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/iCloud/Dotfiles"))

        viewModel.save()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(viewModel.state, StorageViewModel.State.saved)
        XCTAssertEqual(saved.storage, MackupStorage(engine: .iCloud, path: nil, directory: "Dotfiles"))
        XCTAssertEqual(saved.applicationsToSync, ["git"])
        XCTAssertEqual(saved.applicationsToIgnore, ["xcode"])
    }

    func testFolderSelectionsUpdateStorageFields() {
        let viewModel = StorageViewModel(editor: FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        ))

        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Backup Root/Mackup"))

        XCTAssertEqual(viewModel.storageFolderPath, "/Users/test/Backup Root/Mackup")
    }

    func testSaveSplitsUnifiedFileSystemFolderIntoMackupPathAndDirectory() throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .fileSystem, path: "/Sync", directory: "Mackup"),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = StorageViewModel(
            editor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )
        viewModel.load()
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Sync/Mackup"))

        viewModel.save()

        XCTAssertEqual(
            try XCTUnwrap(editor.savedConfig).storage,
            MackupStorage(engine: .fileSystem, path: "/Users/test/Sync", directory: "Mackup")
        )
    }

    func testUnavailableAutomaticStorageEngineCannotBeSelected() {
        let viewModel = StorageViewModel(
            editor: FakeMackupConfigEditor(
                config: MackupConfig(
                    fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                    storage: MackupStorage(engine: .fileSystem, path: "/Sync", directory: "Mackup"),
                    applicationsToSync: [],
                    applicationsToIgnore: [],
                    originalText: ""
                )
            ),
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )
        viewModel.load()

        viewModel.selectEngine(MackupStorageEngine.dropbox)

        XCTAssertEqual(viewModel.engine, MackupStorageEngine.fileSystem)
    }

    func testSaveAutomaticProviderWritesRelativeNestedDirectory() throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = StorageViewModel(
            editor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: "/Users/test/Dropbox", isAvailable: true, detail: "/Users/test/Dropbox"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )
        viewModel.load()
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Dropbox/Dotfiles/Mackup"))

        viewModel.save()

        XCTAssertEqual(
            try XCTUnwrap(editor.savedConfig).storage,
            MackupStorage(engine: .dropbox, path: nil, directory: "Dotfiles/Mackup")
        )
    }

    func testAutomaticProviderCannotSaveFolderOutsideDetectedRoot() {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = StorageViewModel(
            editor: editor,
            storageDetector: FakeStorageDetector(
                items: [
                    MackupStorageAvailability(engine: .dropbox, detectedPath: "/Users/test/Dropbox", isAvailable: true, detail: "/Users/test/Dropbox"),
                    MackupStorageAvailability(engine: .googleDrive, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .iCloud, detectedPath: nil, isAvailable: false, detail: "missing"),
                    MackupStorageAvailability(engine: .fileSystem, detectedPath: nil, isAvailable: true, detail: "Choose")
                ]
            )
        )
        viewModel.load()
        viewModel.selectStorageFolder(URL(fileURLWithPath: "/Users/test/Documents/Mackup"))

        XCTAssertFalse(viewModel.canSave)
    }

    func testStorageEngineDisplayNamesAreUserFacing() {
        XCTAssertEqual(MackupStorageEngine.dropbox.displayName, "Dropbox")
        XCTAssertEqual(MackupStorageEngine.googleDrive.displayName, "Google Drive")
        XCTAssertEqual(MackupStorageEngine.iCloud.displayName, "iCloud")
        XCTAssertEqual(MackupStorageEngine.fileSystem.displayName, "File System")
    }

    func testLoadFailurePublishesFailedState() {
        let viewModel = StorageViewModel(editor: FakeMackupConfigEditor(error: MackupConfigError.unsupportedStorageEngine("bad")))

        viewModel.load()

        if case .failed = viewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failed state")
        }
    }
}

private final class FakeMackupConfigEditor: MackupConfigEditing {
    private let config: MackupConfig?
    private let error: Error?
    private(set) var savedConfig: MackupConfig?
    private(set) var loadedPath: URL?

    init(config: MackupConfig) {
        self.config = config
        self.error = nil
    }

    init(error: Error) {
        self.config = nil
        self.error = error
    }

    func load(path: URL?) throws -> MackupConfig {
        loadedPath = path
        if let error {
            throw error
        }
        return config!
    }

    func save(_ config: MackupConfig) throws {
        savedConfig = config
    }
}

private struct FakeStorageDetector: MackupStorageDetecting {
    let items: [MackupStorageAvailability]

    func availability() -> [MackupStorageAvailability] {
        items
    }
}
