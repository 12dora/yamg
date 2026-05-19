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

        return uniqueNames.map { MackupApplication(name: $0) }
    }

    private func applicationName(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // mackup CLI output is ASCII-only; use a locale-independent compare so
        // running under a non-English locale doesn't mis-match header lines.
        let bannerKeywords = ["supported applications", "applications supported", "error:"]
        let loweredLine = trimmedLine.lowercased()
        guard !trimmedLine.isEmpty,
              !bannerKeywords.contains(where: { loweredLine.contains($0) }) else {
            return nil
        }

        let name: String

        if let first = trimmedLine.first, first == "-" || first == "*" {
            name = trimmedLine
                .dropFirst()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            name = trimmedLine
        }

        guard isApplicationIdentifier(name) else {
            return nil
        }

        return name
    }

    private func isApplicationIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9][A-Za-z0-9._+-]*$"#, options: .regularExpression) != nil
    }
}
