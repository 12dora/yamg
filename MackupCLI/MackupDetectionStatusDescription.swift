import Foundation

extension MackupDetectionReport.Status {
    var userFacingDescription: String {
        switch self {
        case .found:
            return "Mackup CLI is available."
        case .notFound:
            return "Mackup CLI was not found."
        case .invalidVersionOutput(let output):
            return "Mackup version output could not be parsed: \(output)"
        case .failed(let message):
            return message
        }
    }
}
