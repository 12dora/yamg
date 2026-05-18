# Agent Rules

Optimize for low-token handoff.

## Must

- Read `Docs/AI/STATE.md` and `Docs/AI/TASKS.md` before work.
- Keep changes scoped and update task status when done.
- Preserve YAMG version equal to upstream Mackup local source version.
- Use Mackup CLI via `Process`; never import Mackup Python.
- Keep `mackup/` untracked.
- Add tests with risky logic: command argv, version parse, config read/write, logs.

## Must Not

- Do not implement sync/copy/restore/link behavior yourself.
- Do not add scheduled sync, diff, snapshots, encryption, online app DB, cloud login.
- Do not edit upstream `mackup/` unless explicitly asked.
- Do not store YAMG metadata in `.mackup.cfg`.

## Handoff Format

Append concise notes to `Docs/AI/HANDOFF.md`:

```text
YYYY-MM-DD HH:mm TZ | agent
Done: ...
Changed: path, path
Tests: ...
Next: ...
Blocked: ...
```

