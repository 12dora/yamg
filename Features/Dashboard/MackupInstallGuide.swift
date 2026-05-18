import Foundation

struct MackupInstallOption: Equatable, Identifiable {
    let id: String
    let title: String
    let command: String
    let executableName: String
    let arguments: [String]
}

struct MackupInstallGuide: Equatable {
    let options: [MackupInstallOption]

    static let mvp = MackupInstallGuide(
        options: [
            MackupInstallOption(
                id: "homebrew",
                title: "Homebrew",
                command: "brew install mackup",
                executableName: "brew",
                arguments: ["install", "mackup"]
            ),
            MackupInstallOption(
                id: "pipx",
                title: "pipx",
                command: "pipx install mackup",
                executableName: "pipx",
                arguments: ["install", "mackup"]
            )
        ]
    )
}
