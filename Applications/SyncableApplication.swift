import Foundation

struct SyncableApplication: Identifiable, Equatable {
    let identifier: String
    let displayName: String
    var isSynced: Bool

    var id: String { identifier }
}

enum SyncableApplicationMatcher {
    static func intersect(
        supportedIdentifiers: [String],
        installed: [MackupApplication]
    ) -> [(identifier: String, displayName: String)] {
        let identifierSet = Set(supportedIdentifiers)
        var matched: [(identifier: String, displayName: String)] = []
        var seen = Set<String>()

        for installedApp in installed {
            let slug = MackupApplication.identifier(from: installedApp.displayName)
            guard !slug.isEmpty else { continue }

            let identifier: String
            if identifierSet.contains(slug) {
                identifier = slug
            } else if identifierSet.contains(installedApp.name) {
                identifier = installedApp.name
            } else {
                continue
            }

            guard !seen.contains(identifier) else { continue }
            seen.insert(identifier)
            matched.append((identifier: identifier, displayName: installedApp.displayName))
        }

        matched.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return matched
    }
}
