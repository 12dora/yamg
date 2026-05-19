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

        // Use a Unicode-aware separator class so non-ASCII names (e.g. pure CJK)
        // still produce a non-empty identifier instead of collapsing to "".
        let slug = lowered.replacingOccurrences(
            of: #"[^\p{L}\p{N}]+"#,
            with: "-",
            options: .regularExpression
        )

        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
