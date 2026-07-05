import Foundation

enum MackupStorageEngine: String, CaseIterable, Equatable {
    case dropbox
    case googleDrive = "google_drive"
    case iCloud = "icloud"
    case fileSystem = "file_system"

    var displayName: String {
        switch self {
        case .dropbox:
            return "Dropbox"
        case .googleDrive:
            return "Google Drive"
        case .iCloud:
            return "iCloud"
        case .fileSystem:
            return "File System"
        }
    }
}

struct MackupStorage: Equatable {
    var engine: MackupStorageEngine
    var path: String?
    var directory: String?
    /// The verbatim `engine = ...` value when it is not one of the engines YAMG
    /// models (e.g. mackup's `copy`). Preserved so a round-trip never rewrites or
    /// drops an engine the user's real config legitimately uses. `nil` when the
    /// engine matches a known `MackupStorageEngine` case.
    var rawEngine: String? = nil
}

struct MackupConfig: Equatable {
    var fileURL: URL
    var storage: MackupStorage
    var applicationsToSync: [String]
    var applicationsToIgnore: [String]

    var originalText: String
}

protocol MackupConfigEditing {
    func load(path: URL?) throws -> MackupConfig
    func save(_ config: MackupConfig) throws
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

        return MackupConfigParser.parse(text: text, fileURL: fileURL)
    }

    func save(_ config: MackupConfig) throws {
        let text = MackupConfigRenderer.render(config)
        let parentURL = config.fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try text.write(to: config.fileURL, atomically: true, encoding: .utf8)
    }
}

private enum MackupConfigParser {
    static func parse(text: String, fileURL: URL) -> MackupConfig {
        var currentSection: String?
        var engine = MackupStorageEngine.dropbox
        var rawEngine: String?
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
                        if let parsedEngine = MackupStorageEngine(rawValue: keyValue.value) {
                            engine = parsedEngine
                            rawEngine = nil
                        } else {
                            // Never throw on an unrecognized engine: mackup supports
                            // engines YAMG does not model (e.g. `copy`). Throwing here
                            // caused the caller's `try?` to swallow the error and
                            // overwrite the file with an empty config — catastrophic
                            // data loss. Preserve the raw value instead.
                            rawEngine = keyValue.value
                        }
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
            storage: MackupStorage(engine: engine, path: path, directory: directory, rawEngine: rawEngine),
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
        // Do NOT strip inline comments. mackup uses Python's configparser with the
        // default inline_comment_prefixes=None, so it treats `#`/`;` inside a value
        // as literal content. Stripping them here silently corrupted storage paths
        // like "/Volumes/Backup Drive #2".
        let value = trimmedLine[trimmedLine.index(after: separatorIndex)...]
            .trimmingCharacters(in: .whitespaces)

        return (key, value)
    }

    static func applicationName(from trimmedLine: String) -> String {
        if let separatorIndex = trimmedLine.firstIndex(of: "=") {
            return String(trimmedLine[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        }
        return trimmedLine
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
        // Normalize line endings first. CharacterSet.newlines treats CR and LF as
        // separate members, so splitting a CRLF file on it injects an empty
        // component between every line — which the verbatim echo below would turn
        // into spurious blank lines in preserved content.
        let normalizedText = config.originalText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let originalLines = normalizedText.components(separatedBy: "\n")
        var renderedSections = Set<String>()
        var index = 0

        while index < originalLines.count {
            let line = originalLines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let section = MackupConfigParser.sectionName(from: trimmed),
               supportedSections.contains(section) {
                // Guard against a config that contains the same supported section
                // twice: emit it only on first encounter, otherwise it would be
                // rendered (with the merged body) more than once, producing a file
                // mackup's strict configparser rejects.
                if !renderedSections.contains(section), shouldEmit(section: section, in: config) {
                    appendSection(section, config: config, originalLines: originalLines, startIndex: index, to: &output)
                }
                renderedSections.insert(section)
                index = nextSectionIndex(in: originalLines, after: index + 1)
            } else {
                output.append(line)
                index += 1
            }
        }

        for section in supportedSections.sorted()
        where !renderedSections.contains(section) && shouldEmit(section: section, in: config) {
            appendSeparatorIfNeeded(to: &output)
            appendSection(section, config: config, originalLines: [], startIndex: 0, to: &output)
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private static func shouldEmit(section: String, in config: MackupConfig) -> Bool {
        switch section {
        case "storage":
            return true
        case "applications_to_sync":
            return !config.applicationsToSync.isEmpty
        case "applications_to_ignore":
            return !config.applicationsToIgnore.isEmpty
        default:
            return false
        }
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
            output.append("engine = \(config.storage.rawEngine ?? config.storage.engine.rawValue)")

            if let path = config.storage.path, !path.isEmpty {
                output.append("path = \(path)")
            }

            if let directory = config.storage.directory, !directory.isEmpty {
                output.append("directory = \(directory)")
            }

            output.append(contentsOf: unsupportedStorageLines(in: originalLines, startIndex: startIndex))
        case "applications_to_sync":
            output.append("[applications_to_sync]")
            output.append(contentsOf: mergedApplicationLines(
                desired: config.applicationsToSync,
                originalLines: originalLines,
                startIndex: startIndex
            ))
        case "applications_to_ignore":
            output.append("[applications_to_ignore]")
            output.append(contentsOf: mergedApplicationLines(
                desired: config.applicationsToIgnore,
                originalLines: originalLines,
                startIndex: startIndex
            ))
        default:
            break
        }
    }

    /// Reconciles the desired application list against the section's original body
    /// so that user comments, blank lines, and formatting inside
    /// applications_to_sync / applications_to_ignore survive a save. Original app
    /// lines are kept verbatim when still desired (and dropped when the user
    /// toggled them off); newly-added apps are appended in the desired order.
    private static func mergedApplicationLines(
        desired: [String],
        originalLines: [String],
        startIndex: Int
    ) -> [String] {
        let desiredSet = Set(desired)
        var emitted: [String] = []
        var seen = Set<String>()

        if !originalLines.isEmpty {
            let endIndex = nextSectionIndex(in: originalLines, after: startIndex + 1)
            for line in originalLines[(startIndex + 1)..<endIndex] {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                    emitted.append(line)
                    continue
                }

                let name = MackupConfigParser.applicationName(from: trimmed)
                if desiredSet.contains(name), !seen.contains(name) {
                    emitted.append(line)
                    seen.insert(name)
                }
                // Otherwise the app was removed from the desired list: drop the line.
            }
        }

        for name in desired where !seen.contains(name) {
            emitted.append(name)
            seen.insert(name)
        }

        return emitted
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
