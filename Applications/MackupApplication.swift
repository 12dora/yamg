import Foundation

struct MackupApplication: Identifiable, Equatable {
    let name: String
    let displayName: String

    init(name: String, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
    }

    var id: String { name }

    static func identifier(from displayName: String) -> String {
        let lowered = displayName
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        let slug = lowered.replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "-",
            options: .regularExpression
        )

        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
