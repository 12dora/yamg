# YAMG

Yet Another Mackup GUI: a SwiftUI macOS GUI frontend for Mackup.

Version: `0.10.3`, matching the local upstream Mackup source version.

Core rule: YAMG does not implement sync logic. It detects, configures, and runs Mackup CLI only.

Current UX notes:

- Applications scans installed macOS `.app` bundles so local apps such as Raycast appear even when Mackup has no built-in definition for them.
- Dashboard and Storage require a provider plus a Mackup folder before creating or saving storage config. Dropbox, Google Drive, and iCloud are enabled only when the same detection rules Mackup uses find a local folder; `file_system` remains available for any chosen folder.
- Storage shows one Mackup folder picker in the UI, then writes Mackup-compatible `[storage] path` and `directory` fields as needed.
- Storage and Preferences use macOS file/folder pickers for paths; the `.mackup.cfg` file remains graphically editable after creation.
- Preferences reset clears saved paths and deletes matching selected/default `.mackup.cfg` files when they exist.
- Link Mode is hidden by default and can be enabled in Preferences. When visible, it shows the exact Mackup link commands and their side effects before confirmation.

Start points:

- PRD: `YAMG_PRD.md`
- AI handoff: `Docs/AI/STATE.md`
- Agent rules: `Docs/AI/AGENT_RULES.md`
- Task queue: `Docs/AI/TASKS.md`
- Technical scaffold: `Docs/Engineering/SCAFFOLD.md`
