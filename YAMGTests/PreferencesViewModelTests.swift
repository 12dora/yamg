import XCTest
@testable import YAMG

@MainActor
final class PreferencesViewModelTests: XCTestCase {
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

    func testResetClearsStoredPaths() {
        let preferences = InMemoryPreferences(
            preferredCLIPath: URL(fileURLWithPath: "/usr/local/bin/mackup"),
            configFilePath: URL(fileURLWithPath: "/tmp/.mackup.cfg")
        )
        let viewModel = PreferencesViewModel(preferences: preferences)

        viewModel.reset()

        XCTAssertNil(preferences.preferredCLIPath)
        XCTAssertNil(preferences.configFilePath)
        XCTAssertEqual(viewModel.cliPath, "")
        XCTAssertEqual(viewModel.configPath, "")
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
