# Handoff

2026-05-18 23:43 CST | Codex
Done: addressed UX follow-up fixes: Applications now scans installed `.app` bundles so local apps like Raycast appear while Mackup details still use `mackup show`; Storage and Preferences paths are GUI picker driven; created configs remain graphically editable via Dashboard/Storage; Link Mode shows explicit command guidance; sidebar rows use full-width buttons; layouts are denser with lightweight animations; Preferences reset deletes matching selected/default `.mackup.cfg` files.
Changed: `Applications/InstalledApplicationScanner.swift`, `Applications/MackupApplication.swift`, `Applications/MackupApplicationListParser.swift`, `Features/Applications/*`, `Features/Dashboard/DashboardView.swift`, `Features/LinkMode/LinkModeView.swift`, `Features/Preferences/*`, `Features/RootShellView.swift`, `Features/Storage/*`, `Resources/Localizable.xcstrings`, `YAMGTests/InstalledApplicationScannerTests.swift`, `YAMGTests/ApplicationsListViewModelTests.swift`, `YAMGTests/PreferencesViewModelTests.swift`, `YAMGTests/StorageViewModelTests.swift`, `README.md`, `YAMG_PRD.md`, `YAMG.xcodeproj/project.pbxproj`.
Tests: `jq empty Resources/Localizable.xcstrings`; `plutil -lint YAMG.xcodeproj/project.pbxproj`; `git diff --check`; targeted `xcodebuild test ...` for InstalledApplicationScanner, ApplicationsListViewModel, StorageViewModel, PreferencesViewModel, DashboardViewModel, LinkModeViewModel passed 31 tests; full `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests` passed 83 tests.
Next: open the app for hands-on UI smoke testing if needed.
Blocked: none.

2026-05-18 20:09 CST | Codex
Done: implemented P1 backup/restore flow on Dashboard with dry-run enabled by default, explicit confirmation before running, streamed output display, and `ProcessLogStore` recording; commands are limited to Mackup CLI `backup`/`restore` via `MackupCommandRunning`.
Changed: `Features/Operations/OperationFlowView.swift`, `Features/Operations/OperationFlowViewModel.swift`, `Features/Dashboard/DashboardView.swift`, `Resources/Localizable.xcstrings`, `YAMGTests/OperationFlowViewModelTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `jq empty Resources/Localizable.xcstrings`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: start P2 Homebrew/pipx install entry or preferences for CLI/config path.
Blocked: none.

2026-05-18 23:11 CST | Codex
Done: fixed follow-up UX issues: storage config remains graphically editable after creation, storage engines use friendly names, supported applications retry through an isolated Mackup CLI list environment when the user's storage config is unusable, storage path/directory use folder pickers, Link Mode includes command guidance, sidebar rows are full-width selectable, layouts are denser with lightweight animations, and Preferences reset deletes the selected/default .mackup.cfg.
Changed: Applications/MackupApplicationListParser.swift, Config/MackupConfig.swift, Features/Applications/ApplicationsListViewModel.swift, Features/Dashboard/DashboardView.swift, Features/LinkMode/LinkModeView.swift, Features/Preferences/PreferencesView.swift, Features/Preferences/PreferencesViewModel.swift, Features/RootShellView.swift, Features/Storage/StorageView.swift, Features/Storage/StorageViewModel.swift, MackupCLI/MackupProcessRunner.swift, Resources/Localizable.xcstrings, YAMGTests/ApplicationsListViewModelTests.swift, YAMGTests/MackupApplicationListParserTests.swift, YAMGTests/MackupProcessRunnerTests.swift, YAMGTests/PreferencesViewModelTests.swift, YAMGTests/StorageViewModelTests.swift, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: jq empty Resources/Localizable.xcstrings; git diff --check; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests.
Next: run the app and manually verify the first-run, Storage, Applications, Link Mode, sidebar, and Preferences reset flows.
Blocked: none.

2026-05-18 20:03 CST | Codex
Done: implemented P1 Storage editor UI for Mackup-supported `[storage] engine/path/directory` fields only, backed by `MackupConfigEditor`; no migration, sync, copy, delete, or link behavior added.
Changed: `Config/MackupConfig.swift`, `Features/Storage/StorageView.swift`, `Features/Storage/StorageViewModel.swift`, `Features/RootShellView.swift`, `Support/LocalizationKey.swift`, `Resources/Localizable.xcstrings`, `YAMGTests/StorageViewModelTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `jq empty Resources/Localizable.xcstrings`; `xcodebuild build -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS'`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/StorageViewModelTests`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: implement P1 Backup/restore/dry-run flow with confirmation.
Blocked: none.

2026-05-18 19:58 CST | Codex
Done: implemented P1 Application detail via `mackup show <application>` with CLI-output parser, detail view model, selected application detail pane, and tests for parser/view model behavior.
Changed: `Applications/MackupApplicationDetail.swift`, `Applications/MackupApplicationDetailParser.swift`, `Features/Applications/ApplicationDetailView.swift`, `Features/Applications/ApplicationDetailViewModel.swift`, `Features/Applications/ApplicationsListView.swift`, `Features/Applications/ApplicationsListViewModel.swift`, `MackupCLI/MackupDetectionStatusDescription.swift`, `Support/LocalizationKey.swift`, `Resources/Localizable.xcstrings`, `YAMGTests/ApplicationDetailViewModelTests.swift`, `YAMGTests/MackupApplicationDetailParserTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `jq empty Resources/Localizable.xcstrings`; `xcodebuild build -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS'`. Attempted `xcodebuild test ... -only-testing:YAMGTests` and narrower detail tests; both compiled but hung at XCTest host startup in this shell, so they were interrupted rather than reported as passing.
Next: implement P1 Storage editor UI.
Blocked: XCTest host startup hangs in current shell environment after app launch; build succeeds.

2026-05-18 19:46 CST | Codex
Done: implemented P1 Applications list using `mackup list` through `MackupCommandRunning`, with output parsing, loading/empty/error states, and Applications sidebar content.
Changed: `Applications/MackupApplication.swift`, `Applications/MackupApplicationListParser.swift`, `Features/Applications/ApplicationsListView.swift`, `Features/Applications/ApplicationsListViewModel.swift`, `Features/RootShellView.swift`, `Support/LocalizationKey.swift`, `Resources/Localizable.xcstrings`, `YAMGTests/ApplicationsListViewModelTests.swift`, `YAMGTests/MackupApplicationListParserTests.swift`, `YAMG.xcodeproj/project.pbxproj`, `Docs/AI/TASKS.md`, `Docs/AI/HANDOFF.md`.
Tests: `plutil -lint YAMG.xcodeproj/project.pbxproj`; `jq empty Resources/Localizable.xcstrings`; `xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests`.
Next: implement P1 Application detail via `mackup show <application>`.
Blocked: none.

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

2026-05-18 22:23 CST | Codex
Done: added P2 Homebrew/pipx install entry for missing Mackup CLI detection; Dashboard now shows copyable install commands without running package managers.
Changed: Features/Dashboard/MackupInstallGuide.swift, Features/Dashboard/DashboardView.swift, Features/Dashboard/DashboardViewModel.swift, Support/LocalizationKey.swift, Resources/Localizable.xcstrings, YAMGTests/DashboardViewModelTests.swift, YAMG.xcodeproj/project.pbxproj, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: plutil -lint YAMG.xcodeproj/project.pbxproj; jq empty Resources/Localizable.xcstrings; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/DashboardViewModelTests.
Next: implement P2 Preferences for CLI/config path.
Blocked: none.

2026-05-18 22:29 CST | Codex
Done: implemented Preferences for Mackup CLI/config paths using UserDefaults; wired preferred paths into Dashboard detection, Applications list/detail, Storage config editing, and backup/restore command config-file options without writing YAMG metadata to .mackup.cfg.
Changed: App/YAMGApp.swift, Support/AppPreferences.swift, Support/LocalizationKey.swift, Features/Preferences/PreferencesView.swift, Features/Preferences/PreferencesViewModel.swift, Features/RootShellView.swift, Features/Dashboard/DashboardView.swift, Features/Dashboard/DashboardViewModel.swift, Features/Applications/ApplicationsListView.swift, Features/Applications/ApplicationsListViewModel.swift, Features/Applications/ApplicationDetailView.swift, Features/Applications/ApplicationDetailViewModel.swift, Features/Storage/StorageView.swift, Features/Operations/OperationFlowView.swift, Resources/Localizable.xcstrings, YAMGTests/AppPreferencesTests.swift, YAMGTests/PreferencesViewModelTests.swift, YAMGTests/StorageViewModelTests.swift, YAMGTests/OperationFlowViewModelTests.swift, YAMG.xcodeproj/project.pbxproj, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: plutil -lint YAMG.xcodeproj/project.pbxproj; jq empty Resources/Localizable.xcstrings; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/AppPreferencesTests -only-testing:YAMGTests/PreferencesViewModelTests -only-testing:YAMGTests/StorageViewModelTests -only-testing:YAMGTests/OperationFlowViewModelTests.
Next: implement P2 Link Mode advanced page.
Blocked: none.

2026-05-18 22:34 CST | Codex
Done: implemented P2 Link Mode advanced page as a non-default sidebar entry with risk acknowledgement, confirmation flow, streamed output, logging, and allowed Mackup CLI link commands only.
Changed: Features/LinkMode/LinkModeView.swift, Features/LinkMode/LinkModeViewModel.swift, Features/AppSection.swift, Features/RootShellView.swift, Support/LocalizationKey.swift, Resources/Localizable.xcstrings, YAMGTests/LinkModeViewModelTests.swift, YAMGTests/AppSectionTests.swift, YAMG.xcodeproj/project.pbxproj, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: plutil -lint YAMG.xcodeproj/project.pbxproj; jq empty Resources/Localizable.xcstrings; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/LinkModeViewModelTests -only-testing:YAMGTests/AppSectionTests; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests.
Next: P2 complete; next work should pick the next priority added to TASKS.md.
Blocked: none.

2026-05-18 22:46 CST | Codex
Done: fixed sidebar click handling by using explicit selectable sidebar buttons; improved first-run Dashboard setup with single selected install method, one-click Homebrew/pipx installer execution, and guided creation of a minimal Mackup-supported .mackup.cfg.
Changed: Features/RootShellView.swift, Features/Dashboard/DashboardView.swift, Features/Dashboard/DashboardViewModel.swift, Features/Dashboard/MackupInstallGuide.swift, Support/CommandLineToolRunner.swift, Resources/Localizable.xcstrings, YAMGTests/DashboardViewModelTests.swift, YAMG.xcodeproj/project.pbxproj, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: plutil -lint YAMG.xcodeproj/project.pbxproj; jq empty Resources/Localizable.xcstrings; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/DashboardViewModelTests -only-testing:YAMGTests/AppSectionTests; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests.
Next: reopen Debug app for user testing; consider dedicated UI test coverage for first-run wizard when UI automation is stable.
Blocked: none.

2026-05-18 22:52 CST | Codex
Done: added Preferences development reset button that clears local CLI override and points config path to a guaranteed-missing development .mackup.cfg path, restoring first-run onboarding without deleting real Mackup config.
Changed: Support/AppPreferences.swift, Features/Preferences/PreferencesView.swift, Features/Preferences/PreferencesViewModel.swift, Resources/Localizable.xcstrings, YAMGTests/AppPreferencesTests.swift, YAMGTests/PreferencesViewModelTests.swift, Docs/AI/TASKS.md, Docs/AI/HANDOFF.md.
Tests: jq empty Resources/Localizable.xcstrings; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests/AppPreferencesTests -only-testing:YAMGTests/PreferencesViewModelTests; xcodebuild test -project YAMG.xcodeproj -scheme YAMG -destination 'platform=macOS' -only-testing:YAMGTests.
Next: user can use Preferences > Development reset > Reset to first-run state, then return to Dashboard and refresh.
Blocked: none.
