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
            configFilePath: URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg"),
            showsLinkMode: true
        )

        let viewModel = PreferencesViewModel(preferences: preferences)

        XCTAssertEqual(viewModel.cliPath, "/opt/homebrew/bin/mackup")
        XCTAssertEqual(viewModel.configPath, "/tmp/yamg/.mackup.cfg")
        XCTAssertTrue(viewModel.showsLinkMode)
    }

    func testSaveNormalizesWhitespaceAndTildePaths() throws {
        let executableFile = temporaryDirectory.appendingPathComponent("mackup")
        try "#!/bin/bash\necho test".write(to: executableFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableFile.path)

        let preferences = InMemoryPreferences()
        let viewModel = PreferencesViewModel(preferences: preferences)
        viewModel.cliPath = "  \(executableFile.path)  "
        viewModel.configPath = "  "
        viewModel.showsLinkMode = true

        viewModel.save()

        XCTAssertEqual(preferences.preferredCLIPath, executableFile)
        XCTAssertNil(preferences.configFilePath)
        XCTAssertTrue(preferences.showsLinkMode)
        XCTAssertEqual(viewModel.state, .saved)
    }

    func testSaveFailsWhenCLIPathIsNotExecutable() {
        let preferences = InMemoryPreferences()
        let viewModel = PreferencesViewModel(preferences: preferences)
        viewModel.cliPath = "/nonexistent/path/mackup"

        viewModel.save()

        if case .failed(let message) = viewModel.state {
            // The message is now a localization key rendered via LocalizedStringKey
            // so it follows the in-app language instead of being a hardcoded string.
            XCTAssertEqual(message, "preferences.cli_path.invalid")
        } else {
            XCTFail("Expected failed state with non-executable path")
        }
    }

    func testEditingAfterSaveClearsSavedIndicator() throws {
        let executableFile = temporaryDirectory.appendingPathComponent("mackup")
        try "#!/bin/bash\necho test".write(to: executableFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableFile.path)

        let viewModel = PreferencesViewModel(preferences: InMemoryPreferences())
        viewModel.cliPath = executableFile.path
        viewModel.save()
        XCTAssertEqual(viewModel.state, .saved)

        // Editing a field after a successful save must drop the "Saved" indicator
        // so the UI never claims unsaved values are persisted.
        viewModel.showsLinkMode = true
        XCTAssertEqual(viewModel.state, .editing)
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
        XCTAssertFalse(preferences.showsLinkMode)
        XCTAssertEqual(viewModel.cliPath, "")
        XCTAssertEqual(viewModel.configPath, "")
        XCTAssertFalse(viewModel.showsLinkMode)
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

    func testResetDeletesBothSelectedAndDefaultConfigFiles() throws {
        let selectedConfigFile = temporaryDirectory.appendingPathComponent("selected/.mackup.cfg")
        let defaultConfigFile = temporaryDirectory.appendingPathComponent("default/.mackup.cfg")
        try FileManager.default.createDirectory(
            at: selectedConfigFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: defaultConfigFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "[storage]\nengine = icloud\n".write(to: selectedConfigFile, atomically: true, encoding: .utf8)
        try "[storage]\nengine = dropbox\n".write(to: defaultConfigFile, atomically: true, encoding: .utf8)
        let preferences = InMemoryPreferences(configFilePath: selectedConfigFile)
        let viewModel = PreferencesViewModel(
            preferences: preferences,
            defaultConfigPath: defaultConfigFile
        )

        viewModel.reset()

        XCTAssertFalse(FileManager.default.fileExists(atPath: selectedConfigFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: defaultConfigFile.path))
        XCTAssertNil(preferences.configFilePath)
        XCTAssertEqual(viewModel.state, .reset)
    }

    func testPathSelectionsUpdatePreferenceFields() {
        let viewModel = PreferencesViewModel(preferences: InMemoryPreferences())

        viewModel.selectCLIPath(URL(fileURLWithPath: "/opt/homebrew/bin/mackup"))
        viewModel.selectConfigPath(URL(fileURLWithPath: "/Users/test/.mackup.cfg"))

        XCTAssertEqual(viewModel.cliPath, "/opt/homebrew/bin/mackup")
        XCTAssertEqual(viewModel.configPath, "/Users/test/.mackup.cfg")
    }
}

private final class InMemoryPreferences: AppPreferencesStoring {
    var preferredCLIPath: URL?
    var configFilePath: URL?
    var showsLinkMode: Bool
    var preferredLanguage: AppLanguage

    init(preferredCLIPath: URL? = nil, configFilePath: URL? = nil, showsLinkMode: Bool = false, preferredLanguage: AppLanguage = .system) {
        self.preferredCLIPath = preferredCLIPath
        self.configFilePath = configFilePath
        self.showsLinkMode = showsLinkMode
        self.preferredLanguage = preferredLanguage
    }
}
