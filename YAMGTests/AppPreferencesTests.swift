import XCTest
@testable import YAMG

final class AppPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "YAMGTests.AppPreferences.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testPersistsPreferredCLIAndConfigPaths() throws {
        let preferences = try XCTUnwrap(defaults).makePreferences()
        let cliPath = URL(fileURLWithPath: "/opt/homebrew/bin/mackup")
        let configPath = URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg")

        preferences.preferredCLIPath = cliPath
        preferences.configFilePath = configPath

        let reloaded = try XCTUnwrap(defaults).makePreferences()
        XCTAssertEqual(reloaded.preferredCLIPath, cliPath)
        XCTAssertEqual(reloaded.configFilePath, configPath)
    }

    func testClearingPathsRemovesStoredValues() throws {
        let preferences = try XCTUnwrap(defaults).makePreferences()
        preferences.preferredCLIPath = URL(fileURLWithPath: "/usr/local/bin/mackup")
        preferences.configFilePath = URL(fileURLWithPath: "/tmp/.mackup.cfg")

        preferences.preferredCLIPath = nil
        preferences.configFilePath = nil

        XCTAssertNil(preferences.preferredCLIPath)
        XCTAssertNil(preferences.configFilePath)
    }

    func testDevelopmentResetUsesMissingConfigPathAndClearsCLIOverride() throws {
        let preferences = try XCTUnwrap(defaults).makePreferences()
        preferences.preferredCLIPath = URL(fileURLWithPath: "/usr/local/bin/mackup")
        preferences.configFilePath = URL(fileURLWithPath: "/Users/test/.mackup.cfg")

        preferences.resetForFirstRunSimulation()

        XCTAssertNil(preferences.preferredCLIPath)
        XCTAssertEqual(preferences.configFilePath?.lastPathComponent, "missing-first-run.mackup.cfg")
        XCTAssertEqual(preferences.configFilePath?.path.contains("/YAMG/Development/"), true)
    }
}

private extension UserDefaults {
    func makePreferences() -> AppPreferences {
        AppPreferences(defaults: self)
    }
}
