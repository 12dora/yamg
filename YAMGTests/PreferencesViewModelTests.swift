import XCTest
@testable import YAMG

@MainActor
final class PreferencesViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testLoadsExistingPathsFromPreferences() {
        let preferences = InMemoryPreferences(
            preferredCLIPath: URL(fileURLWithPath: "/opt/homebrew/bin/mackup"),
            configFilePath: URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg")
        )

        let viewModel = PreferencesViewModel(preferences: preferences)

        XCTAssertEqual(viewModel.cliPath, "/opt/homebrew/bin/mackup")
        XCTAssertEqual(viewModel.configPath, "/tmp/yamg/.mackup.cfg")
    }

    func testSaveNormalizesWhitespaceAndTildePaths() {
        let preferences = InMemoryPreferences()
        let viewModel = PreferencesViewModel(preferences: preferences)
        viewModel.cliPath = "  ~/bin/mackup  "
        viewModel.configPath = "  "

        viewModel.save()

        XCTAssertEqual(
            preferences.preferredCLIPath,
            URL(fileURLWithPath: NSString(string: "~/bin/mackup").expandingTildeInPath)
        )
        XCTAssertNil(preferences.configFilePath)
        XCTAssertEqual(viewModel.state, .saved)
    }

    func testResetClearsStoredPathsAndDeletesSelectedConfigFile() throws {
        let configFile = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try "[storage]\nengine = dropbox\n".write(to: configFile, atomically: true, encoding: .utf8)
        let preferences = InMemoryPreferences(
            preferredCLIPath: URL(fileURLWithPath: "/usr/local/bin/mackup"),
            configFilePath: configFile
        )
        let viewModel = PreferencesViewModel(preferences: preferences)

        viewModel.reset()

        XCTAssertFalse(FileManager.default.fileExists(atPath: configFile.path))
        XCTAssertNil(preferences.preferredCLIPath)
        XCTAssertNil(preferences.configFilePath)
        XCTAssertEqual(viewModel.cliPath, "")
        XCTAssertEqual(viewModel.configPath, "")
        XCTAssertEqual(viewModel.state, .reset)
    }

    func testResetDeletesDefaultConfigWhenNoCustomPathIsSet() throws {
        let defaultConfigFile = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try "[storage]\nengine = dropbox\n".write(to: defaultConfigFile, atomically: true, encoding: .utf8)
        let preferences = InMemoryPreferences()
        let viewModel = PreferencesViewModel(
            preferences: preferences,
            defaultConfigPath: defaultConfigFile
        )

        viewModel.reset()

        XCTAssertFalse(FileManager.default.fileExists(atPath: defaultConfigFile.path))
        XCTAssertEqual(viewModel.state, .reset)
    }

    func testDevelopmentResetSimulatesMissingConfigWithoutDeletingRealConfig() {
        let preferences = InMemoryPreferences(
            preferredCLIPath: URL(fileURLWithPath: "/usr/local/bin/mackup"),
            configFilePath: URL(fileURLWithPath: "/Users/test/.mackup.cfg")
        )
        let viewModel = PreferencesViewModel(preferences: preferences)

        viewModel.resetForFirstRunSimulation()

        XCTAssertNil(preferences.preferredCLIPath)
        XCTAssertEqual(
            preferences.configFilePath,
            URL(fileURLWithPath: "/tmp/yamg-development/missing-first-run.mackup.cfg")
        )
        XCTAssertEqual(viewModel.cliPath, "")
        XCTAssertEqual(viewModel.configPath, "/tmp/yamg-development/missing-first-run.mackup.cfg")
        XCTAssertEqual(viewModel.state, .developmentReset)
    }
}

private final class InMemoryPreferences: AppPreferencesStoring {
    var preferredCLIPath: URL?
    var configFilePath: URL?

    init(preferredCLIPath: URL? = nil, configFilePath: URL? = nil) {
        self.preferredCLIPath = preferredCLIPath
        self.configFilePath = configFilePath
    }

    func resetForFirstRunSimulation() {
        preferredCLIPath = nil
        configFilePath = URL(fileURLWithPath: "/tmp/yamg-development/missing-first-run.mackup.cfg")
    }
}
