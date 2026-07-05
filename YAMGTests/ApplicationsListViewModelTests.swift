import XCTest
@testable import YAMG

@MainActor
final class ApplicationsListViewModelTests: XCTestCase {
    func testRefreshLoadsIntersectionWithSyncFlagsFromConfig() async {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: ["git"],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(
                applications: [
                    MackupApplication(name: "git", displayName: "Git"),
                    MackupApplication(name: "raycast", displayName: "Raycast")
                ]
            ),
            catalog: FakeCatalog(identifiers: ["git", "raycast", "iterm2"]),
            configEditor: editor
        )

        await viewModel.refresh()

        XCTAssertEqual(
            viewModel.state,
            .loaded([
                SyncableApplication(identifier: "git", displayName: "Git", isSynced: true),
                SyncableApplication(identifier: "raycast", displayName: "Raycast", isSynced: false)
            ])
        )
    }

    func testRefreshReportsEmptyWhenNoIntersection() async {
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "novel", displayName: "Novel")
            ]),
            catalog: FakeCatalog(identifiers: ["git"]),
            configEditor: FakeMackupConfigEditor(
                config: MackupConfig(
                    fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                    storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                    applicationsToSync: [],
                    applicationsToIgnore: [],
                    originalText: ""
                )
            )
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .empty)
    }

    func testRefreshReportsFailureWhenCatalogThrows() async {
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git")
            ]),
            catalog: FakeCatalog(error: MackupSupportedApplicationCatalogError.mackupUnavailable("missing")),
            configEditor: FakeMackupConfigEditor(
                config: MackupConfig(
                    fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                    storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                    applicationsToSync: [],
                    applicationsToIgnore: [],
                    originalText: ""
                )
            )
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .failed("missing"))
    }

    func testEmptyApplicationsToSyncShowsAllAsSynced() async {
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: FakeMackupConfigEditor(
                config: MackupConfig(
                    fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                    storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                    applicationsToSync: [],
                    applicationsToIgnore: [],
                    originalText: ""
                )
            )
        )

        await viewModel.refresh()

        XCTAssertTrue(viewModel.isSyncAllMode)
        XCTAssertEqual(
            viewModel.state,
            .loaded([
                SyncableApplication(identifier: "git", displayName: "Git", isSynced: true),
                SyncableApplication(identifier: "raycast", displayName: "Raycast", isSynced: true)
            ])
        )
    }

    func testTogglingSyncOnWritesApplicationToSyncList() async throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .fileSystem, path: "/Sync", directory: "Mackup"),
                applicationsToSync: ["raycast"],
                applicationsToIgnore: ["xcode"],
                originalText: "[storage]\nengine = file_system\n"
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertFalse(viewModel.isSyncAllMode)
        XCTAssertTrue(viewModel.setSync(identifier: "git", isOn: true))

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, ["git", "raycast"])
        XCTAssertEqual(saved.applicationsToIgnore, ["xcode"])
        XCTAssertEqual(saved.storage, MackupStorage(engine: .fileSystem, path: "/Sync", directory: "Mackup"))
        if case .loaded(let apps) = viewModel.state {
            XCTAssertEqual(apps.first(where: { $0.identifier == "git" })?.isSynced, true)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testTogglingSyncOffInSyncAllModeExpandsToExplicitList() async throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertTrue(viewModel.isSyncAllMode)
        XCTAssertTrue(viewModel.setSync(identifier: "git", isOn: false))

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, ["raycast"])
        XCTAssertFalse(viewModel.isSyncAllMode)
        if case .loaded(let apps) = viewModel.state {
            XCTAssertEqual(apps.first(where: { $0.identifier == "git" })?.isSynced, false)
            XCTAssertEqual(apps.first(where: { $0.identifier == "raycast" })?.isSynced, true)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testSelectAllClearsApplicationsToSyncList() async throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: ["git"],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertFalse(viewModel.isSyncAllMode)
        viewModel.selectAll()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, [])
        XCTAssertTrue(viewModel.isSyncAllMode)
        if case .loaded(let apps) = viewModel.state {
            XCTAssertTrue(apps.allSatisfy(\.isSynced))
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testDeselectAllClearsAllApplications() async throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: [],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertTrue(viewModel.isSyncAllMode)
        viewModel.deselectAll()

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, [])
        XCTAssertEqual(saved.applicationsToIgnore, ["git", "raycast"])
        XCTAssertFalse(viewModel.isSyncAllMode)
        if case .loaded(let apps) = viewModel.state {
            XCTAssertTrue(apps.allSatisfy { !$0.isSynced })
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testTogglingOffLastExplicitlySyncedAppSyncsNothingNotEverything() async throws {
        // Explicit sync list of one app; turning it off must NOT collapse into
        // mackup's "empty means sync everything" — it must ignore all supported apps.
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: ["git"],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertFalse(viewModel.isSyncAllMode)
        XCTAssertTrue(viewModel.setSync(identifier: "git", isOn: false))

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, [])
        XCTAssertEqual(saved.applicationsToIgnore, ["git", "raycast"])
        XCTAssertFalse(viewModel.isSyncAllMode)
        if case .loaded(let apps) = viewModel.state {
            XCTAssertTrue(apps.allSatisfy { !$0.isSynced })
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func testTogglingSyncOffRemovesApplicationFromSyncList() async throws {
        let editor = FakeMackupConfigEditor(
            config: MackupConfig(
                fileURL: URL(fileURLWithPath: "/tmp/.mackup.cfg"),
                storage: MackupStorage(engine: .dropbox, path: nil, directory: nil),
                applicationsToSync: ["git", "raycast"],
                applicationsToIgnore: [],
                originalText: ""
            )
        )
        let viewModel = ApplicationsListViewModel(
            installedScanner: FakeInstalledApplicationScanner(applications: [
                MackupApplication(name: "git", displayName: "Git"),
                MackupApplication(name: "raycast", displayName: "Raycast")
            ]),
            catalog: FakeCatalog(identifiers: ["git", "raycast"]),
            configEditor: editor
        )
        await viewModel.refresh()

        XCTAssertTrue(viewModel.setSync(identifier: "git", isOn: false))

        let saved = try XCTUnwrap(editor.savedConfig)
        XCTAssertEqual(saved.applicationsToSync, ["raycast"])
    }
}

private struct FakeInstalledApplicationScanner: InstalledApplicationScanning {
    let applications: [MackupApplication]

    func scanInstalledApplications() throws -> [MackupApplication] {
        applications
    }
}

private struct FakeCatalog: MackupSupportedApplicationCataloging {
    let identifiers: [String]
    let error: Error?

    init(identifiers: [String]) {
        self.identifiers = identifiers
        self.error = nil
    }

    init(error: Error) {
        self.identifiers = []
        self.error = error
    }

    func supportedApplicationIdentifiers() async throws -> [String] {
        if let error {
            throw error
        }
        return identifiers
    }
}

private final class FakeMackupConfigEditor: MackupConfigEditing {
    private var config: MackupConfig
    private(set) var savedConfig: MackupConfig?

    init(config: MackupConfig) {
        self.config = config
    }

    func load(path: URL?) throws -> MackupConfig {
        config
    }

    func save(_ config: MackupConfig) throws {
        self.config = config
        savedConfig = config
    }
}
