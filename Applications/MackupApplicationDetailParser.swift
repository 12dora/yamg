import Foundation

enum MackupApplicationDetailParserError: Error, Equatable {
    case missingName
}

struct MackupApplicationDetailParser {
    func parse(_ output: String, applicationName: String) throws -> MackupApplicationDetail {
        var displayName: String?
        var configurationFiles: [String] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("Name:") {
                let name = trimmedLine
                    .dropFirst("Name:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    displayName = name
                }
                continue
            }

            if trimmedLine.hasPrefix("-") {
                let file = trimmedLine
                    .dropFirst()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !file.isEmpty {
                    configurationFiles.append(file)
                }
            }
        }

        guard let displayName else {
            throw MackupApplicationDetailParserError.missingName
        }

        return MackupApplicationDetail(
            applicationName: applicationName,
            displayName: displayName,
            configurationFiles: configurationFiles
        )
    }
}
