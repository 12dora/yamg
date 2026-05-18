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
        let viewModel = StorageViewModel(editor: editor)

        viewModel.load()

        XCTAssertEqual(viewModel.state, .editing)
        XCTAssertEqual(viewModel.configPath, configURL)
        XCTAssertEqual(viewModel.engine, .fileSystem)
        XCTAssertEqual(viewModel.path, "/Sync")
        XCTAssertEqual(viewModel.directory, "Mackup")
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
        let viewModel = StorageViewModel(editor: editor)
        viewModel.load()
        viewModel.engine = .iCloud
        viewModel.path = "  "
        viewModel.directory = "Dotfiles"

        viewModel.save()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(viewModel.state, .saved)
        XCTAssertEqual(saved.storage, MackupStorage(engine: .iCloud, path: nil, directory: "Dotfiles"))
        XCTAssertEqual(saved.applicationsToSync, ["git"])
        XCTAssertEqual(saved.applicationsToIgnore, ["xcode"])
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

    init(config: MackupConfig) {
        self.config = config
        self.error = nil
    }

    init(error: Error) {
        self.config = nil
        self.error = error
    }

    func load(path: URL?) throws -> MackupConfig {
        if let error {
            throw error
        }
        return config!
    }

    func save(_ config: MackupConfig) throws {
        savedConfig = config
    }
}
