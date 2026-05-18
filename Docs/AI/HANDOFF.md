# Handoff

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
