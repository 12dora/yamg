import XCTest
@testable import YAMG

final class InstalledApplicationScannerTests: XCTestCase {
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

    func testScansInstalledAppBundlesAsUserFacingApplications() throws {
        try createAppBundle(named: "Raycast.app")
        try createAppBundle(named: "Visual Studio Code.app")
        try "not an app".write(
            to: temporaryDirectory.appendingPathComponent("README.txt"),
            atomically: true,
            encoding: .utf8
        )

        let scanner = InstalledApplicationScanner(searchDirectories: [temporaryDirectory])

        let applications = try scanner.scanInstalledApplications()

        XCTAssertEqual(
            applications,
            [
                MackupApplication(name: "raycast", displayName: "Raycast"),
                MackupApplication(name: "visual-studio-code", displayName: "Visual Studio Code")
            ]
        )
    }

    func testIdentifierFromDisplayNameNormalizesOriginalStrings() {
        XCTAssertEqual(MackupApplication.identifier(from: "Google Drive"), "google-drive")
        XCTAssertEqual(MackupApplication.identifier(from: "Visual Studio Code"), "visual-studio-code")
        XCTAssertEqual(MackupApplication.identifier(from: "Raycast"), "raycast")
    }

    private func createAppBundle(named name: String) throws {
        let appURL = temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
    }
}
