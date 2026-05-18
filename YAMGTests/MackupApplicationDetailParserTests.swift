import XCTest
@testable import YAMG

final class MackupApplicationDetailParserTests: XCTestCase {
    func testParseExtractsDisplayNameAndConfigurationFiles() throws {
        let output = """
        Name: Git
        Configuration files:
         - .gitconfig
         - .config/git/config
        """

        let detail = try MackupApplicationDetailParser().parse(output, applicationName: "git")

        XCTAssertEqual(
            detail,
            MackupApplicationDetail(
                applicationName: "git",
                displayName: "Git",
                configurationFiles: [".gitconfig", ".config/git/config"]
            )
        )
    }

    func testParseAllowsApplicationWithoutConfigurationFiles() throws {
        let output = """
        Name: Empty App
        Configuration files:
        """

        let detail = try MackupApplicationDetailParser().parse(output, applicationName: "empty")

        XCTAssertEqual(detail.configurationFiles, [])
        XCTAssertEqual(detail.displayName, "Empty App")
    }

    func testParseRejectsOutputWithoutName() {
        XCTAssertThrowsError(
            try MackupApplicationDetailParser().parse("Configuration files:\n - .gitconfig", applicationName: "git")
        ) { error in
            XCTAssertEqual(error as? MackupApplicationDetailParserError, .missingName)
        }
    }
}
