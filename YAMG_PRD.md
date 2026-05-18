# Yet Another Mackup GUI 产品需求文档（PRD）

## 第一步：源码勘察结果

本次勘察基于本地 `mackup/` 源码目录，并对当前公开稳定版本做了外部核对：本地源码 `mackup/pyproject.toml:1`-`9` 标注版本为 `0.10.3`、Python 要求为 `>=3.9`，但 PyPI 与 Homebrew Formulae 在 2026-05-18 可见的稳定版为 `0.10.2`。YAMG 的最低兼容目标建议设为 `0.10.2`，同时兼容源码中的 `0.10.3` 输出格式。

Mackup 当前 CLI 入口由 `pyproject.toml` 的 `[project.scripts] mackup = "mackup.main:main"` 暴露（`mackup/pyproject.toml:35`-`36`），命令定义集中在 docopt 文档字符串中（`mackup/src/mackup/main.py:6`-`24`）。真实子命令为：`list`、`show <application>`、`backup`、`restore`、`link install`、`link`、`link uninstall`；没有独立 `mackup uninstall` 子命令，文档中 `mackup uninstall` 的说法应在 YAMG 中修正为 `mackup link uninstall`。全局参数包括 `--force`、`--force-no`、`--root`、`--dry-run`、`--verbose`、`--config-file=<path>`、`--version`。

Mackup 有两种执行模式：copy mode 由 `backup` 与 `restore` 完成，实际是文件/目录复制；link mode 由 `link install`、`link`、`link uninstall` 完成，使用符号链接。源码中的复制、删除、链接分别由 `utils.copy`、`utils.delete`、`utils.link` 实现（`mackup/src/mackup/utils.py:54`-`150`）。`backup` 会把本地配置复制到 Mackup 文件夹；`restore` 会把 Mackup 文件夹中的配置复制回本地；`link install` 会复制到 Mackup 文件夹、删除本地原文件、再创建 symlink；`link` 会从 Mackup 文件夹创建本地 symlink；`link uninstall` 会删除由 Mackup 管理的 symlink 并复制文件回家目录（`mackup/src/mackup/application.py:50`-`395`）。冲突处理依赖交互确认，`--force` 全部回答 Yes，`--force-no` 全部回答 No（`mackup/src/mackup/utils.py:26`-`51`）。

`.mackup.cfg` 的查找顺序为：显式 `--config-file`、默认 `~/.mackup.cfg`、`$MACKUP_CONFIG`、`$XDG_CONFIG_HOME/mackup/mackup.cfg` 或 `~/.config/mackup/mackup.cfg`，其中实际默认路径优先于环境变量（`mackup/src/mackup/config.py:150`-`212`，`mackup/doc/README.md:18`-`35`）。配置 section 包括 `[storage]`、`[applications_to_sync]`、`[applications_to_ignore]`。应用定义 CFG 包括 `[application]`、`[configuration_files]`、`[xdg_configuration_files]`（`mackup/src/mackup/appsdb.py:40`-`72`）。存储后端仅支持 `dropbox`、`google_drive`、`icloud`、`file_system` 四类（`mackup/src/mackup/constants.py:39`-`43`）。默认 engine 为 `dropbox`，默认目录名为 `Mackup`（`mackup/src/mackup/config.py:234`-`305`）。

应用支持库来自 `mackup/src/mackup/applications/`，本地源码中共有 607 个 `.cfg` 文件。Mackup 还支持用户自定义应用 CFG：旧位置 `~/.mackup/` 优先于 XDG 位置 `$XDG_CONFIG_HOME/mackup/applications/` 或 `~/.config/mackup/applications/`，自定义同名 CFG 会覆盖内置 CFG（`mackup/src/mackup/appsdb.py:74`-`132`，`mackup/doc/README.md:202`-`284`）。因此 YAMG 可以提供自定义应用 CFG 编辑器，但必须写入 Mackup 已支持的位置与格式，不得维护独立应用库。

主要危险点：`restore`、`backup`、`link install`、`link` 在冲突时可能删除并替换目标文件；`link install` 会删除本地原文件并改为 symlink；`link uninstall` 只处理指向 Mackup 文件夹的 symlink，非 Mackup symlink 或普通文件会跳过并警告（`mackup/src/mackup/application.py:348`-`395`）。Mackup 默认禁止 root 运行，除非用户传入 `--root`（`mackup/src/mackup/mackup.py:28`-`37`）。在 macOS 14 Sonoma 及以后，Mackup README 明确警告 link mode 会破坏偏好设置，应优先使用 copy mode（`mackup/README.md:131`-`139`）。

## 1. 产品概述

| 项目 | 内容 | 理由 |
|---|---|---|
| 产品全称 | Yet Another Mackup GUI | 明确它是 Mackup 的 GUI 前端，而不是上游替代品 |
| 缩写 | YAMG | 简短，便于菜单栏、日志、仓库命名 |
| 产品性质 | 公益开源软件，免费、无广告、无内购、源代码公开 | 与 Mackup 的开源工具属性一致，避免商业化诉求推动功能蔓延 |
| 一句话定位（10 字内） | Mackup 图形前端 | 准确表达边界 |
| 一句话定位（30 字内） | 给不会用终端的 Mac 用户使用 Mackup | 直接对应目标用户痛点 |
| 推荐协议 | GPL-3.0-or-later 优先，MIT 可作为备选 | Mackup 自身为 GPL-3.0-or-later（`mackup/pyproject.toml:13`），若 YAMG 深度复用其配置与文档语义，GPL 更能保持社区一致；MIT 更宽松但与上游 copyleft 气质较弱 |

### 目标用户

| 用户类型 | 典型画像 | 核心需求 | YAMG 设计重点 |
|---|---|---|---|
| 非技术用户 | 会安装 Mac App，但不熟悉 Terminal、PATH、Python | 备份与恢复应用配置，不想理解命令行 | 向导、清晰风险提示、一键安装 Mackup |
| 技术用户 | 使用 dotfiles、Homebrew、iCloud/Dropbox，但希望减少重复命令 | 快速查看支持应用、编辑 `.mackup.cfg`、执行备份/恢复 | 透明展示实际命令、保留日志与高级配置 |
| IT 管理员 | 负责多台 Mac 的迁移或重装流程 | 可控、可解释、可审计的配置迁移 | 明确命令映射、可复制日志、可指定 mackup 路径与配置文件 |

### 核心价值主张

YAMG 让不会用终端的 Mac 用户也能使用 Mackup 的能力：检测环境、生成 `.mackup.cfg`、调用 Mackup CLI、展示 stdout/stderr、解释错误与退出码。所有同步、备份、恢复、链接、卸载链接行为都由 Mackup CLI 完成。

### 非目标

YAMG 不做增量同步、定时任务、版本快照、文件 diff、加密、团队共享、在线应用库更新、云端账号管理，不替代 Mackup，不脱离 Mackup 单独工作，不修改上游 Mackup 源码，不商业化。

## 2. 原软件能力梳理

### CLI 命令到 GUI 入口映射

| CLI 命令 | 源码依据 | 语义 | 主要参数 | 副作用 | GUI 入口 | 退出处理 |
|---|---|---|---|---|---|---|
| `mackup list` | `mackup/src/mackup/main.py:111`-`123` | 输出支持应用 slug 列表与版本 | `--verbose` 无实质增强 | 无文件写入，但会检查存储路径 | Applications 页面“刷新应用列表” | 0 显示列表，非 0 显示 stderr |
| `mackup show <application>` | `mackup/src/mackup/main.py:125`-`137` | 输出单个应用名称与配置文件 | `<application>` 必填 | 无文件写入 | 应用详情页“查看 Mackup 定义” | 不支持应用时退出并提示 |
| `mackup backup` | `mackup/src/mackup/main.py:138`-`149` | 从家目录复制配置到 Mackup 文件夹 | `--force`、`--force-no`、`--dry-run`、`--verbose`、`--config-file` | 可创建 Mackup 文件夹，可覆盖备份目录文件 | Dashboard“立即备份”、向导首次备份 | 冲突时使用 Sheet 转换为确认，最终由 CLI 执行 |
| `mackup restore` | `mackup/src/mackup/main.py:150`-`158` | 从 Mackup 文件夹复制配置回家目录 | 同上 | 可覆盖本地文件 | Dashboard“恢复到本机”、新 Mac 恢复流程 | 高风险确认，日志可复制 |
| `mackup link install` | `mackup/src/mackup/main.py:160`-`169` | 复制到 Mackup 文件夹、删除本地原文件、创建 symlink | 同上 | 删除本地原文件并建立符号链接 | Advanced/Link Mode 页面 | macOS 14+ 默认隐藏并强警告 |
| `mackup link` | `mackup/src/mackup/main.py:217`-`243` | 从 Mackup 文件夹创建本地 symlink | 同上 | 可删除本地目标再建 symlink | Advanced/Link Mode 页面 | macOS 14+ 强警告 |
| `mackup link uninstall` | `mackup/src/mackup/main.py:171`-`215` | 删除 Mackup 管理的 symlink 并复制文件回本地 | 同上 | 替换 symlink 为普通文件/目录 | “解除 Mackup 链接”流程 | 不是卸载 YAMG；不删除 Mackup 文件夹 |
| `mackup --version` | `mackup/src/mackup/main.py:81` | 输出 `Mackup <VERSION>` | 无 | 无 | 环境检测 | 解析版本号 |
| `mackup -h` | `mackup/src/mackup/main.py:6`-`24` | 输出帮助 | 无 | 无 | 帮助菜单“查看 Mackup CLI 帮助” | 只读展示 |

全局选项映射：`--force` 对应“自动确认覆盖”；`--force-no` 对应“遇到覆盖全部跳过”；`--dry-run` 对应“试运行”；`--verbose` 对应“详细日志”；`--config-file=<path>` 对应“高级：使用指定配置文件”；`--root` 仅在高级故障排除中暴露，默认禁止。

### 配置项到 GUI 控件映射

| 配置位置 | 字段 | 默认值 | 合法值 | 生效规则 | GUI 控件 |
|---|---|---|---|---|---|
| 配置文件路径 | `--config-file` | 自动查找 | 家目录内绝对或相对路径 | 显式指定优先；不存在则报错 | 高级设置“配置文件路径”选择器 |
| `[storage]` | `engine` | `dropbox` | `dropbox`、`google_drive`、`icloud`、`file_system` | 控制路径检测逻辑；Dropbox、Google Drive、iCloud 仅在 Mackup 兼容检测成功时可选 | Storage provider 按钮组 |
| `[storage]` | `path` | 无 | 绝对路径或相对家目录路径 | `file_system` 必填；Dropbox、Google Drive、iCloud 由 Mackup 自动检测，不写 `path` | GUI 中合并为 “Mackup folder” 文件夹选择器 |
| `[storage]` | `directory` | `Mackup` | 目录名或子路径；不能为 `.mackup` 或 XDG 自定义应用目录 | 拼接到 storage path 之后；选择默认 `<provider>/Mackup` 时可省略 | GUI 中合并为 “Mackup folder” 文件夹选择器 |
| `[applications_to_sync]` | 每行一个 app slug | 空集合 | `mackup list` 中的 slug，可包含自定义 app | 非空时只同步该集合，再扣除 ignore | Applications 勾选“仅同步选中应用” |
| `[applications_to_ignore]` | 每行一个 app slug | 空集合 | `mackup list` 中的 slug，可包含自定义 app | 从候选集合中移除，优先级高于 sync | Applications 勾选“排除应用” |
| 自定义应用 CFG `[application]` | `name` | 无 | 显示名 | `appsdb.py` 读取后用于 `show` | Custom Apps 名称字段 |
| 自定义应用 CFG `[configuration_files]` | 无值 key | 空 | 相对 `$HOME` 的文件/目录，不允许绝对路径 | 加入应用同步文件集合 | 路径列表编辑器 |
| 自定义应用 CFG `[xdg_configuration_files]` | 无值 key | 空 | 相对 `$XDG_CONFIG_HOME` 的路径，不允许绝对路径 | 展开为 `$XDG_CONFIG_HOME/<path>` 再转相对 home | XDG 路径列表编辑器 |

### 存储后端到 GUI 选项映射

| 后端 | 配置值 | 路径识别 | 源码依据 | GUI 表现 |
|---|---|---|---|---|
| Dropbox | `dropbox` | 读取 `~/.dropbox/host.db`，base64 解码第二字段 | `mackup/src/mackup/utils.py:201`-`225` | 自动检测，显示实际 Dropbox 路径 |
| Google Drive | `google_drive` | 读取 Google Drive `sync_config.db` 中 `local_sync_root_path` | `mackup/src/mackup/utils.py:228`-`274` | 自动检测，失败时提示新版本 Google Drive 可能路径不可读 |
| iCloud Drive | `icloud` | 固定检测 `~/Library/Mobile Documents/com~apple~CloudDocs/` | `mackup/src/mackup/utils.py:276`-`290` | 自动检测 iCloud Drive 是否可用 |
| File System | `file_system` | 使用 `[storage] path` | `mackup/src/mackup/config.py:271`-`279` | 文件夹选择器，适合 OneDrive、Syncthing、Git 工作树等任意同步文件夹 |

## 3. mackup CLI 检测与一键安装

### 检测时机

| 时机 | 触发原因 | 行为 |
|---|---|---|
| 应用启动 | mackup 是唯一执行引擎 | 后台检测，不阻塞窗口显示；状态展示在 Dashboard |
| 首次向导环境检测页进入时 | 未完成检测不能继续 | 阻塞“下一步”直到通过或安装完成 |
| 每次执行命令前 | 路径、版本、权限可能变化 | 快速复检二进制存在与版本 |
| 用户点击“重新检测” | 用户可能刚手动安装 | 重新扫描 PATH 与常见路径 |
| 用户修改 mackup 路径后 | 确认高级配置有效 | 运行 `--version` 并保存 |

### 检测内容

1. 可执行文件是否存在：优先用户手动指定路径，其次 `which mackup`，再扫描 `/opt/homebrew/bin/mackup`、`/usr/local/bin/mackup`、`~/.local/bin/mackup`、`~/Library/Python/*/bin/mackup`、虚拟环境候选路径。
2. 实际路径与是否在 PATH：PATH 中可直接调用；不在 PATH 时使用绝对路径。
3. 版本号：运行 `<mackup> --version`，解析 `Mackup 0.10.2` 或 `Mackup 0.10.3`。
4. 安装来源推断：`brew list mackup`、`pipx list`、可执行文件路径与 shebang。
5. Python：运行 `python3 --version`，最低要求 `>=3.9`，因为本地源码 `mackup/pyproject.toml:9` 指定 `requires-python = ">= 3.9"`。
6. 配置文件可读性：按 Mackup 查找顺序检查 `~/.mackup.cfg`、`$MACKUP_CONFIG`、XDG 配置。
7. 完整磁盘访问权限：尝试读取典型受保护路径的可用性，失败时引导用户授予权限。

### 检测状态

| 状态 | 条件 | UI 表现 | 主操作 |
|---|---|---|---|
| 已安装且版本满足要求 | 找到 mackup，版本 `>=0.10.2` | 绿色状态点，显示路径、版本、来源 | 继续 |
| 已安装但版本过低 | 版本 `<0.10.2` | 黄色警告，解释可能缺少 copy mode 或配置查找能力 | 一键升级 |
| 已安装但不在 PATH | 绝对路径可用，`which` 不可见 | 黄色提示，显示“YAMG 将使用绝对路径调用” | 确认路径或手动选择 |
| 未安装 | 扫描失败 | 红色空状态，进入安装方案选择 | Homebrew 安装或 pipx 安装 |

中英示例：

| Key | 中文 | English |
|---|---|---|
| `cli.status.ready` | 已找到 Mackup %@，路径：%@ | Mackup %@ found at %@. |
| `cli.status.outdated` | 当前 Mackup 版本过低，需要升级后继续。 | This Mackup version is too old. Upgrade before continuing. |
| `cli.status.notInPath` | Mackup 可用，但不在 PATH 中。YAMG 将使用绝对路径调用。 | Mackup works, but it is not in PATH. YAMG will call it by absolute path. |
| `cli.status.missing` | 未找到 Mackup。请在 YAMG 内安装，或手动指定路径。 | Mackup was not found. Install it in YAMG or choose a binary manually. |

### 安装界面

安装界面使用两张安装方案卡片：

| 方案 | 条件 | 优点 | 限制 | 命令 |
|---|---|---|---|---|
| Homebrew（推荐） | 已安装 `/opt/homebrew/bin/brew` 或 `/usr/local/bin/brew` | macOS 用户常见，升级卸载简单，Homebrew 当前稳定版为 0.10.2 | 未安装 Homebrew 时不代替用户安装，避免执行远程 shell | `brew install mackup` / `brew upgrade mackup` |
| pipx | Python 3.9+ 可用 | 与 Python CLI 工具隔离，适合不使用 Homebrew 的用户 | 需要先有 Python 与 pipx | `python3 -m pip install --user pipx`，`pipx install mackup` |

安装过程展示：

| 进度状态 | 中文 | English |
|---|---|---|
| `install.checkingBrew` | 正在检测 Homebrew... | Checking Homebrew... |
| `install.running` | 正在安装 Mackup... | Installing Mackup... |
| `install.upgrading` | 正在升级 Mackup... | Upgrading Mackup... |
| `install.verifying` | 正在验证安装结果... | Verifying installation... |
| `install.cancelled` | 安装已取消。 | Installation cancelled. |
| `install.failed` | 安装失败。请查看日志，或复制命令手动执行。 | Installation failed. Review the log or copy the command to run manually. |

日志区域实时流式显示 stdout/stderr，默认折叠详细日志，失败时自动展开。取消按钮向子进程发送 `terminate()`，若超时则提示用户可能仍有 Homebrew 子进程运行，提供“打开 Activity Monitor”与“复制诊断日志”。

### 架构与权限

Apple Silicon 默认 Homebrew 路径为 `/opt/homebrew/bin/brew`，Intel 默认路径为 `/usr/local/bin/brew`。YAMG 不应静默安装 Homebrew；如果缺失，显示官方 Homebrew 链接与可复制命令。绝大多数 Mackup 操作不需要 sudo，且 Mackup 默认禁止 root 运行（`mackup/src/mackup/mackup.py:28`-`37`），因此 YAMG 不提供常规管理员授权。只有用户选择通过系统包管理器执行需要权限的外部安装时，才考虑用 `osascript -e 'do shell script ... with administrator privileges'`；首版应避免 SMJobBless，降低复杂度。

完整磁盘访问权限是核心前置条件。YAMG 需要读写家目录、`~/Library`、dotfiles、云盘目录。环境检测页提供“打开系统设置”按钮，跳转到“系统设置 → 隐私与安全性 → 完整磁盘访问权限”，提示用户添加 YAMG。

## 4. 信息架构与导航

YAMG 采用 macOS 原生 Sidebar + Detail View。理由：任务入口固定、状态密集、符合系统设置类工具心智。

| 一级导航 | 主要内容 | 对应 Mackup 能力 |
|---|---|---|
| Dashboard | 环境状态、当前存储、上次 YAMG 执行记录、快捷备份/恢复 | `backup`、`restore`、`--version` |
| Applications | 本机已安装应用列表、搜索、筛选；Mackup 可识别时展示详情 | `.app` 扫描、`show <application>` |
| Application Detail | Mackup CFG 路径只读展示；未被 Mackup 支持时显示 CLI 错误 | `show <application>` |
| Storage | 后端检测与一个 Mackup folder 选择器，保存时写入 Mackup 的 `engine/path/directory` | `[storage]` |
| Custom Apps | 自定义 CFG 编辑器 | Mackup 支持的 `~/.mackup/*.cfg` 与 XDG 自定义目录 |
| Link Mode | 默认隐藏；在 Preferences 开启后显示 link install/link/link uninstall | `link install`、`link`、`link uninstall` |
| Logs | 最近命令输出 | stdout/stderr 记录 |
| Preferences | 语言、菜单栏图标、CLI 路径、配置文件路径、Link Mode 显示开关 | YAMG 元数据 + Mackup 直通配置 |

菜单栏提供 File、Edit、View、Run、Window、Help。Run 菜单只包含 CLI 已有动作：Backup、Restore、Dry Run Backup、Dry Run Restore、Link Install、Link、Link Uninstall。Menu Bar Extra 建议提供，功能限制为显示 Mackup 状态、上次 YAMG 命令时间、打开主窗口、触发 Backup/Restore；不做定时或后台自动同步。

## 5. 首次启动向导

向导使用大窗口分步流程，左侧为步骤列表，右侧为当前表单。所有按钮使用本地化字符串，默认“上一步 / 下一步 / 退出向导”。

### 5.1 欢迎页

布局：顶部应用图标与名称，中部一句定位，底部“开始”按钮与“仅打开主界面”。  
中文文案：欢迎使用 Yet Another Mackup GUI。YAMG 是 Mackup 的图形前端，开源免费。  
English: Welcome to Yet Another Mackup GUI. YAMG is a free and open-source GUI frontend for Mackup.  
错误状态：无。跳过行为：允许进入主界面，但 Dashboard 显示“尚未完成设置”。

### 5.2 环境检测

布局：检测结果卡片、安装方案卡片、完整磁盘访问提示、实时日志。若 Mackup 未安装或版本过低，必须安装/升级后继续。  
按钮：重新检测、安装 Mackup、选择 Mackup 路径、打开系统设置、复制命令。  
错误状态：Homebrew 未找到、Python 版本低、pipx 安装失败、`mackup --version` 无法解析。  
最终不调用同步命令，只调用 `--version` 与安装/升级命令。

### 5.3 同步模式选择

| 模式 | 中文 | English | 后续命令 |
|---|---|---|---|
| 首次设置 | 将本机配置备份到存储位置 | Back up this Mac to storage | `mackup backup` |
| 从已有备份恢复 | 将存储位置中的配置恢复到本机 | Restore storage backup to this Mac | `mackup restore` |
| 仅查看 | 先查看支持应用与配置，不执行操作 | Browse without running commands | 无 |

由于 Mackup copy mode 是当前推荐路径，macOS 14+ 不在向导中推荐 link mode。

### 5.4 存储位置选择

列表展示 Dropbox、Google Drive、iCloud Drive、File System 四项。Dropbox、Google Drive、iCloud Drive 复用 Mackup 的检测规则，检测到本地路径时才可点击，未检测到时置灰并显示原因；File System 始终可选。用户必须选择 provider 与 Mackup folder 后才能创建 `.mackup.cfg`。GUI 只显示一个 Mackup folder，保存时按 Mackup 规范拆写 `file_system` 的 `path` 与 `directory`，自动 provider 默认不写 `path`。这一步只写 `.mackup.cfg`，不复制用户数据。

中文错误：未找到 iCloud Drive 文件夹。请确认 iCloud Drive 已启用。  
English: iCloud Drive was not found. Make sure iCloud Drive is enabled.

### 5.5 应用选择

应用选择应优先让用户看到本机确实安装的应用，来源为标准 Applications 目录中的 `.app` 包；Mackup 详情仍通过 `mackup show <slug>` 获取，未被 Mackup 支持的应用显示 CLI 错误而不伪装为可同步项。过滤器只影响展示，不改变 Mackup 能力。每项可展开展示 `mackup show <slug>` 输出的文件路径。
保存时写入 `[applications_to_sync]` 或 `[applications_to_ignore]`。若用户不做选择，默认遵循 Mackup：同步所有支持应用减去 ignore 集合。

### 5.6 冲突预检

Mackup 没有独立冲突预检命令。YAMG 只能提供轻量文件系统状态展示：列出即将处理的路径中本地与备份目录同时存在的项，并明确“最终覆盖行为由 Mackup CLI 的确认逻辑执行”。不展示 diff，不做复杂判断。可提供 `--dry-run` 试运行按钮，调用 `mackup --dry-run backup` 或 `mackup --dry-run restore`。

### 5.7 首次同步执行

布局：当前命令、进度文本、日志流、取消按钮、详细日志开关。  
首次备份调用 `mackup backup`，恢复调用 `mackup restore`。用户选择“自动确认覆盖”时附加 `--force`；选择“遇到覆盖跳过”时附加 `--force-no`。  
取消后提示：命令已停止。请查看日志确认哪些文件已经处理。Mackup 不提供事务回滚。

### 5.8 完成页

展示执行结果、退出码、处理过的日志摘要、当前存储后端、下一步建议。统计只来自 YAMG 对日志行的计数与执行记录，不假装 Mackup 提供持久状态。  
中文：完成。你可以在另一台 Mac 上安装 YAMG 或 Mackup，并选择“从已有备份恢复”。  
English: Done. On another Mac, install YAMG or Mackup and choose “Restore from existing backup”.

## 6. 主界面功能详述

### Dashboard

Dashboard 显示 Mackup 状态、当前存储后端、Mackup 文件夹路径、上次 YAMG 成功执行时间、最近一次命令与退出码。上次执行时间属于 YAMG 元数据，存于 `~/Library/Application Support/YAMG/RunHistory.json`，不写入 Mackup 配置。

快捷操作：立即备份、恢复到本机、试运行备份、试运行恢复。所有按钮在执行前弹出确认 Sheet，展示实际命令。

### Applications

列表数据来自本机 `.app` 扫描，详情来自 `mackup show <application>`。YAMG 使用应用显示名生成 slug，例如 `Raycast.app` 显示为 Raycast，并尝试用 `raycast` 查询 Mackup 详情；若 Mackup 不支持该 slug，则在详情区显示 Mackup 的错误输出。状态包括：

| 状态 | 判断方法 | 注意 |
|---|---|---|
| 已纳入同步 | 在 `[applications_to_sync]` 或默认全同步且不在 ignore | 配置状态，不代表文件已存在 |
| 已排除 | 在 `[applications_to_ignore]` | ignore 高于 sync |
| 未安装 | 尝试查找 CFG 中至少一个路径不存在 | 仅为 UI 提示，不影响 Mackup CLI |
| 自定义 | CFG 来自 `~/.mackup` 或 XDG 自定义目录 | 明确标记覆盖关系 |

### Files

只读展示应用 CFG 中的 `configuration_files` 与 `xdg_configuration_files` 展开结果。YAMG 不允许编辑内置 CFG；自定义 CFG 只能在 Custom Apps 页面编辑。

### Storage

Storage 页面编辑 `[storage]`。界面只提供 provider 与 Mackup folder 两个决策点，避免把 Mackup 的 `path`/`directory` 拆成两个容易混淆的输入；保存时仍严格写回 Mackup 支持的字段。切换后端时，YAMG 只修改配置并提示用户按 Mackup 文档完成迁移：先在所有机器执行 `mackup link uninstall`（若使用 link mode），手动复制 Mackup 文件夹到新位置，修改配置，再在主机执行 `backup`、其他机器执行 `restore`。Mackup 没有自动迁移命令，因此 YAMG 不提供一键迁移。

### Custom Apps

Mackup 支持自定义应用 CFG，因此 YAMG 提供该页面。编辑器字段限定为 `[application] name`、`[configuration_files]`、`[xdg_configuration_files]`。保存位置默认 XDG：`~/.config/mackup/applications/<slug>.cfg`；若存在旧位置 `~/.mackup/<slug>.cfg`，提示旧位置优先。YAMG 不上传、不同步、不维护独立应用市场。

### Preferences

YAMG 偏好：界面语言（跟随系统、简体中文、English）、开机启动、显示菜单栏图标、日志级别、Sparkle 自动更新。Mackup 直通配置：同步列表、忽略列表、存储设置、配置文件路径。高级：手动指定 Mackup 二进制路径、打开 `.mackup.cfg` 文本视图、打开日志目录、关于与许可证。

## 7. 常见任务流

### 在新 Mac 上恢复备份

1. 打开 YAMG，环境检测通过。
2. 选择“从已有备份恢复”。
3. 选择与旧 Mac 相同的存储后端与目录名。
4. YAMG 检测 Mackup 文件夹是否存在。
5. 展示将恢复的应用与潜在覆盖项。
6. 用户确认后执行。

最终调用：`mackup restore`，可附加 `--force`、`--force-no`、`--verbose`、`--config-file`。

### 把某个应用加入或移出同步列表

1. Applications 搜索应用。
2. 用户选择“纳入同步”或“排除同步”。
3. YAMG 更新 `.mackup.cfg` 的 `[applications_to_sync]` 或 `[applications_to_ignore]`。
4. 弹出提示：配置已保存，下一次 backup/restore 生效。

最终调用：保存配置时不调用 Mackup；查看候选应用调用 `mackup list` 与 `mackup show <application>`。

### 切换存储后端

1. Storage 选择新后端。
2. YAMG 写入 `[storage] engine/path/directory`。
3. 显示 Mackup 文档式迁移步骤，不提供自动迁移。
4. 用户可选择在当前机器执行 `backup` 或 `restore`。

最终调用：配置保存不调用 Mackup；用户确认后调用 `mackup backup` 或 `mackup restore`。

### 卸载 YAMG

仅卸载 GUI：退出 YAMG，删除 App，本地 Mackup、`.mackup.cfg`、Mackup 文件夹均保留。  
完全解除 Mackup link mode：先执行 `mackup link uninstall`，确认 symlink 已复制回本地，再删除 YAMG。若用户使用 copy mode，不需要 `link uninstall`。

最终调用：只有解除 link mode 时调用 `mackup link uninstall`。

### 查看 Mackup 日志输出

1. 打开 Logs 页面。
2. 选择一次运行记录。
3. 查看命令、启动时间、退出码、stdout、stderr。
4. 可复制日志或打开日志文件。

最终调用：无；日志来自 YAMG 记录的子进程输出。

## 8. UI / 视觉设计规范

设计原则：遵循 Apple HIG，优先原生控件、系统 Accent Color、浅色/深色自适应。YAMG 是工具型开源软件，界面应克制、清晰、可审计，不使用夸张营销式 Hero。

macOS 26+ 使用 Liquid Glass 相关材质增强 Sidebar、Toolbar、Sheet、Popover、Menu Bar Extra；核心功能不得依赖 macOS 26 独有 API。macOS 12-15 回退到 `.regularMaterial`、`.ultraThinMaterial` 与标准 vibrancy。最低支持 macOS 12 Monterey，理由是 SwiftUI、String Catalog 工作流与现代权限引导较稳定；降至 macOS 11 会增加 UI 与测试成本，不符合 MVP。

字体使用系统 SF Pro。图标使用 SF Symbols 5.0+。应用图标建议三个方向：带齿轮的文件夹、云盘中的 dotfile、终端光标与 Finder 文件夹结合。内部按钮优先图标加 tooltip，例如备份用 `arrow.up.doc`、恢复用 `arrow.down.doc`、日志用 `doc.text.magnifyingglass`。

多语言适配：按钮不固定宽度，使用 `leading/trailing`，列表列宽允许自适应。德语、法语预留 30%-50% 字符增长空间。所有文本允许换行或 truncation tooltip，关键确认文案不截断。

三态设计：

| 视图 | 空状态 | 加载状态 | 错误状态 |
|---|---|---|---|
| Dashboard | 尚未完成环境检测 | 检测 Mackup 中 | Mackup 不可用 |
| Applications | 未读取到应用列表 | 运行 `mackup list` 中 | `mackup list` 失败 |
| Storage | 尚未配置存储 | 检测云盘路径中 | 存储路径不可用 |
| Logs | 暂无运行记录 | 读取日志中 | 日志文件损坏或不可读 |

## 9. 国际化（i18n）架构规范

技术选型：Swift 5.9+、Xcode 15+ String Catalog（`Localizable.xcstrings`）。理由：String Catalog 支持翻译状态、注释、复数、变体管理，适合开源协作。所有用户可见字符串必须用 `LocalizedStringResource` 或 `String(localized:)`，禁止硬编码。

首版语言：`zh-Hans`、`en`。预留语言：`zh-Hant`、`ja`、`de`、`fr`、`es`、`ko`。

命名规范：

| 类型 | 示例 key |
|---|---|
| 页面标题 | `onboarding.welcome.title` |
| 按钮 | `common.button.continue` |
| 错误 | `error.cli.notFound.message` |
| 日志状态 | `install.status.verifying` |
| 菜单项 | `menu.run.backup` |

占位符使用 String Catalog 的 typed placeholder。示例：`cli.status.ready = "已找到 Mackup %@，路径：%@"`，comment 写明第一个占位符是版本，第二个是路径。复数使用 plural variant，例如 `%lld applications supported`。日期、数字、文件大小使用 `Date.FormatStyle`、`ByteCountFormatter`、`NumberFormatter`。路径显示使用 `URL.path(percentEncoded: false)` 与系统 API，不手工拼接展示字符串。

RTL 预留：布局使用 `leading/trailing`，图标与文本用系统 mirroring；首版不支持 RTL 语言，但不得把 left/right 写死在布局逻辑中。

测试策略：启用 Xcode “Show non-localized strings”；使用 double-length pseudolanguage 检查溢出；用英文、中文、伪语言跑向导、安装失败、冲突确认、日志页面。CI 可加入脚本扫描 Swift 文件中的裸字符串。

开源翻译流程：MVP 用 GitHub PR 直接编辑 `Localizable.xcstrings`，门槛低。v1.0 后可接入 Weblate，优点是适合社区译者与翻译记忆；Crowdin 商业生态成熟但开源项目配置成本较高。每条字符串必须有 comment，否则 PR 不合并。

## 10. 错误处理与边界情况

| 场景 | 检测方法 | 中文提示 | English | 恢复操作 |
|---|---|---|---|---|
| Mackup 未找到 | 扫描路径与 `which` | 未找到 Mackup。 | Mackup was not found. | 一键安装或选择路径 |
| 版本过低 | `--version` | Mackup 版本过低。 | Mackup is too old. | Homebrew/pipx 升级 |
| 版本无法解析 | stdout 不匹配 | 无法识别 Mackup 版本输出。 | Could not parse Mackup version. | 复制输出，手动指定 |
| Homebrew 未安装 | brew 路径不存在 | 未找到 Homebrew。 | Homebrew was not found. | 选择 pipx 或打开 Homebrew 文档 |
| Python 过低 | `python3 --version` | Python 版本低于 3.9。 | Python is older than 3.9. | 安装新版 Python |
| pipx 不可用 | `pipx --version` 失败 | 未找到 pipx。 | pipx was not found. | 安装 pipx |
| 云盘未挂载 | storage path 不存在 | 存储位置不可用。 | Storage location is unavailable. | 打开云盘 App 或换 file_system |
| 磁盘空间不足 | `URLResourceValues.volumeAvailableCapacity` | 可用空间不足。 | Not enough disk space. | 清理空间或换位置 |
| 权限被拒 | stderr/PermissionError | YAMG 无法读取或写入该文件。 | YAMG cannot read or write this file. | 授予完整磁盘访问 |
| 配置损坏 | ConfigParser 失败或 Mackup 非 0 | `.mackup.cfg` 无法读取。 | `.mackup.cfg` cannot be read. | 打开文本编辑器修复 |
| 旧配置格式 | Mackup 报 old section | 检测到旧版配置格式。 | Old configuration format detected. | 按文档迁移 |
| 网络中断 | 云盘路径消失或命令失败 | 云盘同步可能已中断。 | Cloud storage may be disconnected. | 重新连接后重试 |
| 用户强制退出 | 子进程被终止 | 命令已中断，Mackup 不提供回滚。 | Command interrupted. Mackup has no rollback. | 查看日志后重试 |
| symlink 指向其他位置 | 文件系统检查或 Mackup 警告 | 已存在指向其他位置的符号链接。 | A symlink points somewhere else. | 手动确认后再执行 |
| 应用未安装 | CFG 路径均不存在 | 未找到该应用的配置文件。 | No config files were found for this app. | 保留配置或排除 |
| macOS 路径变化 | 路径不存在 | 该路径在当前系统不存在。 | This path does not exist on this macOS version. | 参考 Mackup 上游更新 |
| 文件被占用 | copy/delete 失败 | 文件可能正在被其他 App 使用。 | The file may be in use by another app. | 退出相关 App 后重试 |
| 特殊字符路径 | 路径 API 校验 | 路径包含特殊字符，请确认显示无误。 | The path contains special characters. Verify it carefully. | 使用系统文件选择器 |
| 子进程卡死 | 超时无输出 | Mackup 暂无响应。 | Mackup is not responding. | 取消或继续等待 |
| 输出无法解析 | parser 失败 | 命令已完成，但部分输出无法解析。 | Command finished, but some output could not be parsed. | 展示原始日志 |

## 11. 技术架构建议

技术栈：SwiftUI 为主，必要时使用 AppKit 定制 `NSToolbar`、日志文本视图、文件选择器。与 Mackup 的交互使用 `Process` 启动子进程，分别读取 stdout/stderr。不要直接 import Python 模块，理由是：隔离崩溃、尊重用户已安装版本、避免 Python ABI 与虚拟环境问题、保持 YAMG 是前端而不是 fork。

数据存储：

| 数据 | 位置 | 说明 |
|---|---|---|
| YAMG 偏好 | `UserDefaults` | 语言、菜单栏图标、CLI 路径 |
| 运行日志 | `~/Library/Application Support/YAMG/Logs/` | stdout/stderr、命令、退出码 |
| 运行历史 | `~/Library/Application Support/YAMG/RunHistory.json` | 上次执行时间等 YAMG 元数据 |
| Mackup 配置 | `~/.mackup.cfg` 或 Mackup 支持路径 | 严格按 Mackup 格式读写 |

权限模型：非沙盒。Mackup 的核心任务需要访问 dotfiles、`~/Library`、任意 file_system 路径与云盘目录，Mac App Store 沙盒不适合。分发采用 Developer ID 公证 DMG、GitHub Releases、Homebrew Cask；不上架 Mac App Store。

模块建议：`CLIClient`、`MackupDetector`、`ConfigStore`、`ApplicationsRepository`、`ProcessLogStore`、`OnboardingFeature`、`DashboardFeature`、`I18nResources`。关键协议包括 `MackupExecutableResolving`、`MackupCommandRunning`、`MackupConfigEditing`。

## 12. 里程碑与发布计划

| 版本 | 范围 | 必须完成 |
|---|---|---|
| MVP v0.1 | 检测与 copy mode 主流程 | Mackup 检测、一键安装、向导、Storage、Applications 只读、`backup`、`restore`、双语基础 |
| v1.0 | 覆盖 Mackup CLI 与配置 | `list`、`show`、`backup`、`restore`、`link install`、`link`、`link uninstall`、所有 `.mackup.cfg` 字段 GUI 化、自定义应用 CFG、完整 i18n |
| v1.x | 质量与社区 | 更多语言、错误文案完善、视觉打磨、日志检索、稳定性优化，不新增 Mackup 不支持的功能维度 |

## 13. 开源治理

许可证建议 GPL-3.0-or-later。优点是与 Mackup 一致，能约束下游保持开源；缺点是商业集成自由度低。MIT 优点是使用自由、贡献门槛低；缺点是与上游 GPL 气质不一致。YAMG 是公益开源 GUI，推荐 GPL。

仓库结构：

```text
YAMG/
  App/
  Features/
  MackupCLI/
  Config/
  Resources/Localizable.xcstrings
  Docs/
  Tests/
```

分支策略：`main` 保持可发布，`develop` 集成下一版本，`translation/*` 用于集中翻译。Issue 模板：Bug、Translation、Documentation、Mackup Compatibility。CONTRIBUTING 要点：说明 YAMG 不接收超出 Mackup 能力的 PR；任何新增功能必须标注对应 Mackup 命令或配置项；翻译 PR 必须保留 key 与 comment。

与上游关系：YAMG 是纯下游消费者，不 fork Mackup，不修改 Mackup 代码，不替代其分发。README 应致谢 Mackup 与 Laurent Raufaste，并链接上游仓库。

不接收的 PR：定时同步、增量同步、快照、加密、在线应用库、独立同步引擎、绕过 Mackup CLI 的 Python 模块调用。

## 14. 风险与开放问题

1. 上游维护活跃度：2025-2026 有新版本发布，但 YAMG 长期依赖上游 CLI 行为，需要建立兼容性测试。
2. 版本分歧：本地源码为 0.10.3，PyPI/Homebrew 稳定版为 0.10.2，YAMG 需要明确最低版本策略。
3. Link mode 风险：Mackup README 对 macOS 14+ 明确警告 symlinked preferences 问题，YAMG 应默认推荐 copy mode。
4. 安装路径演进：未来上游可能推荐 uv、pipx 或其他安装方式，检测模块要可扩展。
5. 公证与权限：非沙盒 App 访问大量配置文件可能触发用户不信任或系统权限限制。
6. 命名授权：Yet Another Mackup GUI 使用 Mackup 名称，应与上游作者沟通致谢与商标表述。
7. 翻译质量：开源翻译需要 reviewer 与术语表，否则错误文案可能误导用户做危险操作。
8. Google Drive 检测：Mackup 当前读取旧 `sync_config.db`，新版 Google Drive 行为可能变化，YAMG 只能提示上游限制。

## 术语表

| 中文 | English | 说明 |
|---|---|---|
| 备份 | Backup | `mackup backup`，复制本地配置到 Mackup 文件夹 |
| 恢复 | Restore | `mackup restore`，复制 Mackup 文件夹配置到本地 |
| 链接安装 | Link Install | `mackup link install`，移动配置并创建 symlink |
| 解除链接 | Link Uninstall | `mackup link uninstall`，移除 Mackup 管理的 symlink |
| 存储后端 | Storage Backend | Dropbox、Google Drive、iCloud、file_system |
| 配置文件 | Configuration File | `.mackup.cfg` 或应用 CFG |
| 应用 slug | Application Slug | Mackup 内部应用 ID，如 `git`、`iterm2` |
| 完整磁盘访问 | Full Disk Access | macOS 隐私权限 |
| 试运行 | Dry Run | `--dry-run`，显示步骤但不执行 |
| 字符串目录 | String Catalog | Xcode `.xcstrings` 本地化资源 |

## 修订记录

| 日期 | 版本 | 作者 | 变更摘要 |
|---|---|---|---|
| 2026-05-18 | v0.1 | Codex | 基于 Mackup 源码勘察创建首版 PRD |

## 参考来源

| 来源 | 用途 |
|---|---|
| `mackup/src/mackup/main.py` | CLI 命令、参数、版本输出 |
| `mackup/src/mackup/config.py` | `.mackup.cfg` 查找、存储字段、默认值 |
| `mackup/src/mackup/appsdb.py` | 应用 CFG 与自定义应用加载规则 |
| `mackup/src/mackup/application.py` | backup/restore/link 行为与冲突处理 |
| `mackup/src/mackup/utils.py` | 复制、删除、symlink、云盘检测 |
| `mackup/README.md`、`mackup/doc/README.md` | 用户语义、copy/link mode、配置文档 |
| PyPI `mackup` 项目页 | 当前稳定发行版 0.10.2 |
| Homebrew Formulae `mackup` 页 | Homebrew 当前稳定版 0.10.2 |
