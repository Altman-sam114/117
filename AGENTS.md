# AGENTS.md

本文是 MD Journal 的入口记忆、项目总览、硬规则和多 Agent 云端迭代工作流。

MD Journal 是一个原生 SwiftUI iOS Markdown 日记应用，主链路是“用户编辑日记 -> `JournalEntry` 状态更新 -> `JournalStore` 本地 JSON 持久化 -> SwiftUI 列表、编辑器、预览和统计看板渲染”。

## 1. 必读文件

每次开始任务前按顺序阅读：

1. `AGENTS.md`
2. `update_log.md`
3. `md/flow/flow.md`
4. `md/flow/flowchart.md`
5. `md/test/test.md`
6. `README.md`
7. `md/prompt/README.md`
8. 与本轮任务直接相关的 Swift 源码、Xcode 工程配置、workflow 和提示词文件

同时运行：

```sh
git status --short --branch
```

需要云端验证、推送或下载结果包时，还必须查看：

```sh
git log --oneline -5
git branch --all
git remote -v
```

## 2. 角色召唤和身份标识

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务必须区分 A/B/C 边界，提醒用户指定角色或说明本轮按普通任务执行。
- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## 3. 项目基本规则

- 代码以 SwiftUI 原生实现为主，不引入第三方依赖，除非人工明确要求。
- 当前工程最低 iOS 版本为 16.0；修改 deployment target 必须同步说明影响。
- 用户数据只保存在本地 JSON，不引入服务器、账号或云同步，除非人工明确提出。
- 保持当前安静、实用、偏工具型的中文界面风格。
- 支持 iPhone 竖屏和横屏；新增页面必须考虑窄屏、宽屏和 Dynamic Type。
- 变更范围要贴合本轮目标，不做无关重构。
- 不删除、不回滚用户或其他 Agent 的未说明改动。

## 4. 核心架构边界

- `JournalEntry` 是日记数据模型和兼容解码边界。
- `JournalStore` 是唯一的日记集合修改与本地持久化入口。
- `ContentView` 负责应用级导航、选中项修复和保存错误展示。
- `EntryListView` 负责列表、搜索、分类筛选和统计入口。
- `EntryEditorView` 负责元数据编辑、正文编辑、Markdown 快捷插入和编辑/预览布局。
- `MarkdownBlockParser` 负责轻量 Markdown 分块与 `###` 小节分组。
- `MarkdownPreviewView` 只消费解析结果并渲染预览，不负责保存数据。
- `JournalStatistics` 负责统计计算，视图只展示结果。

## 5. main 直推与云端验证规则

- 默认使用 `main` 作为唯一上传、提交、推送和云端验证分支。
- 本阶段不使用 `smalldata_test`、`develop`、`codeb/...` 或其他候选分支，不创建 PR，不执行 PR merge。
- 任何 Agent 在 `git push origin main` 或改变远端 `main` 前，都必须确认当前分支是 `main`，目标远端是 `origin/main`，且提交范围只包含本轮相关文件。
- Agent B 每轮开始前必须同步最新 `origin/main`，确认工作区无无关改动，再在 `main` 上实现。
- Agent B 完成后本地只跑轻量检查，提交并直接 push 到 `origin/main`，触发 GitHub Actions 重验证。
- Agent C 只验收 `origin/main` 最新 commit 对应的 `commitSha`、run id、run attempt 和未加密 artifact，不验收旧 run 或旧 artifact。
- Agent C 必须用 `gh auth login` 后下载 artifact；下载缓存默认放在 `/private/tmp/mdjournal-c-review-<run_id>/`。
- Agent C 发现问题时，不做回滚式处理；默认退回 Agent B 在 `main` 上追加修复 commit，再 push 触发新 run。
- 若当前仓库没有 `origin` 远端、没有 GitHub Actions 权限或无法下载 artifact，必须明确记录阻塞，不能伪装云端验收已完成。

推荐同步和推送命令：

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git status --short
git add 相关文件
git commit -m "vX.Y: 简要说明本轮做了什么"
git push origin main
```

## 6. 标准迭代工作流

### 人工

人工提出目标、限制、验收标准和测试要求。人工也可以指定版本号、算法框架、UI/交互要求或禁止项。

### Agent A：目标分析与提示词

Agent A 默认不直接写代码，负责把人工目标转成给 Agent B 的实现提示词。

Agent A 必须：

- 阅读入口文档、更新日志、核心流程、流程图、测试规范、prompt 规则和相关源码。
- 明确目标、非目标、边界、依赖、风险、CI 要求和验收标准。
- 设计实现方案，说明要改哪些模块、状态流如何变化、需要哪些本地轻量检查、云端 workflow 和结果包验收。
- 分配版本号：人工指定则按人工指定；未指定时沿当前 `v0.x` 小版本递增，重要阶段可开 `v1.0`。
- 将提示词写入 `md/prompt/v0（简要标题）/v0.1（简要说明）.md` 这类路径。

### Agent B：实现、轻量检查、main 直推

Agent B 按 Agent A 提示词实现。

Agent B 必须：

- 阅读 Agent A 提示词和项目入口文档。
- 从最新 `origin/main` 开始；若没有远端或无法同步，必须先记录阻塞。
- 小步实现，不扩大范围，不绕过核心状态边界。
- 根据 `md/test/test.md` 运行本地轻量检查。
- 提交本轮相关文件并 push 到 `origin/main`，触发 GitHub Actions。
- 记录实际命令、结果、commit SHA、push 结果、未跑测试原因和已知风险。

### Agent C：云端结果包验收与文档确认

Agent C 验收 Agent B 的结果，维护核心逻辑文档，并只以云端结果包作为最终重验证依据。

Agent C 必须：

- 查看实际 diff、最新 `origin/main` commit 和对应 GitHub Actions run。
- 下载未加密 CI 结果包，核对 manifest、JUnit 或等价摘要、主构建日志、失败摘要和项目关键产物。
- 确认 manifest 中的 `branch`、`commitSha`、`runId`、`runAttempt` 与最新 `origin/main` 完全一致。
- 对照人工目标与 Agent A 提示词判断是否通过。
- 检查架构边界、测试覆盖、文档同步和风险说明。
- 更新 `md/flow/flow.md`、`md/flow/flowchart.md` 和必要的 `update_log.md`。
- 如不通过，列出问题并退回 Agent B 在 `main` 上追加修复 commit，不得把失败版本伪装成通过。
- 如最终通过，确认 `update_log.md` 已记录版本、验证结果、artifact 名称和遗留事项。

## 7. 测试规则

- 每次实现前先读 `md/test/test.md`。
- 默认云端重验证，本机只跑轻量检查。
- 只有人工明确要求“本机测试”“本地 build”“本地 xcodebuild”“本地跑模拟器”时，才把本机完整构建或模拟器验证作为默认路径。
- 文档-only 修改可只跑 `git diff --check`、workflow YAML 解析、Xcode project plist 解析等轻量检查，但必须说明未跑完整构建或云端验证的原因。
- 不得用“已验证”替代具体命令和结果。
- 不得伪造测试通过、云端 run 通过或 artifact 已核对。

## 8. 文档规则

- `AGENTS.md` 只写入口规则和协作流程，不堆历史。
- `update_log.md` 记录正式版本、重要维护事项、关键决策和遗留问题。
- `md/flow/flow.md` 只写当前真实核心逻辑和云端协作流，不写历史流水账。
- `md/flow/flowchart.md` 用 Mermaid 表达当前真实核心数据流、执行流和 Agent 云端迭代流。
- `md/test/test.md` 记录测试分层、命令、触发条件、云端结果包和当前基线。
- `md/prompt/` 保存每轮 Agent A 输出的详细实现提示词。
- 每次完成实际开发、修复、重构或流程改造后，必须同步更新 README、测试规范、核心流程和更新日志中受影响的部分。

## 9. 交付格式

最终回复使用中文，必须包含：

- 本轮改了什么。
- 关键文件。
- 实际运行的验证命令和结果。
- 当前分支、commit SHA；如已云端验证，还要写 run id、run attempt 和 artifact 名称。
- 是否已 push 到 `origin/main`。
- Agent C 是否下载并核对结果包。
- 未运行的测试及原因。
- 已知风险或下一步建议。

## 10. 禁止项

- 禁止无依据改动数据持久化格式。
- 禁止绕过 `JournalStore` 直接批量改写日记集合。
- 禁止引入第三方依赖后不记录原因、影响和验证结果。
- 禁止删除或覆盖用户数据。
- 禁止破坏 `###` 小节识别、Markdown 预览、分类/心情兼容解码和本地 JSON 保存这些核心行为。
- 禁止用模板文档替代对当前项目真实状态的描述。
- 禁止把旧 artifact、旧输出或本地文件冒充本轮云端结果包。
- 禁止在没有 `origin/main` 或 GitHub Actions 权限时伪装已经完成云端验收。
