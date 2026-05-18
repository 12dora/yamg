import Foundation

enum MackupApplicationListParserError: Error, Equatable {
    case noApplicationsFound
}

struct MackupApplicationListParser {
    func parse(_ output: String) throws -> [MackupApplication] {
        let names = output
            .components(separatedBy: .newlines)
            .compactMap(applicationName(from:))

        let uniqueNames = Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        guard !uniqueNames.isEmpty else {
            throw MackupApplicationListParserError.noApplicationsFound
        }

        return uniqueNames.map(MackupApplication.init(name:))
    }

    private func applicationName(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.hasPrefix("-") else {
            return nil
        }

        let name = trimmedLine
            .dropFirst()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? nil : name
    }
}
