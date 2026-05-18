import Foundation

protocol InstalledApplicationScanning {
    func scanInstalledApplications() throws -> [MackupApplication]
}

struct InstalledApplicationScanner: InstalledApplicationScanning {
    private let fileManager: FileManager
    private let searchDirectories: [URL]

    init(
        fileManager: FileManager = .default,
        searchDirectories: [URL]? = nil
    ) {
        self.fileManager = fileManager
        self.searchDirectories = searchDirectories ?? InstalledApplicationScanner.defaultSearchDirectories
    }

    func scanInstalledApplications() throws -> [MackupApplication] {
        var applicationsByIdentifier: [String: MackupApplication] = [:]

        for directory in searchDirectories where fileManager.fileExists(atPath: directory.path) {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isApplicationKey, .localizedNameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                let displayName = applicationDisplayName(for: url)
                let identifier = MackupApplication.identifier(from: displayName)

                guard !identifier.isEmpty else {
                    continue
                }

                applicationsByIdentifier[identifier] = MackupApplication(
                    name: identifier,
                    displayName: displayName
                )
            }
        }

        return applicationsByIdentifier.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func applicationDisplayName(for url: URL) -> String {
        if let resourceValues = try? url.resourceValues(forKeys: [.localizedNameKey]),
           let localizedName = resourceValues.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localizedName.isEmpty {
            return localizedName.replacingOccurrences(of: ".app", with: "")
        }

        return url.deletingPathExtension().lastPathComponent
    }
}

extension InstalledApplicationScanner {
    static var defaultSearchDirectories: [URL] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
    }
}
