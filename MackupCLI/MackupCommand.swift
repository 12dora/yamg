import Foundation

enum MackupCommandError: Error, Equatable {
    case emptyApplicationName
    case versionCommandDoesNotAcceptOptions
}

struct MackupCommand: Equatable {
    enum Action: Equatable {
        case version
        case list
        case show(application: String)
        case backup
        case restore
        case linkInstall
        case link
        case linkUninstall
    }

    enum ForceAnswer: Equatable {
        case yes
        case no
    }

    struct Options: Equatable {
        var dryRun: Bool
        var verbose: Bool
        var forceAnswer: ForceAnswer?
        var configFile: URL?

        init(
            dryRun: Bool = false,
            verbose: Bool = false,
            forceAnswer: ForceAnswer? = nil,
            configFile: URL? = nil
        ) {
            self.dryRun = dryRun
            self.verbose = verbose
            self.forceAnswer = forceAnswer
            self.configFile = configFile
        }

        var arguments: [String] {
            var result: [String] = []

            if dryRun {
                result.append("--dry-run")
            }

            if verbose {
                result.append("--verbose")
            }

            switch forceAnswer {
            case .yes:
                result.append("--force")
            case .no:
                result.append("--force-no")
            case .none:
                break
            }

            if let configFile {
                result.append("--config-file=\(configFile.path)")
            }

            return result
        }

        var isEmpty: Bool {
            !dryRun && !verbose && forceAnswer == nil && configFile == nil
        }
    }

    let action: Action
    let options: Options

    init(action: Action, options: Options = Options()) throws {
        switch action {
        case .show(let application):
            guard !application.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MackupCommandError.emptyApplicationName
            }
        case .version:
            guard options.isEmpty else {
                throw MackupCommandError.versionCommandDoesNotAcceptOptions
            }
        case .list, .backup, .restore, .linkInstall, .link, .linkUninstall:
            break
        }

        self.action = action
        self.options = options
    }

    static func version() -> MackupCommand {
        MackupCommand(action: .version, uncheckedOptions: Options())
    }

    static func list(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .list, uncheckedOptions: options)
    }

    static func show(application: String, options: Options = Options()) throws -> MackupCommand {
        try MackupCommand(action: .show(application: application), options: options)
    }

    static func backup(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .backup, uncheckedOptions: options)
    }

    static func restore(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .restore, uncheckedOptions: options)
    }

    static func linkInstall(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .linkInstall, uncheckedOptions: options)
    }

    static func link(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .link, uncheckedOptions: options)
    }

    static func linkUninstall(options: Options = Options()) -> MackupCommand {
        MackupCommand(action: .linkUninstall, uncheckedOptions: options)
    }

    var arguments: [String] {
        options.arguments + action.arguments
    }

    var description: String {
        switch action {
        case .version:
            return "mackup --version"
        case .list:
            return "mackup list"
        case .show(let application):
            return "mackup show \(application)"
        case .backup:
            return "mackup backup"
        case .restore:
            return "mackup restore"
        case .linkInstall:
            return "mackup link install"
        case .link:
            return "mackup link"
        case .linkUninstall:
            return "mackup link uninstall"
        }
    }

    private init(action: Action, uncheckedOptions options: Options) {
        self.action = action
        self.options = options
    }
}

private extension MackupCommand.Action {
    var arguments: [String] {
        switch self {
        case .version:
            return ["--version"]
        case .list:
            return ["list"]
        case .show(let application):
            return ["show", application]
        case .backup:
            return ["backup"]
        case .restore:
            return ["restore"]
        case .linkInstall:
            return ["link", "install"]
        case .link:
            return ["link"]
        case .linkUninstall:
            return ["link", "uninstall"]
        }
    }
}
