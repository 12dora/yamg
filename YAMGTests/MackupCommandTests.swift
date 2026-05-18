import XCTest
@testable import YAMG

final class MackupCommandTests: XCTestCase {
    func testVersionBuildsStandaloneArgument() {
        XCTAssertEqual(MackupCommand.version().arguments, ["--version"])
    }

    func testListBuildsArguments() {
        XCTAssertEqual(MackupCommand.list().arguments, ["list"])
    }

    func testShowBuildsApplicationArgumentWithoutShellSplitting() throws {
        let command = try MackupCommand.show(application: "visual-studio-code")

        XCTAssertEqual(command.arguments, ["show", "visual-studio-code"])
    }

    func testShowRejectsEmptyApplicationName() {
        XCTAssertThrowsError(try MackupCommand.show(application: "  \n")) { error in
            XCTAssertEqual(error as? MackupCommandError, .emptyApplicationName)
        }
    }

    func testBackupBuildsCopyModeDryRunArguments() {
        let command = MackupCommand.backup(options: .init(dryRun: true, verbose: true))

        XCTAssertEqual(command.arguments, ["--dry-run", "--verbose", "backup"])
    }

    func testRestoreBuildsConfigFileArgumentBeforeAction() {
        let command = MackupCommand.restore(
            options: .init(configFile: URL(fileURLWithPath: "/tmp/yamg/.mackup.cfg"))
        )

        XCTAssertEqual(command.arguments, ["--config-file=/tmp/yamg/.mackup.cfg", "restore"])
    }

    func testForceYesAndForceNoAreDistinctArguments() {
        XCTAssertEqual(
            MackupCommand.backup(options: .init(forceAnswer: .yes)).arguments,
            ["--force", "backup"]
        )
        XCTAssertEqual(
            MackupCommand.restore(options: .init(forceAnswer: .no)).arguments,
            ["--force-no", "restore"]
        )
    }

    func testLinkModeCommandsAreExplicitAdvancedActions() {
        XCTAssertEqual(MackupCommand.linkInstall().arguments, ["link", "install"])
        XCTAssertEqual(MackupCommand.link().arguments, ["link"])
        XCTAssertEqual(MackupCommand.linkUninstall().arguments, ["link", "uninstall"])
    }

    func testVersionRejectsOperationalOptions() {
        XCTAssertThrowsError(
            try MackupCommand(action: .version, options: .init(dryRun: true))
        ) { error in
            XCTAssertEqual(error as? MackupCommandError, .versionCommandDoesNotAcceptOptions)
        }
    }
}
