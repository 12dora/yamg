# Scaffold

Version: `0.10.3`.

## Directory Intent

```text
App/           app entry, environment, commands
Features/      SwiftUI screens and view models
MackupCLI/     detection, command builder, Process runner, parsers
Config/        .mackup.cfg model and INI read/write
Applications/  Mackup app list/detail models
Logging/       run metadata and stdout/stderr logs
Support/       filesystem, defaults, permissions, version helpers
Resources/     Localizable.xcstrings, assets
Tests/         shared fixtures
YAMGTests/     unit tests
YAMGUITests/   UI tests
Docs/AI/       agent state, rules, task queue, handoff
```

## Core Protocols

```swift
protocol MackupExecutableResolving {
    func detect(preferredPath: URL?) async -> MackupDetectionReport
}

protocol MackupCommandRunning {
    func run(_ command: MackupCommand) -> AsyncThrowingStream<ProcessEvent, Error>
}

protocol MackupConfigEditing {
    func load(path: URL?) throws -> MackupConfig
    func save(_ config: MackupConfig) throws
}

protocol ProcessLogPersisting {
    func createRun(command: MackupCommand) throws -> RunRecord
    func append(_ event: ProcessEvent, to runID: UUID) async throws
    func finish(runID: UUID, result: ProcessResult) async throws
}
```

## MVP Command Surface

- `mackup --version`
- `mackup list`
- `mackup show <application>`
- `mackup backup`
- `mackup restore`
- optional flags: `--dry-run`, `--verbose`, `--force`, `--force-no`, `--config-file=<path>`

No shell string execution. Build `Process.executableURL` and `arguments`.

