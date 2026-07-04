# 项目核心流程文档

## 0. 一句话总览

MD Journal 的当前主链路是：用户在 SwiftUI 界面创建和编辑日记，`JournalEntry` 承载标题、正文、日期、分类和心情，`JournalStore` 负责本地 JSON 加载与保存，列表、编辑器、Markdown 预览和统计看板根据同一份日记状态实时渲染。应用当前支持 iOS/iPadOS，并通过 Mac Catalyst 构建为 macOS app。

协作主链路是：人工提出目标 -> Agent A 写版本化提示词 -> Agent B 在 `main` 上实现并直推 `origin/main` -> GitHub Actions 生成未加密 CI 结果包 -> Agent C 下载结果包复判 -> 通过则记录版本，失败则退回 Agent B 在 `main` 上追加修复 commit。

未来可选主控链路是：人工用 `agentx:` 提供总目标 X -> Agent X 拆分小轮次 -> 每轮仍按 Agent A -> Agent B -> Agent C 执行 -> Agent X 根据 Agent C artifact 验收结果判断继续、退回、暂停或完成。

## 1. 当前核心数据流

```text
用户操作
  -> ContentView 维护选中日记 ID
  -> EntryListView / EntryEditorView 发起创建、删除、编辑
  -> JournalStore 更新 [JournalEntry]
  -> JSONEncoder / JSONDecoder 读写 Documents/md-journal-entries.json
  -> SwiftUI 重新渲染列表、编辑器、预览和统计
```

Markdown 与统计派生数据流：

```text
JournalEntry.body
  -> MarkdownBlockParser.parseDocument
  -> MarkdownParseResult.blocks / sectionGroups
  -> MarkdownPreviewView 渲染普通块或 ### 小节分组预览
  -> 日记卡片小节摘要、统计小节覆盖率继续由 JournalEntry.sections 派生

[JournalEntry]
  -> JournalStatistics
  -> 总篇数、总词数、连续天数、7 天趋势、分类分布、心情分布、小节覆盖率
  -> EntryListView 概览卡片 / StatisticsDashboardView
```

## 2. 当前核心执行流

### 2.1 启动与加载

1. `MDJournalApp` 创建 `ContentView`。
2. `ContentView` 通过 `@StateObject` 初始化 `JournalStore`。
3. `JournalStore.init` 定位 Documents 目录下的 `md-journal-entries.json`。
4. 若文件不存在，创建 `JournalEntry.starterEntry()` 并保存。
5. 若文件存在，使用 ISO8601 日期策略解码 `[JournalEntry]`。
6. 解码后按 `createdAt` 倒序排序。
7. `ContentView.onAppear` 选择第一篇日记。

### 2.2 创建日记

1. 用户点击列表工具栏“新建”或空状态“写一篇”。
2. `ContentView.createEntry()` 调用 `JournalStore.createEntry()`。
3. `JournalStore` 创建默认日记，正文包含三个 `###` 小节。
4. 新日记插入 `entries` 首位并保存到本地 JSON。
5. `ContentView` 将 `selectedEntryID` 切到新日记。

### 2.3 编辑与保存

1. `ContentView.selectedEntryBinding` 为当前日记生成 `Binding<JournalEntry>`。
2. `EntryEditorView` 通过 binding 编辑标题、日期、分类、心情和正文。
3. binding setter 调用 `JournalStore.update(_:)`。
4. `JournalStore.update` 更新 `updatedAt`、替换数组中的日记、重新排序，并安排短延迟保存。
5. 连续编辑会合并为一次 JSON 写盘；内存中的 `entries` 始终即时更新。
6. 应用进入 inactive/background 时，`ContentView` 调用 `JournalStore.flushPendingSave()` 立即写入待保存变更。
7. 保存失败时设置 `errorMessage`。
8. `ContentView` 通过 alert 展示保存或读取错误。

### 2.4 列表、筛选与删除

1. `EntryListView` 接收 `entries` 和 `selection`。
2. 搜索文本匹配标题、正文、分类、心情。
3. 分类芯片通过 `selectedCategory` 过滤列表。
4. `EntryRowView` 展示分类、心情、日期、摘要、词数、小节数和小节标题。
5. 用户滑动删除或在 Mac Catalyst 下右键删除时调用 `ContentView.deleteEntry(_:)`。
6. `JournalStore.delete(_:)` 从数组移除日记并保存。
7. `ContentView.repairSelection` 确保选中项仍然有效。

### 2.5 Markdown 预览

1. `EntryEditorView` 在窄屏用 segmented picker 切换编辑和预览。
2. 宽度大于等于 `820` pt 时，编辑和预览左右分栏同时展示。
3. `MarkdownPreviewView` 调用 `MarkdownBlockParser.parseDocument(_:)` 获取单次解析结果。
4. 如果解析结果存在非开篇 `###` 分组，则按 `MarkdownSectionGroup` 渲染小节卡片。
5. 否则按普通块序列渲染。
6. 内联 Markdown 通过 `AttributedString(markdown:)` 做轻量渲染。

### 2.6 统计看板

1. 用户点击列表工具栏“统计”。
2. `EntryListView` 通过 closure 请求 `ContentView` 显示统计，Mac Catalyst 下也可从“日记”菜单触发。
3. `ContentView` 以 sheet 形式打开 `StatisticsDashboardView`。
4. `StatisticsDashboardView` 用当前 `entries` 构造 `JournalStatistics`。
5. 统计计算总篇数、总词数、平均词数、小节覆盖率、连续天数、本周数据、分类分布、心情分布和最近 7 天趋势。
6. 宽度大于等于 `820` pt 时使用两列布局，否则使用单列滚动布局。
7. Mac Catalyst 下仍以 sheet 展示统计，后续可扩展为独立窗口。

### 2.7 Mac Catalyst 菜单命令

1. `MDJournalApp` 在 scene level 注册“日记”菜单。
2. `ContentView` 通过 focused scene value 暴露新建日记和显示统计两个动作。
3. 菜单“新建日记”调用 `ContentView.createEntry()`，并承载 `⌘N` 快捷键。
4. 菜单“显示统计”调用 `ContentView.showStatistics()`，复用与列表工具栏相同的统计 sheet。
5. 工具栏新建和统计按钮继续保留，作为非菜单的可见入口。

## 3. Agent 云端协作流

### 3.1 角色召唤

- `agenta`、`a:` 或 `A:` 召唤 Agent A。
- `agentb`、`b:` 或 `B:` 召唤 Agent B。
- `agentc`、`c:` 或 `C:` 召唤 Agent C。
- `agentx`、`x:` 或 `X:` 召唤 Agent X。
- 未带前缀时按普通 Codex 任务处理；若任务需要明确 A/B/C/X 边界，先要求人工指定或说明本轮按普通任务执行。

### 3.2 Agent X 主控循环

Agent X 是未来的主控调度角色，用于围绕一个总目标 X 多轮调用现有 A/B/C 流程。Agent X 不直接替代 Agent A 的提示词设计、不替代 Agent B 的实现和 push，也不替代 Agent C 的云端结果包验收。

Agent X 单轮循环：

1. 接收人工总目标、限制和验收标准。
2. 把总目标拆成当前轮次目标，明确非目标、关键文件、验证要求和退出条件。
3. 要求 Agent A 写本轮版本化提示词。
4. 要求 Agent B 基于提示词实现、跑本地轻量检查、commit 并 push 到 `origin/main`。
5. 等待 GitHub Actions 生成最新 run 的未加密 artifact。
6. 要求 Agent C 下载并核对最新 artifact 的 manifest、JUnit 或等价摘要、日志和结果包产物。
7. 根据 Agent C 结论判断：
   - 继续下一轮：本轮通过，且总目标仍有明确剩余任务。
   - 退回 Agent B：本轮未通过，但问题可由追加修复 commit 解决。
   - 暂停等待人工：需要权限、账号、密钥、付费服务、产品决策或冲突归属判断。
   - 宣布完成：总目标已完成，且最后一轮已通过 Agent C artifact 验收。

Agent X 不能无条件无限循环。遇到连续 3 轮同一阻塞、连续 2 轮没有有效 diff、CI 连续同因失败、用户要求停止或方向改变时，必须暂停或结束并说明原因。

### 3.3 Agent A 输出提示词

1. 读取入口文档、更新日志、流程、流程图、测试规范、prompt 规则和相关源码。
2. 判断目标、非目标、架构边界、风险和验收标准。
3. 指定本地轻量检查、云端 workflow、结果包内容和 Agent C 核对方式。
4. 分配版本号并把提示词写入 `md/prompt/`。

### 3.4 Agent B main 直推

1. 确认当前分支是 `main`。
2. 执行 `git fetch origin`、`git pull --ff-only origin main`，确保基于最新 `origin/main`。
3. 若没有 `origin` 远端或无法同步，记录阻塞，不伪造云端流程。
4. 小步实现，只改本轮相关文件。
5. 本地运行 `md/test/test.md` 要求的轻量检查。
6. `git commit` 后 `git push origin main`，触发 GitHub Actions。

### 3.5 GitHub Actions 结果包

1. `.github/workflows/ci-results.yml` 在 `main` push 和 `workflow_dispatch` 时运行。
2. CI 执行静态检查、generic iOS Debug build、Mac Catalyst Debug build 和 `MDJournalTests` XCTest。
3. CI 上传未加密 artifact，至少包含：
   - `ci-artifact-manifest.json`
   - `ci-failure-summary.md`
   - `static-checks.log`
   - `xcodebuild.log`
   - `maccatalyst-build.log`
   - `xctest.log`
   - `junit.xml`
   - 可用时的 `MDJournal.xcresult`
   - 可用时的 `MDJournalMacCatalyst.xcresult`
   - 可用时的 `MDJournalTests.xcresult`
4. manifest 必须记录 `branch`、`commitSha`、`runId`、`runAttempt`、workflow 名称、scheme、iOS build destination、Mac Catalyst build destination、test destination、日志路径和各阶段 outcome，其中 `testOutcome` 和 `macCatalystBuildOutcome` 是真实 `success/failure`。

### 3.6 Agent C 结果包验收

1. 确认 `origin/main` 最新 commit。
2. 使用 `gh auth login` 后下载最新 run 的 artifact 到 `/private/tmp/mdjournal-c-review-<run_id>/`。
3. 打开并核对 `ci-artifact-manifest.json`、`junit.xml`、主日志和失败摘要。
4. 只验收 manifest 中 `branch=main` 且 `commitSha`、`runId`、`runAttempt` 与最新 `origin/main` 和 GitHub Actions run 完全一致的结果包。
5. 通过则确认文档和 `update_log.md` 已同步；失败则退回 Agent B 在 `main` 上追加修复 commit 并重新 push。

## 4. 核心状态对象 / 模块

### 4.1 `JournalEntry`

职责：描述单篇日记和派生展示信息。

输入：标题、正文、创建时间、更新时间、分类、心情。

输出：展示标题、摘要、词数、`###` 小节、Markdown 分享文档。

禁止：新增字段时破坏旧 JSON 解码；随意改变分类、心情 rawValue。

### 4.2 `JournalStore`

职责：加载、保存、创建、更新、删除和排序日记。

输入：用户操作产生的日记变更。

输出：`@Published entries`、`errorMessage`、本地 JSON 文件。

禁止：在其他模块绕过它直接改写日记集合或本地文件。

### 4.3 `MarkdownBlockParser`

职责：把轻量 Markdown 字符串解析成块和 `###` 小节组。

输入：`JournalEntry.body`。

输出：`MarkdownParseResult`、`[MarkdownBlock]`、`[MarkdownSectionGroup]`。

禁止：在未更新 README、测试规范和 flow 文档的情况下改变现有语法含义。

### 4.4 `JournalStatistics`

职责：把 `[JournalEntry]` 转成统计看板所需数据。

输入：日记数组、日历、当前时间。

输出：总量、平均值、连续天数、分布、7 天趋势和洞察文案。

禁止：在视图层复制统计逻辑。

### 4.5 SwiftUI Views

职责：展示状态、收集用户输入、调用上层 closure 或 binding。

输入：`entries`、`Binding<JournalEntry>`、筛选状态、布局宽度。

输出：界面、用户事件、分享 sheet、统计 sheet。

禁止：把持久化、复杂统计或 Markdown 解析业务塞进视图。

## 5. 关键边界

- 数据层：`JournalStore` + `JournalEntry` + JSON 编解码。
- 模型/规则层：`MarkdownBlockParser`、`JournalStatistics`、日期格式化和 Markdown snippet。
- UI 层：`ContentView`、列表、编辑器、预览、统计、空状态、工具栏。
- 工程配置：`MDJournal.xcodeproj/project.pbxproj` 控制 target、bundle id、iOS 版本、Mac Catalyst 支持和方向。
- CI 层：`.github/workflows/ci-results.yml` 负责 main push 后的 iOS build、Mac Catalyst build、XCTest 云端重验证和结果包上传。
- 文档与流程层：`AGENTS.md`、`update_log.md`、`md/test/test.md`、`md/flow/`、`md/prompt/`。
- 版本提交层：Agent B 在 `main` 上提交并推送；Agent C 基于 `origin/main` 最新结果包验收。

## 6. 用户入口

- App 启动后进入 `ContentView`。
- 左侧/主列表：查看、搜索、筛选、新建、删除、打开统计。
- 详情编辑器：修改标题、日期、分类、心情、正文，插入 Markdown 片段，分享文档。
- 预览：窄屏切换查看，宽屏与编辑器并排查看。
- 统计看板：从列表工具栏打开。
- Mac Catalyst：在 macOS 上运行同一 app target，列表支持右键删除，“日记”菜单支持新建和显示统计，`⌘N` 新建由菜单命令承载。

## 7. 前端 / 数据层 / 模型层 / 测试层关系

- 前端只通过 binding、closure 和 `JournalStore` 暴露的操作改变状态。
- 数据层负责本地文件读写和错误上报。
- 模型层负责兼容解码和派生属性。
- 规则层负责 Markdown 解析与统计。
- 测试层当前包含本地轻量检查、本机可选 Mac Catalyst build、`MDJournalTests` 核心规则与 `JournalStore` 写入节流 XCTest，以及 GitHub Actions generic iOS build、Mac Catalyst build 和 iOS Simulator XCTest 重验证。

## 8. 已确认的铁律

- 本地 JSON 保存不能静默失败，错误必须进入 `errorMessage`。
- 编辑过程可以节流写盘，但内存状态必须即时更新，应用离开活跃态前必须 flush 待保存变更。
- Markdown 预览应复用单次解析结果，避免同一渲染周期重复解析正文。
- Mac Catalyst 的核心创建和统计动作应同时有工具栏与菜单入口，重要快捷键不能重复注册。
- 旧数据缺失 `updatedAt`、`category`、`mood` 时必须能解码。
- 日记排序按 `createdAt` 倒序。
- 新建日记必须包含默认 `###` 小节模板。
- `###` 是当前小节分组的核心标记。
- iPhone 需要支持竖屏、横屏左、横屏右。
- 宽屏阈值当前为 `820` pt。
- Mac 版本当前采用 Mac Catalyst，不新增独立 native macOS target。
- 默认云端重验证，本机只跑轻量检查，除非人工明确要求本机构建。
- Agent C 必须核对云端未加密结果包；不得只看 Agent B 文字汇报。
- 没有 `origin/main`、GitHub Actions 权限或 artifact 下载权限时，必须记录阻塞。

## 9. 未来扩展点

- 扩展 `MDJournalTests` 覆盖 `JournalStore` 可测试性、更多 Markdown 边界和数据迁移风险。
- 增强 Markdown 预览语法，但保持轻量并同步测试。
- 改善插入片段后的光标位置。
- 增加导入/导出或备份功能。
- 增加更可靠的模拟器或真机视觉验证流程。
- 为文档增加 markdown lint。
- 在 GitHub Actions 中补充覆盖率或 UI 截图产物。

## 10. 不允许破坏的行为

- 日记能创建、编辑、删除并保存到本地 JSON。
- 重启后能加载已有日记。
- 分类、心情、日期、标题、正文都能编辑。
- 搜索标题、正文、分类、心情可用。
- Markdown 预览能显示当前支持的块类型。
- `###` 小节能驱动预览分组、列表摘要和统计覆盖率。
- 统计看板能在无数据和有数据时稳定展示。
- 宽屏编辑器双栏和统计两列不能在窄屏造成重叠。

## 11. 测试映射

- `JournalEntry` 改动：本地轻量检查 + `MDJournalTests` 兼容解码 XCTest + 云端 CI。
- `JournalStore` 改动：本地轻量检查 + 云端 CI；涉及数据迁移时需人工确认更高等级验证。
- `MarkdownBlockParser` 改动：本地轻量检查 + `MDJournalTests` 解析 XCTest + 云端 CI。
- `JournalStatistics` 改动：本地轻量检查 + `MDJournalTests` 统计 XCTest + 云端 CI。
- UI 视图改动：本地轻量检查 + 云端 CI；涉及横屏和布局时补手动视觉验证。
- 文档-only 改动：`git diff --check`、workflow YAML 解析、必要时补 `plutil`。
