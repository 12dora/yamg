import XCTest
@testable import YAMG

final class MackupConfigTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testLoadParsesSupportedMackupFields() throws {
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        [storage]
        engine = file_system
        path = dotfiles backup
        directory = Mackup

        [applications_to_sync]
        vim
        git

        [applications_to_ignore]
        xcode
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)

        let config = try editor.load(path: fileURL)

        XCTAssertEqual(config.storage.engine, .fileSystem)
        XCTAssertEqual(config.storage.path, "dotfiles backup")
        XCTAssertEqual(config.storage.directory, "Mackup")
        XCTAssertEqual(config.applicationsToSync, ["vim", "git"])
        XCTAssertEqual(config.applicationsToIgnore, ["xcode"])
    }

    func testLoadDefaultsMissingConfigToDropboxStorage() throws {
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)

        let config = try editor.load(path: nil)

        XCTAssertEqual(config.fileURL, temporaryDirectory.appendingPathComponent(".mackup.cfg"))
        XCTAssertEqual(config.storage.engine, .dropbox)
        XCTAssertNil(config.storage.path)
        XCTAssertNil(config.storage.directory)
        XCTAssertEqual(config.applicationsToSync, [])
        XCTAssertEqual(config.applicationsToIgnore, [])
    }

    func testLoadPreservesUnrecognizedStorageEngineInsteadOfThrowing() throws {
        // mackup supports engines YAMG does not model (e.g. `copy`). Loading such a
        // config must NOT throw — a throw was swallowed by the caller's `try?` and
        // caused the whole file (app lists, comments) to be overwritten on save.
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        [storage]
        engine = copy
        directory = Mackup

        [applications_to_sync]
        vim
        git
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)

        let config = try editor.load(path: fileURL)

        XCTAssertEqual(config.applicationsToSync, ["vim", "git"])

        // Saving an untouched config must re-emit the original engine verbatim.
        try editor.save(config)
        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(saved.contains("engine = copy"))
        XCTAssertTrue(saved.contains("[applications_to_sync]\nvim\ngit"))
    }

    func testLoadDoesNotStripInlineCommentCharactersFromStoragePath() throws {
        // configparser (used by mackup) does not treat `#`/`;` inside a value as an
        // inline comment, so a legitimate path like this must round-trip intact.
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        [storage]
        engine = file_system
        path = /Volumes/Backup Drive #2
        directory = Mackup
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)

        let config = try editor.load(path: fileURL)

        XCTAssertEqual(config.storage.path, "/Volumes/Backup Drive #2")
    }

    func testSavePreservesCommentsAndBlankLinesInsideApplicationSections() throws {
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        [applications_to_sync]
        vim
        # editors group
        git
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)
        var config = try editor.load(path: fileURL)
        // Add an app; existing apps and the interleaved comment must survive.
        config.applicationsToSync = ["vim", "git", "fish"]

        try editor.save(config)

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(saved.contains("# editors group"))
        XCTAssertTrue(saved.contains("fish"))
        XCTAssertTrue(saved.contains("vim"))
        XCTAssertTrue(saved.contains("git"))
    }

    func testSaveDoesNotDuplicateRepeatedSupportedSection() throws {
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        [applications_to_sync]
        vim

        [applications_to_sync]
        git
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)
        let config = try editor.load(path: fileURL)

        try editor.save(config)

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        let occurrences = saved.components(separatedBy: "[applications_to_sync]").count - 1
        XCTAssertEqual(occurrences, 1)
    }

    func testSaveNormalizesCRLFAndDoesNotInjectBlankLinesIntoPreservedContent() throws {
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        let crlf = "[storage]\r\nengine = dropbox\r\n\r\n[custom_tool]\r\nfoo = bar\r\nbaz = qux\r\n"
        try crlf.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)
        let config = try editor.load(path: fileURL)

        try editor.save(config)

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(saved.contains("\r"))
        // The preserved unknown section must not gain spurious blank lines.
        XCTAssertTrue(saved.contains("[custom_tool]\nfoo = bar\nbaz = qux"))
    }

    func testSaveWritesOnlySupportedMackupSectionsAndPreservesUnknownContent() throws {
        let fileURL = temporaryDirectory.appendingPathComponent(".mackup.cfg")
        try """
        # user comment
        [storage]
        engine = dropbox
        custom_storage_key = keep-me

        [unknown_section]
        yamg_should_not_touch = true

        [applications_to_sync]
        old-app
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)
        var config = try editor.load(path: fileURL)
        config.storage = MackupStorage(engine: .fileSystem, path: "dotfiles", directory: "backup")
        config.applicationsToSync = ["vim", "git"]
        config.applicationsToIgnore = ["xcode"]

        try editor.save(config)

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(saved.contains("# user comment"))
        XCTAssertTrue(saved.contains("[unknown_section]\nyamg_should_not_touch = true"))
        XCTAssertTrue(saved.contains("custom_storage_key = keep-me"))
        XCTAssertTrue(saved.contains("[storage]\nengine = file_system\npath = dotfiles\ndirectory = backup"))
        XCTAssertTrue(saved.contains("[applications_to_sync]\nvim\ngit"))
        XCTAssertTrue(saved.contains("[applications_to_ignore]\nxcode"))
        XCTAssertFalse(saved.contains("old-app"))
        XCTAssertFalse(saved.localizedCaseInsensitiveContains("yamg_metadata"))
    }

    func testSaveCreatesConfigWhenFileDoesNotExist() throws {
        let fileURL = temporaryDirectory.appendingPathComponent("nested/.mackup.cfg")
        let editor = MackupConfigEditor(homeDirectory: temporaryDirectory)
        var config = try editor.load(path: fileURL)
        config.storage = MackupStorage(engine: .iCloud, path: nil, directory: ".config/mackup")
        config.applicationsToSync = ["fish"]
        config.applicationsToIgnore = []

        try editor.save(config)

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(saved.contains("[storage]\nengine = icloud\ndirectory = .config/mackup"))
        XCTAssertTrue(saved.contains("[applications_to_sync]\nfish"))
        XCTAssertFalse(saved.contains("[applications_to_ignore]"))
    }
}
