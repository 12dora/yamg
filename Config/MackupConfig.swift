import Foundation

enum MackupStorageEngine: String, CaseIterable, Equatable {
    case dropbox
    case googleDrive = "google_drive"
    case iCloud = "icloud"
    case fileSystem = "file_system"
}

struct MackupStorage: Equatable {
    var engine: MackupStorageEngine
    var path: String?
    var directory: String?
}

struct MackupConfig: Equatable {
    var fileURL: URL
    var storage: MackupStorage
    var applicationsToSync: [String]
    var applicationsToIgnore: [String]

    fileprivate var originalText: String
}

protocol MackupConfigEditing {
    func load(path: URL?) throws -> MackupConfig
    func save(_ config: MackupConfig) throws
}

enum MackupConfigError: Error, Equatable {
    case unsupportedStorageEngine(String)
}

final class MackupConfigEditor: MackupConfigEditing {
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    func load(path: URL?) throws -> MackupConfig {
        let fileURL = path ?? homeDirectory.appendingPathComponent(".mackup.cfg")
        let text: String

        if fileManager.fileExists(atPath: fileURL.path) {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } else {
            text = ""
        }

        return try MackupConfigParser.parse(text: text, fileURL: fileURL)
    }

    func save(_ config: MackupConfig) throws {
        let text = MackupConfigRenderer.render(config)
        let parentURL = config.fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try text.write(to: config.fileURL, atomically: true, encoding: .utf8)
    }
}

private enum MackupConfigParser {
    static func parse(text: String, fileURL: URL) throws -> MackupConfig {
        var currentSection: String?
        var engine = MackupStorageEngine.dropbox
        var path: String?
        var directory: String?
        var applicationsToSync: [String] = []
        var applicationsToIgnore: [String] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let section = sectionName(from: trimmed) {
                currentSection = section
                continue
            }

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else {
                continue
            }

            switch currentSection {
            case "storage":
                if let keyValue = keyValue(from: trimmed) {
                    switch keyValue.key {
                    case "engine":
                        guard let parsedEngine = MackupStorageEngine(rawValue: keyValue.value) else {
                            throw MackupConfigError.unsupportedStorageEngine(keyValue.value)
                        }
                        engine = parsedEngine
                    case "path":
                        path = keyValue.value
                    case "directory":
                        directory = keyValue.value
                    default:
                        break
                    }
                }
            case "applications_to_sync":
                applicationsToSync.append(applicationName(from: trimmed))
            case "applications_to_ignore":
                applicationsToIgnore.append(applicationName(from: trimmed))
            default:
                break
            }
        }

        return MackupConfig(
            fileURL: fileURL,
            storage: MackupStorage(engine: engine, path: path, directory: directory),
            applicationsToSync: applicationsToSync,
            applicationsToIgnore: applicationsToIgnore,
            originalText: text
        )
    }

    static func sectionName(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("["), trimmedLine.hasSuffix("]") else {
            return nil
        }

        return String(trimmedLine.dropFirst().dropLast())
    }

    static func keyValue(from trimmedLine: String) -> (key: String, value: String)? {
        guard let separatorIndex = trimmedLine.firstIndex(of: "=") else {
            return nil
        }

        let key = trimmedLine[..<separatorIndex].trimmingCharacters(in: .whitespaces)
        let rawValue = trimmedLine[trimmedLine.index(after: separatorIndex)...]
            .trimmingCharacters(in: .whitespaces)

        return (key, stripInlineComment(from: rawValue))
    }

    static func applicationName(from trimmedLine: String) -> String {
        if let separatorIndex = trimmedLine.firstIndex(of: "=") {
            return String(trimmedLine[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        }
        return trimmedLine
    }

    private static func stripInlineComment(from value: String) -> String {
        var result = value
        for marker in [" #", " ;"] {
            if let range = result.range(of: marker) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}

private enum MackupConfigRenderer {
    private static let supportedSections = Set([
        "storage",
        "applications_to_sync",
        "applications_to_ignore"
    ])

    static func render(_ config: MackupConfig) -> String {
        var output: [String] = []
        let originalLines = config.originalText.components(separatedBy: .newlines)
        var renderedSections = Set<String>()
        var index = 0

        while index < originalLines.count {
            let line = originalLines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let section = MackupConfigParser.sectionName(from: trimmed),
               supportedSections.contains(section) {
                appendSection(section, config: config, originalLines: originalLines, startIndex: index, to: &output)
                renderedSections.insert(section)
                index = nextSectionIndex(in: originalLines, after: index + 1)
            } else {
                output.append(line)
                index += 1
            }
        }

        for section in supportedSections.sorted() where !renderedSections.contains(section) {
            appendSeparatorIfNeeded(to: &output)
            appendSection(section, config: config, originalLines: [], startIndex: 0, to: &output)
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private static func appendSection(
        _ section: String,
        config: MackupConfig,
        originalLines: [String],
        startIndex: Int,
        to output: inout [String]
    ) {
        switch section {
        case "storage":
            output.append("[storage]")
            output.append("engine = \(config.storage.engine.rawValue)")

            if let path = config.storage.path, !path.isEmpty {
                output.append("path = \(path)")
            }

            if let directory = config.storage.directory, !directory.isEmpty {
                output.append("directory = \(directory)")
            }

            output.append(contentsOf: unsupportedStorageLines(in: originalLines, startIndex: startIndex))
        case "applications_to_sync":
            output.append("[applications_to_sync]")
            output.append(contentsOf: config.applicationsToSync)
        case "applications_to_ignore":
            output.append("[applications_to_ignore]")
            output.append(contentsOf: config.applicationsToIgnore)
        default:
            break
        }
    }

    private static func unsupportedStorageLines(in lines: [String], startIndex: Int) -> [String] {
        guard !lines.isEmpty else {
            return []
        }

        let endIndex = nextSectionIndex(in: lines, after: startIndex + 1)

        return lines[(startIndex + 1)..<endIndex].filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return false
            }

            guard let keyValue = MackupConfigParser.keyValue(from: trimmed) else {
                return trimmed.hasPrefix("#") || trimmed.hasPrefix(";")
            }

            return !["engine", "path", "directory"].contains(keyValue.key)
        }
    }

    private static func nextSectionIndex(in lines: [String], after startIndex: Int) -> Int {
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if MackupConfigParser.sectionName(from: trimmed) != nil {
                break
            }
            index += 1
        }

        return index
    }

    private static func appendSeparatorIfNeeded(to output: inout [String]) {
        if let last = output.last, !last.isEmpty {
            output.append("")
        }
    }
}
