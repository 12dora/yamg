import Foundation
import SQLite3

struct MackupStorageAvailability: Equatable, Identifiable {
    var engine: MackupStorageEngine
    var detectedPath: String?
    var isAvailable: Bool
    var detail: String

    var id: MackupStorageEngine { engine }
}

protocol MackupStorageDetecting {
    func availability() -> [MackupStorageAvailability]
}

struct MackupStorageDetector: MackupStorageDetecting {
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func availability() -> [MackupStorageAvailability] {
        MackupStorageEngine.allCases.map { engine in
            switch engine {
            case .dropbox:
                return detectedAvailability(
                    engine: engine,
                    path: dropboxPath(),
                    missingDetail: "Dropbox host.db was not found or could not be decoded."
                )
            case .googleDrive:
                return detectedAvailability(
                    engine: engine,
                    path: googleDrivePath(),
                    missingDetail: "Google Drive sync_config.db was not found or did not contain local_sync_root_path."
                )
            case .iCloud:
                return detectedAvailability(
                    engine: engine,
                    path: iCloudPath(),
                    missingDetail: "iCloud Drive folder was not found."
                )
            case .fileSystem:
                return MackupStorageAvailability(
                    engine: engine,
                    detectedPath: nil,
                    isAvailable: true,
                    detail: "Choose any local or synced folder."
                )
            }
        }
    }

    private func detectedAvailability(
        engine: MackupStorageEngine,
        path: String?,
        missingDetail: String
    ) -> MackupStorageAvailability {
        if let path {
            return MackupStorageAvailability(
                engine: engine,
                detectedPath: path,
                isAvailable: true,
                detail: path
            )
        }

        return MackupStorageAvailability(
            engine: engine,
            detectedPath: nil,
            isAvailable: false,
            detail: missingDetail
        )
    }

    private func dropboxPath() -> String? {
        let hostDBURL = homeDirectory
            .appendingPathComponent(".dropbox", isDirectory: true)
            .appendingPathComponent("host.db")

        guard
            let text = try? String(contentsOf: hostDBURL, encoding: .utf8),
            text.split(whereSeparator: \.isWhitespace).count >= 2
        else {
            return nil
        }

        let fields = text.split(whereSeparator: \.isWhitespace)
        guard
            let data = Data(base64Encoded: String(fields[1])),
            let decoded = String(data: data, encoding: .utf8),
            !decoded.isEmpty
        else {
            return nil
        }

        return decoded
    }

    private func googleDrivePath() -> String? {
        let modernDBURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Google/Drive/user_default", isDirectory: true)
            .appendingPathComponent("sync_config.db")
        let legacyDBURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Google/Drive", isDirectory: true)
            .appendingPathComponent("sync_config.db")
        let dbURL = fileManager.fileExists(atPath: modernDBURL.path) ? modernDBURL : legacyDBURL

        guard fileManager.fileExists(atPath: dbURL.path) else {
            return nil
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer {
            sqlite3_close(database)
        }

        let query = "SELECT data_value FROM data WHERE entry_key = 'local_sync_root_path';"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let path = String(cString: cString)
        return path.isEmpty ? nil : path
    }

    private func iCloudPath() -> String? {
        let url = homeDirectory
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return url.path
    }
}
