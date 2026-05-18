import Foundation

struct MackupApplication: Identifiable, Equatable {
    let name: String

    var id: String { name }
}
