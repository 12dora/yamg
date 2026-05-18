import Foundation

struct MackupVersion: Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: MackupVersion, rhs: MackupVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

enum MackupVersionParser {
    private static let versionPattern = #"\b(\d+)\.(\d+)\.(\d+)\b"#

    static func parse(_ output: String) -> MackupVersion? {
        guard let regex = try? NSRegularExpression(pattern: versionPattern) else {
            return nil
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range), match.numberOfRanges == 4 else {
            return nil
        }

        func component(at index: Int) -> Int? {
            guard let range = Range(match.range(at: index), in: output) else {
                return nil
            }
            return Int(output[range])
        }

        guard
            let major = component(at: 1),
            let minor = component(at: 2),
            let patch = component(at: 3)
        else {
            return nil
        }

        return MackupVersion(major: major, minor: minor, patch: patch)
    }
}

struct MackupDetectionReport: Equatable {
    enum Status: Equatable {
        case found
        case notFound
        case invalidVersionOutput(String)
        case failed(String)
    }

    let status: Status
    let executableURL: URL?
    let version: MackupVersion?
    let checkedURLs: [URL]

    var isUsable: Bool {
        if case .found = status {
            return true
        }
        return false
    }
}

protocol MackupExecutableResolving {
    func detect(preferredPath: URL?) async -> MackupDetectionReport
}

final class MackupDetector: MackupExecutableResolving {
    typealias RunnerFactory = (URL) -> MackupCommandRunning

    private let candidateURLs: [URL]
    private let fileManager: FileManager
    private let runnerFactory: RunnerFactory

    init(
        candidateURLs: [URL] = MackupDetector.defaultCandidateURLs,
        fileManager: FileManager = .default,
        runnerFactory: @escaping RunnerFactory = { MackupProcessRunner(executableURL: $0) }
    ) {
        self.candidateURLs = candidateURLs
        self.fileManager = fileManager
        self.runnerFactory = runnerFactory
    }

    func detect(preferredPath: URL?) async -> MackupDetectionReport {
        let checkedURLs = candidateList(preferredPath: preferredPath)

        for candidate in checkedURLs {
            guard fileManager.isExecutableFile(atPath: candidate.path) else {
                continue
            }

            return await detectExecutable(at: candidate, checkedURLs: checkedURLs)
        }

        return MackupDetectionReport(
            status: .notFound,
            executableURL: nil,
            version: nil,
            checkedURLs: checkedURLs
        )
    }

    private func candidateList(preferredPath: URL?) -> [URL] {
        var result: [URL] = []

        if let preferredPath {
            result.append(preferredPath)
        }

        for candidate in candidateURLs where !result.contains(candidate) {
            result.append(candidate)
        }

        return result
    }

    private func detectExecutable(at url: URL, checkedURLs: [URL]) async -> MackupDetectionReport {
        let runner = runnerFactory(url)
        var output = ""

        do {
            for try await event in runner.run(.version()) {
                switch event {
                case .output(let text, .stdout), .output(let text, .stderr):
                    output += text
                case .finished(let result):
                    guard result.exitCode == 0 else {
                        return MackupDetectionReport(
                            status: .failed("mackup --version exited with code \(result.exitCode)"),
                            executableURL: url,
                            version: nil,
                            checkedURLs: checkedURLs
                        )
                    }
                }
            }
        } catch {
            return MackupDetectionReport(
                status: .failed(error.localizedDescription),
                executableURL: url,
                version: nil,
                checkedURLs: checkedURLs
            )
        }

        guard let version = MackupVersionParser.parse(output) else {
            return MackupDetectionReport(
                status: .invalidVersionOutput(output),
                executableURL: url,
                version: nil,
                checkedURLs: checkedURLs
            )
        }

        return MackupDetectionReport(
            status: .found,
            executableURL: url,
            version: version,
            checkedURLs: checkedURLs
        )
    }
}

extension MackupDetector {
    static let defaultCandidateURLs: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/bin/mackup"),
        URL(fileURLWithPath: "/usr/local/bin/mackup"),
        URL(fileURLWithPath: "/usr/bin/mackup")
    ]
}
