# YAMG

Yet Another Mackup GUI: a SwiftUI macOS GUI frontend for Mackup.

Version: `0.10.3`, matching the local upstream Mackup source version.

Core rule: YAMG does not implement sync logic. It detects, configures, and runs Mackup CLI only.

Current UX notes:

- Dashboard is the single setup surface: it shows Mackup CLI status, `.mackup.cfg` presence, and a storage editor that creates the file when missing and modifies it in place when present. The standalone Storage section has been removed.
- Storage provider buttons enable Dropbox, Google Drive, and iCloud only when Mackup's own detection rules find the folder; `file_system` is always available.
- Applications lists the intersection of installed macOS `.app` bundles and Mackup-supported application identifiers (from `mackup list`). Each row has a sync toggle that immediately writes `[applications_to_sync]` in `.mackup.cfg`.
- Matching uses the slug of the installed display name (e.g. `Sublime Text 3` → `sublime-text-3`) and falls back to the bundle slug; apps Mackup does not support are hidden.
- Preferences holds only CLI/config paths and the Link Mode visibility toggle. Reset clears those preferences and deletes the matching `.mackup.cfg` files. The development reset has been removed.
- Link Mode is hidden by default and can be enabled in Preferences. When visible it still shows the exact Mackup link commands and their side effects before confirmation.

Start points:

- PRD: `YAMG_PRD.md`
- AI handoff: `Docs/AI/STATE.md`
- Agent rules: `Docs/AI/AGENT_RULES.md`
- Task queue: `Docs/AI/TASKS.md`
- Technical scaffold: `Docs/Engineering/SCAFFOLD.md`
