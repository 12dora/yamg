# AI State

Keep this file short. Read first when resuming.

## Project

- Name: YAMG
- Version: `0.10.3`
- Version rule: match local upstream Mackup source version from `mackup/pyproject.toml`.
- Product: SwiftUI macOS GUI frontend for Mackup CLI.
- Boundary: do not exceed Mackup CLI/config capabilities.

## Current Repo State

- Git should track YAMG only.
- `mackup/` is local upstream reference source and is ignored by Git.
- PRD exists at `YAMG_PRD.md`.
- No full Swift implementation yet; scaffold docs/directories are being prepared.

## Important Upstream Facts

- CLI commands: `list`, `show <application>`, `backup`, `restore`, `link install`, `link`, `link uninstall`, `--version`.
- Config: `.mackup.cfg`; sections `[storage]`, `[applications_to_sync]`, `[applications_to_ignore]`.
- Storage engines: `dropbox`, `google_drive`, `icloud`, `file_system`.
- Prefer copy mode for MVP. Link mode is advanced/high risk, especially macOS 14+.

## Next Best Step

Create Xcode SwiftUI macOS project matching `Docs/Engineering/SCAFFOLD.md`, then implement P0 modules from `Docs/AI/TASKS.md`.

