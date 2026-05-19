# YAMG 项目代码质量审查报告

**项目:** YAMG (Yet Another Mackup GUI) — macOS SwiftUI 应用  
**版本:** 0.10.3  
**审查日期:** 2026-05-19  
**审查范围:** 全部 54 个 Swift 源文件 + 20 个测试文件

---

## 一、严重缺陷 (Critical)

### 1. `deselectAll()` 写入的配置与 UI 状态矛盾

**文件:** `Features/Applications/ApplicationsListViewModel.swift:142-167`

`deselectAll()` 向 `.mackup.cfg` 写入空的 `applicationsToSync` 列表，但 mackup 的实际行为是：空列表 = 同步所有应用。UI 显示"未选中任何应用"，而 mackup 实际会同步全部应用。`selectAll()` 也写入空列表，意味着两个语义相反的操作写入了相同的配置。

**影响:** 用户以为取消了所有同步，实际上 mackup 会同步全部应用，可能导致数据意外覆盖。

---

### 2. 定时备份 Launch Agent 硬编码了 mackup 路径

**文件:** `Features/Dashboard/DashboardView.swift:640`

`createLaunchAgentPlist` 硬编码 `/opt/homebrew/bin/mackup`。Intel Mac 上 Homebrew 路径为 `/usr/local/bin`，pipx 安装路径也不同。应用已有 `preferredCLIPath` 机制但未在此处使用。

**影响:** 非 Apple Silicon + Homebrew 环境下，定时备份静默失败，用户无感知。

---

## 二、高严重度缺陷 (High)

### 3. `ProcessLogStore` TOCTOU 竞态条件

**文件:** `Logging/ProcessLogStore.swift:91-105`

`finish()` 和 `fail()` 方法在锁内读取记录、解锁、修改本地副本、再加锁写回。两次加锁之间其他线程可修改同一记录，导致更新丢失。

**影响:** 并发调用时日志状态可能被覆盖。

---

### 4. `ProcessLogStore` 在非主线程修改 `@Published` 属性

**文件:** `Logging/ProcessLogStore.swift:35-36`

`runRecords` 是 `@Published`，但在任意线程的 `lock.withLock` 块中修改。SwiftUI 要求 `objectWillChange` 在主线程发送。

**影响:** macOS 14+ 上可能产生运行时警告或 UI 更新丢失。

---

### 5. `OperationFlowViewModel.request()` 存在双击竞态

**文件:** `Features/Operations/OperationFlowViewModel.swift:45-53`

`!isRunning` 检查与 `Task { await run() }` 之间不是原子操作。快速双击可绕过 guard，启动两个并发操作。Task 引用未保存，无法取消。

**影响:** 可能同时执行两次 backup/restore，导致数据损坏。

---

### 6. Launch Agent 安装未先卸载旧 Agent

**文件:** `Features/Dashboard/DashboardView.swift:596-616`

修改备份间隔后直接 `launchctl load`，但已加载的 agent 不会被更新。需先 `unload` 再 `load`。

**影响:** 用户修改备份间隔后，旧间隔继续生效。

---

### 7. `MackupProcessRunner` 流事件顺序不可靠

**文件:** `MackupCLI/MackupProcessRunner.swift:66-106`

`readabilityHandler` 异步派发到 `queue`，`terminationHandler` 也派发到同一队列，但 `readabilityHandler = nil` 在终止线程执行。已入队但未执行的输出回调可能在 `.finished` 事件之后到达。

**影响:** 消费者可能在收到完成事件后仍收到输出事件，导致日志截断或状态混乱。

---

### 8. `LogsContentView` 的 `logDetail` 计算属性从未使用

**文件:** `Features/Logs/LogsView.swift:82-108`

定义了 `logDetail` 但 `body` 中从未引用。用户可以看到运行列表，但无法查看任何运行的实际日志输出。

**影响:** 日志详情功能不可用，属于未完成的功能。

---

## 三、中等严重度缺陷 (Medium)

### 9. 日志无上限增长

**文件:** `Logging/ProcessLogStore.swift`

`runRecords`、`runOrder`、`logEntriesByRunID` 无淘汰策略。长时间运行的应用会持续消耗内存。

---

### 10. `PreferencesViewModel.reset()` 无确认即删除配置文件

**文件:** `Features/Preferences/PreferencesViewModel.swift:55-77`

直接删除最多 3 个配置文件路径，无二次确认对话框。用户精心配置的 `.mackup.cfg` 可能被误删且无法恢复。

---

### 11. `MackupConfigRenderer` 为空列表生成多余的 section header

**文件:** `Config/MackupConfig.swift:202-204`

当 `applicationsToSync` 和 `applicationsToIgnore` 为空数组时，仍会写入 `[applications_to_sync]` 等空 section，修改了用户原始配置文件。

---

### 12. `onChange(of:)` 使用已废弃的单参数形式

**文件:** `Features/Applications/ApplicationsListView.swift:113`, `Features/Preferences/PreferencesView.swift:76`

使用了 macOS 13 废弃的 `onChange(of:) { newValue in }` 形式，应迁移到双参数版本。

---

### 13. `CommandLineToolRunner` 中 `readDataToEndOfFile()` 可能阻塞

**文件:** `Support/CommandLineToolRunner.swift:88-89`

在 `terminationHandler` 中调用阻塞式 `readDataToEndOfFile()`，若进程异常终止未关闭文件描述符，可能永久挂起。

---

### 14. `canSaveConfig` 对非 fileSystem 引擎的禁用逻辑不透明

**文件:** `Features/Dashboard/DashboardViewModel.swift:98-112`

当 `automaticStorageDirectory()` 返回 nil 时，保存按钮被禁用但无任何提示告知用户原因。

---

## 四、低严重度缺陷 (Low)

| # | 问题 | 文件 |
|---|------|------|
| 15 | `AppSection.title`/`subtitle` 属性为死代码 | `Features/AppSection.swift:12-25` |
| 16 | `LogsView` 强制向下转型 `ProcessLogStore` 破坏协议抽象 | `Features/Logs/LogsView.swift:12-13` |
| 17 | `MackupDetector` 找到第一个可执行文件即停止，不尝试后续候选 | `MackupCLI/MackupDetector.swift:100-106` |
| 18 | `MackupApplication.identifier(from:)` 对纯 CJK 名称返回空字符串 | `Applications/MackupApplication.swift:14-26` |
| 19 | `MackupApplicationListParser` 使用 locale 敏感的字符串比较解析 CLI 输出 | `Applications/MackupApplicationListParser.swift:25-27` |
| 20 | `RootShellView` 对自有对象使用 `@ObservedObject` 而非 `@StateObject` | `Features/RootShellView.swift:4` |
| 21 | 定时备份 Stepper 每次点击触发 `launchctl` 调用，可能卡顿 | `Features/Dashboard/DashboardView.swift:708-715` |

---

## 五、测试覆盖缺口

| 缺口 | 风险 |
|------|------|
| `MackupSupportedApplicationCatalog` 零测试覆盖（含重试逻辑和隔离 runner 工厂） | 高 |
| `CommandLineToolRunner` 无单元测试 | 中 |
| `ProcessLogStore.fail()` 未测试 | 中 |
| `LinkModeViewModel` 错误路径和运行中 guard 未测试 | 高（破坏性操作） |
| `ApplicationsListViewModel` scanner 失败路径未测试 | 中 |
| `AppPreferences.preferredLanguage` 持久化未测试 | 低 |
| `OperationFlowViewModel.verbose` 标志未测试 | 低 |
| UI 测试仅验证启动，无交互测试 | 中 |

---

## 六、建议优先修复顺序

1. **Critical #1** — `deselectAll()` 配置语义错误，直接影响数据安全
2. **Critical #2** — Launch Agent 路径硬编码，影响非标准环境用户
3. **High #5** — 双击竞态可导致并发操作
4. **High #3 & #4** — ProcessLogStore 线程安全问题
5. **High #6** — Launch Agent 更新失效
6. **Medium #10** — 无确认删除配置文件
