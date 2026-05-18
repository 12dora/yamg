import Foundation

struct MackupInstallOption: Equatable, Identifiable {
    let id: String
    let title: String
    let command: String
}

struct MackupInstallGuide: Equatable {
    let options: [MackupInstallOption]

    static let mvp = MackupInstallGuide(
        options: [
            MackupInstallOption(
                id: "homebrew",
                title: "Homebrew",
                command: "brew install mackup"
            ),
            MackupInstallOption(
                id: "pipx",
                title: "pipx",
                command: "pipx install mackup"
            )
        ]
    )
}
