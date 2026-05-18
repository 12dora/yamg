# Tasks

Status: `[ ]` todo, `[~]` doing, `[x]` done.

## P0

- [x] Init Git excluding `mackup/`.
- [x] Create low-token AI handoff docs.
- [x] Create reusable coding AI start prompt.
- [x] Set YAMG version to upstream local Mackup version `0.10.3`.
- [x] Create SwiftUI macOS Xcode project.
- [x] Add app shell: Sidebar, Dashboard, Applications, Storage, Logs, Preferences.
- [x] Implement `MackupCommand` and argv builder.
- [x] Implement `MackupProcessRunner` with streamed stdout/stderr.
- [x] Implement `MackupDetector` and version parser.
- [x] Implement `ProcessLogStore`.
- [x] Implement `.mackup.cfg` read/write.
- [x] Add `Localizable.xcstrings` zh-Hans/en baseline.

## P1

- [x] Onboarding MVP.
- [x] Applications list via `mackup list`.
- [x] Application detail via `mackup show`.
- [x] Storage editor.
- [x] Backup/restore/dry-run flow with confirmation.

## P2

- [x] Homebrew/pipx install entry.
- [x] Preferences for CLI/config path.
- [x] Link Mode advanced page.

## UX Fixes

- [x] Fix sidebar item selection/click handling.
- [x] Add first-run setup guide for installing Mackup.
- [x] Add one-click selected Mackup installer action.
- [x] Make Homebrew/pipx a single selected install method.
- [x] Add guided creation for missing `.mackup.cfg`.
- [x] Add development reset to simulate first-run state.
- [x] Keep graphical storage config editing after `.mackup.cfg` creation.
- [x] Show friendly storage provider names instead of raw Mackup config values.
- [x] Load supported applications even when user storage config breaks `mackup list`.
- [x] Add GUI folder pickers for storage path and directory fields.
- [x] Add Link Mode operation guide text.
- [x] Make sidebar rows selectable across their full width.
- [x] Tighten main UI spacing and add lightweight state animations.
- [x] Make Preferences reset delete the selected/default `.mackup.cfg`.
