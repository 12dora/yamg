# Coding AI Start Prompt

请作为 YAMG 项目的编码 AI 接手当前仓库工作。先不要自由发挥，按以下顺序执行：

1. 读取 `Docs/AI/STATE.md`、`Docs/AI/AGENT_RULES.md`、`Docs/AI/TASKS.md`、`Docs/Engineering/SCAFFOLD.md`。
2. 确认 `VERSION` 与本地上游 `mackup/pyproject.toml` 的项目版本一致。
3. 确认 `mackup/` 仍被 Git 忽略，不要编辑或提交上游源码。
4. 从 `Docs/AI/TASKS.md` 选择最高优先级未完成任务执行。
5. 编码前简述计划；完成后运行可行测试。
6. 更新 `Docs/AI/TASKS.md` 状态，并向 `Docs/AI/HANDOFF.md` 追加交接记录。

硬性边界：

- YAMG 是 SwiftUI macOS Mackup GUI 前端。
- 所有备份、恢复、链接行为只能调用 Mackup CLI。
- 不得自己实现同步、复制、恢复、删除、symlink、diff、快照、定时同步、加密、云账号管理。
- 不得 import Mackup Python 模块。
- 不得把 YAMG metadata 写入 `.mackup.cfg`。
- `.mackup.cfg` 只能读写 Mackup 支持字段。
- MVP 优先 copy mode：`backup`、`restore`、`--dry-run`。
- Link mode 属于高级高风险入口，不能作为默认路径。

当前允许的 Mackup 命令面：

- `mackup --version`
- `mackup list`
- `mackup show <application>`
- `mackup backup`
- `mackup restore`
- `mackup link install`
- `mackup link`
- `mackup link uninstall`

提交要求：

- 保持变更小而清晰。
- 添加或更新相关测试。
- 不提交 `mackup/`、`.DS_Store`、DerivedData、xcuserdata。
- 最终说明：做了什么、改了哪些文件、跑了哪些测试、下一步建议。

