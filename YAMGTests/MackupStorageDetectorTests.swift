import SQLite3
import XCTest
@testable import YAMG

final class MackupStorageDetectorTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryHome {
            try? FileManager.default.removeItem(at: temporaryHome)
        }
    }

    func testDetectsDropboxFromMackupHostDBRule() throws {
        let dropboxURL = temporaryHome.appendingPathComponent("Dropbox", isDirectory: true)
        let hostDBURL = temporaryHome.appendingPathComponent(".dropbox/host.db")
        try FileManager.default.createDirectory(
            at: hostDBURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encodedPath = Data(dropboxURL.path.utf8).base64EncodedString()
        try "dummy\n\(encodedPath)\n".write(to: hostDBURL, atomically: true, encoding: .utf8)

        let availability = detector().availability()

        XCTAssertEqual(availability.first(where: { $0.engine == .dropbox })?.detectedPath, dropboxURL.path)
        XCTAssertEqual(availability.first(where: { $0.engine == .dropbox })?.isAvailable, true)
    }

    func testDetectsICloudFromMackupCloudDocsRule() throws {
        let iCloudURL = temporaryHome.appendingPathComponent(
            "Library/Mobile Documents/com~apple~CloudDocs",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)

        let availability = detector().availability()

        XCTAssertEqual(availability.first(where: { $0.engine == .iCloud })?.detectedPath, iCloudURL.path)
        XCTAssertEqual(availability.first(where: { $0.engine == .iCloud })?.isAvailable, true)
    }

    func testDetectsGoogleDriveFromMackupSQLiteRule() throws {
        let googleDriveURL = temporaryHome.appendingPathComponent("Google Drive", isDirectory: true)
        let databaseURL = temporaryHome.appendingPathComponent(
            "Library/Application Support/Google/Drive/user_default/sync_config.db"
        )
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try createGoogleDriveDatabase(at: databaseURL, path: googleDriveURL.path)

        let availability = detector().availability()

        XCTAssertEqual(availability.first(where: { $0.engine == .googleDrive })?.detectedPath, googleDriveURL.path)
        XCTAssertEqual(availability.first(where: { $0.engine == .googleDrive })?.isAvailable, true)
    }

    func testFileSystemIsAlwaysAvailableAndAutomaticProvidersCanBeUnavailable() {
        let availability = detector().availability()

        XCTAssertEqual(availability.first(where: { $0.engine == .fileSystem })?.isAvailable, true)
        XCTAssertEqual(availability.first(where: { $0.engine == .dropbox })?.isAvailable, false)
        XCTAssertEqual(availability.first(where: { $0.engine == .googleDrive })?.isAvailable, false)
        XCTAssertEqual(availability.first(where: { $0.engine == .iCloud })?.isAvailable, false)
    }

    private func detector() -> MackupStorageDetector {
        MackupStorageDetector(homeDirectory: temporaryHome)
    }

    private func createGoogleDriveDatabase(at url: URL, path: String) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer {
            sqlite3_close(database)
        }

        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE data (entry_key TEXT, data_value TEXT);", nil, nil, nil), SQLITE_OK)
        let insert = "INSERT INTO data (entry_key, data_value) VALUES ('local_sync_root_path', ?);"
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, insert, -1, &statement, nil), SQLITE_OK)
        defer {
            sqlite3_finalize(statement)
        }
        sqlite3_bind_text(statement, 1, path, -1, SQLITE_TRANSIENT)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
