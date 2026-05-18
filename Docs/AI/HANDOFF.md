# Handoff

2026-05-18 19:40 CST | Codex
Done: implemented P1 Onboarding MVP dashboard showing Mackup CLI detection/version state and default `.mackup.cfg` presence without invoking backup/restore/link behavior.
Changed: `Features/Dashboard/DashboardView.swift`, `Features/Dashboard/DashboardViewModel.swift`, `Features/RootShellView.swift`, `Support/LocalizationKey.swift`, `Resources/Localizable.xcstrings`, `YAMGTests/DashboardViewModelTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `jq empty Resources/Localizable.xcstrings`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests` passed. Full `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS'` ran unit tests successfully but failed when UI test runner timed out enabling automation mode.
Next: implement P1 Applications list via `mackup list`.
Blocked: UI test automation mode timeout in this shell environment.

2026-05-18 19:27 CST | Codex
Done: added `Localizable.xcstrings` zh-Hans/en baseline and wired current app shell copy through localization keys.
Changed: `Resources/Localizable.xcstrings`, `Support/LocalizationKey.swift`, `Features/AppSection.swift`, `Features/RootShellView.swift`, `YAMGTests/AppSectionTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `jq empty Resources/Localizable.xcstrings`; `plutil -lint YAMG.xcodeproj/project.pbxproj`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: start P1 Onboarding MVP.
Blocked: none.

2026-05-18 19:24 CST | Codex
Done: implemented `.mackup.cfg` read/write for Mackup-supported fields only: `[storage]`, `[applications_to_sync]`, and `[applications_to_ignore]`; preserves unknown sections and storage keys without writing YAMG metadata.
Changed: `Config/MackupConfig.swift`, `YAMGTests/MackupConfigTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: add `Localizable.xcstrings` zh-Hans/en baseline.
Blocked: none.

2026-05-18 19:21 CST | Codex
Done: implemented actor-backed in-memory `ProcessLogStore` with run records, ordered process event entries, finish/fail status updates, and missing-run errors.
Changed: `Logging/ProcessLogStore.swift`, `YAMGTests/ProcessLogStoreTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: implement `.mackup.cfg` read/write.
Blocked: none.

2026-05-18 19:18 CST | Codex
Done: implemented `MackupDetector`, `MackupVersion`, and version parser; detector checks preferred path before default candidate paths and validates via `mackup --version` through the runner abstraction.
Changed: `MackupCLI/MackupDetector.swift`, `YAMGTests/MackupDetectorTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: implement `ProcessLogStore`.
Blocked: none.

2026-05-18 19:16 CST | Codex
Done: implemented `MackupProcessRunner` with `Process.executableURL`, safe argument passing, streamed stdout/stderr events, exit result events, cancellation cleanup, and missing executable validation.
Changed: `MackupCLI/MackupProcessRunner.swift`, `YAMGTests/MackupProcessRunnerTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: implement `MackupDetector` and version parser.
Blocked: none.

2026-05-18 19:10 CST | Codex
Done: implemented `MackupCommand` and argv builder for the allowed Mackup CLI surface; validated version/ignored upstream state before coding.
Changed: `MackupCLI/MackupCommand.swift`, `YAMGTests/MackupCommandTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS'`.
Next: implement `MackupProcessRunner` with streamed stdout/stderr.
Blocked: none.

2026-05-18 Asia/Shanghai | Codex
Done: initialized YAMG work docs/scaffold directories; set VERSION to 0.10.3; prepared Git ignore to exclude upstream `mackup/`.
Changed: `.gitignore`, `README.md`, `VERSION`, `Docs/AI/*`, `Docs/Engineering/SCAFFOLD.md`.
Tests: not applicable; documentation/scaffold only.
Next: create SwiftUI macOS Xcode project and implement P0 modules.
Blocked: none.

2026-05-18 19:03 CST | Codex
Done: fixed Xcode target settings exposed by full Xcode; added target product names/bundle identifiers, removed invalid SwiftUI app `NSPrincipalClass`, changed signing to local ad-hoc signing so Debug builds are runnable locally instead of appearing damaged.
Changed: `YAMG.xcodeproj/project.pbxproj`.
Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild clean -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS,arch=arm64'`; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS,arch=arm64'`; `codesign --verify --deep --strict --verbose=2 <DerivedData>/YAMG.app`; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS,arch=arm64' -only-testing:YAMGTests`.
Next: implement `MackupCommand` and argv builder.
Blocked: UI test runner still exits before connection in this shell environment; unit tests pass.

2026-05-18 18:53 CST | Codex
Done: created minimal SwiftUI macOS Xcode project; added app/sidebar shell for Dashboard, Applications, Storage, Logs, Preferences; added unit/UI test targets and baseline tests.
Changed: `YAMG.xcodeproj`, `App/YAMGApp.swift`, `Features/AppSection.swift`, `Features/RootShellView.swift`, `YAMGTests/AppSectionTests.swift`, `YAMGUITests/YAMGUITests.swift`, `Docs/AI/TASKS.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `xmllint --noout YAMG.xcodeproj/xcshareddata/xcschemes/YAMG.xcscheme`; `swiftc -typecheck -parse-as-library -target arm64-apple-macosx12.0 App/YAMGApp.swift Features/AppSection.swift Features/RootShellView.swift`. `xcodebuild` and XCTest checks blocked because active developer directory is CommandLineTools, not full Xcode.
Next: implement `MackupCommand` and argv builder.
Blocked: full Xcode is required for `xcodebuild test`.

2026-05-18 Asia/Shanghai | Codex
Done: added reusable coding AI start prompt.
Changed: `Docs/AI/CODING_PROMPT.md`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: not applicable; documentation only.
Next: paste `Docs/AI/CODING_PROMPT.md` into a coding AI before implementation work.
Blocked: none.
