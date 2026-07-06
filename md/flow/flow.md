# 项目核心流程文档

## 0. 一句话总览

MD Journal 的当前主链路是：`MDJournalApp` 持有共享 `JournalStore`，用户在 SwiftUI 界面创建和编辑日记，`JournalEntry` 承载标题、正文、日期、分类和心情，`JournalEntryBodyMetrics` 负责非持久化正文词数和 `###` 小节轻量派生，`JournalEntryBodySummary` 负责正文摘要并复用 metrics，摘要清理由单次扫描去除轻量 Markdown 标记，`JournalEntryListSnapshot` 负责非持久化列表搜索、筛选和分类计数派生，`JournalListOverviewSnapshot` 负责列表首页轻量概览统计，`MarkdownSnippetInsertion` 负责光标/选区 Markdown 片段插入规则，包含选区空白行跳过和有序列表非空行递增编号，`MarkdownLineContinuation` 负责 Markdown 无序列表、待办、引用和有序列表的回车续写规则，`MarkdownLineIndentation` 负责 Tab / Shift-Tab 行缩进规则，反缩进会删除一个 tab 或最多两个行首空格，`MarkdownBlockParser` 负责标题、段落、引用、无序列表、有序列表、待办、代码、分割线和 `###` 小节分组解析，`MarkdownBodyTextView` 负责正文输入 traits、键盘缩进入口和 UIKit bridge，`JournalStore` 负责本地 JSON 加载、按需排序与保存，`JournalStatistics` 负责统计聚合、分布最大值、主导分类/心情和 7 天趋势最大词数派生，列表、编辑器、Markdown 预览和统计看板根据同一份日记状态实时渲染。应用当前支持 iOS/iPadOS，并通过 Mac Catalyst 构建为 macOS app；本地 Mac 运行由 `script/build_and_run.sh` 和 Codex `Run` action 统一入口承载。

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
  -> JournalEntryBodyMetrics
  -> wordCount / sections / sectionCount
  -> EntryEditorView 头部、JournalStatistics 和 JournalListOverviewSnapshot 轻量复用，不生成 excerpt；头部横向小节概览懒加载离屏卡片

JournalEntry.body
  -> JournalEntryBodySummary
  -> 单次扫描清理 Markdown 标记后的 excerpt + JournalEntryBodyMetrics
  -> 列表卡片复用同一次正文展示派生结果

JournalEntry.body
  -> MarkdownBlockParser.parseDocument
  -> MarkdownParseResult.blocks / sectionGroups
  -> MarkdownPreviewView 复用小节分组判断，并用索引迭代渲染普通块、列表项或 ### 小节分组预览，其中有序列表保留用户输入编号

[JournalEntry]
  -> JournalEntryListSnapshot 单次派生列表搜索、分类筛选和分类计数
  -> EntryListView 列表、section 标题和分类 chip

[JournalEntry]
  -> JournalListOverviewSnapshot 通过 JournalEntryBodyMetrics 单轮轻量派生总篇数、总词数、连续天数和概览洞察
  -> EntryListView 概览卡

[JournalEntry]
  -> JournalStatistics 对已倒序输入跳过重复排序，每篇日记构造一次 JournalEntryBodyMetrics 并单轮聚合
  -> 总篇数、总词数、连续天数、7 天趋势、7 天趋势最大词数、分类分布、心情分布、分布最大值、主导分类/心情、小节覆盖率
  -> EntryListView 概览卡片 / StatisticsDashboardView
```

## 2. 当前核心执行流

### 2.1 启动与加载

1. `MDJournalApp` 通过 App 级 `@StateObject` 初始化共享 `JournalStore`。
2. `MDJournalApp` 创建主 `WindowGroup` 并把 `JournalStore` 注入 `ContentView`。
3. Mac Catalyst 下额外注册“统计”窗口 scene，读取同一个 `JournalStore.entries`。
4. `JournalStore.init` 定位 Documents 目录下的 `md-journal-entries.json`。
5. 若文件不存在，创建 `JournalEntry.starterEntry()` 并保存。
6. 若文件存在，使用 ISO8601 日期策略解码 `[JournalEntry]`。
7. 解码后按 `createdAt` 倒序排序。
8. `ContentView.onAppear` 选择第一篇日记。

### 2.2 创建日记

1. 用户点击列表工具栏“新建”或空状态“写一篇”。
2. `ContentView.createEntry()` 调用 `JournalStore.createEntry()`。
3. `JournalStore` 创建默认日记，正文包含三个 `###` 小节。
4. 新日记插入 `entries` 首位并保存到本地 JSON。
5. `ContentView` 将 `selectedEntryID` 切到新日记。

### 2.3 编辑与保存

1. `ContentView.selectedEntryBinding` 为当前日记生成 `Binding<JournalEntry>`。
2. `EntryEditorView` 通过 binding 编辑标题、日期、分类、心情和正文。
3. `EntryEditorView` 头部直接使用 `JournalEntryBodyMetrics` 展示词数和 `###` 小节概览，不为头部生成未展示的正文 excerpt；小节概览在横向滚动中懒加载离屏卡片。
4. 正文编辑控件由 `MarkdownBodyTextView` 包装 `UITextView` 提供，SwiftUI 仍通过 binding 持有正文文本，同时同步当前光标/选区；正文 placeholder 使用非分配空白判断，避免长文输入重渲染时创建临时 trimmed 字符串。
5. `MarkdownBodyTextView` 会配置正文输入 traits，禁用智能引号、智能破折号和智能插入删除，避免系统自动改写 Markdown 标记。
6. 用户在 Markdown 无序列表、待办、引用或有序列表中按回车时，`MarkdownBodyTextView` 调用 `MarkdownLineContinuation`；非空项续写同缩进前缀，有序列表会递增编号，空项退出当前结构，IME marked text 或普通输入继续走系统默认行为。
7. 用户在正文中按 Tab 或 Shift-Tab 时，`MarkdownBodyTextView` 调用 `MarkdownLineIndentation`；当前行或多行选区会按两个空格缩进，反缩进会删除一个 tab 或最多两个行首空格。
8. Mac Catalyst “写作”菜单或写作工具栏触发 `EntryEditorView.focusWriting()` 时，编辑器会切回编辑模式并聚焦正文；宽屏下同时隐藏右侧预览栏，让正文获得更多空间并停止该栏实时预览渲染。
9. Mac Catalyst “写作”菜单或写作工具栏触发 `EntryEditorView.applyIndentation(_:)` 时，编辑器会先切回编辑模式并聚焦正文，再复用 `MarkdownLineIndentation` 对当前行或多行选区增加缩进或减少缩进。
10. `MarkdownToolbar`、“插入 Markdown”菜单或 Mac Catalyst 写作工具栏触发 `EntryEditorView.insertSnippet(_:)`，片段包含小节、加粗、斜体、引用、无序列表、有序列表、待办、代码和分割线。
11. `EntryEditorView.insertSnippet(_:)` 调用 `MarkdownSnippetInsertion`，按当前光标插入片段，或按选区包裹/逐行转换文本；引用、无序列表、待办和有序列表会跳过选区里的空白行，有序列表只对非空行从 `1. ` 开始连续编号。
12. 若窄屏当前处于预览模式，片段插入、写作缩进命令或专注写作命令会先切回编辑模式并重新聚焦正文。
13. binding setter 调用 `JournalStore.update(_:)`。
14. `JournalStore.update` 更新 `updatedAt`、替换数组中的日记，并安排短延迟保存；仅当 `createdAt` 改变时重新排序。
15. 连续编辑会合并为一次 JSON 写盘；内存中的 `entries` 始终即时更新。
16. 应用进入 inactive/background 时，`ContentView` 调用 `JournalStore.flushPendingSave()` 立即写入待保存变更。
17. 保存失败时设置 `errorMessage`。
18. `ContentView` 通过 alert 展示保存或读取错误。

### 2.4 列表、筛选与删除

1. `EntryListView` 接收 `entries` 和 `selection`。
2. `JournalListOverviewSnapshot` 用 `entries` 和 `JournalEntryBodyMetrics` 单轮派生列表概览卡需要的总篇数、总词数、连续天数和洞察文案，不构造完整统计看板或正文摘要。
3. `JournalEntryListSnapshot` 用当前搜索文本和选中分类对 `entries` 做单次派生。
4. 搜索文本先 trim，非空时匹配标题、正文、分类、心情。
5. 分类芯片通过 `selectedCategory` 过滤列表，chip 数量保持基于全部 entries 的分类分布。
6. `EntryListView` 使用列表快照渲染过滤结果、section 标题和分类计数，使用概览快照渲染顶部概览卡。
7. `EntryRowView` 单次构造 `JournalEntryBodySummary`，展示分类、心情、日期、摘要、词数、小节数和小节标题。
8. 用户滑动删除或在 Mac Catalyst 下右键删除时调用 `ContentView.deleteEntry(_:)`。
9. `JournalStore.delete(_:)` 从数组移除日记并保存。
10. `ContentView.repairSelection` 确保选中项仍然有效。

### 2.5 Markdown 预览

1. `EntryEditorView` 在窄屏用 segmented picker 切换编辑和预览。
2. 宽度大于等于 `820` pt 时，编辑和预览左右分栏展示；Mac Catalyst 写作工具栏可隐藏或显示右侧预览栏，让正文编辑区获得更宽空间。
3. `MarkdownPreviewView` 调用 `MarkdownBlockParser.parseDocument(_:)` 获取单次解析结果。
4. `MarkdownPreviewView` 在同一次渲染中只派生一次 `shouldUseSectionGroups`，同时用于预览间距和普通/小节分组渲染分支。
5. 如果解析结果存在非开篇 `###` 分组，则按 `MarkdownSectionGroup` 渲染小节卡片。
6. 否则按普通块序列渲染。
7. 普通块、小节内块、无序列表、有序列表和待办列表使用索引迭代驱动 `ForEach`，避免在实时预览重渲染时为 `enumerated()` 结果创建临时数组。
8. 普通块支持标题、段落、引用、无序列表、有序列表、待办、代码块和分割线；有序列表只识别 leading whitespace trim 后的 `数字. `，并保留用户输入编号显示。
9. 内联 Markdown 通过 `AttributedString(markdown:)` 做轻量渲染。

### 2.6 统计看板

1. 用户点击列表工具栏“统计”。
2. `EntryListView` 通过 closure 请求 `ContentView` 显示统计，Mac Catalyst 下也可从“日记”菜单触发。
3. iOS/iPadOS 下，`ContentView` 以 sheet 形式打开 `StatisticsDashboardView`。
4. Mac Catalyst 下，`ContentView` 调用 `openWindow(id:)` 打开独立“统计”窗口。
5. `StatisticsDashboardView` 用当前 `entries` 构造一次 `JournalStatistics` 并传给子视图。
6. `JournalStatistics` 先检查输入是否已按 `createdAt` 倒序；常见的 `JournalStore.entries` 主路径直接复用输入数组，只有乱序输入才回退排序。
7. `JournalStatistics` 对每篇日记只构造一次 `JournalEntryBodyMetrics`，单轮聚合总篇数、总词数、平均词数、小节覆盖率、连续天数、本周数据、分类分布、心情分布、分布最大 entry count、主导分类/心情、最近 7 天趋势和趋势最大词数，不为统计路径生成正文摘要。
8. 宽度大于等于 `820` pt 时使用两列布局，否则使用单列滚动布局。
9. 独立统计窗口复用 App 级 `JournalStore`，只读展示当前日记数组，不新增第二套加载或保存路径。

### 2.7 Mac Catalyst 菜单命令

1. `MDJournalApp` 在 scene level 注册“日记”、“写作”和“插入 Markdown”菜单。
2. `ContentView` 通过 focused scene value 暴露新建日记和显示统计两个动作。
3. 菜单“新建日记”调用 `ContentView.createEntry()`，并承载 `⌘N` 快捷键。
4. 菜单“显示统计”调用 `ContentView.showStatistics()`；Mac Catalyst 下打开独立统计窗口，iOS/iPadOS 下复用统计 sheet。
5. `EntryEditorView` 通过 focused scene value 暴露 Markdown 片段插入动作。
6. “插入 Markdown”菜单遍历 `MarkdownSnippet.allCases`，用 `⌘⌥` 组合键插入对应片段，其中 `⌘⌥O` 插入有序列表。
7. `EntryEditorView` 通过 focused scene value 暴露聚焦正文、专注写作、增加/减少缩进和显示/隐藏预览动作。
8. “写作”菜单遍历 `EditorWritingCommand.allCases`，为聚焦正文、专注写作、增加缩进、减少缩进和显示/隐藏预览提供桌面菜单与快捷键入口。
9. Mac Catalyst 写作工具栏提供聚焦正文、专注写作、增加缩进、减少缩进、插入 Markdown 和显示/隐藏预览的可见入口；写作工具栏 hover 提示复用 `EditorWritingCommandShortcut` 显示对应 `⌘⌥` 快捷键；专注写作会隐藏宽屏预览栏并聚焦正文，缩进入口复用 `MarkdownLineIndentation`，插入 Markdown 与正文工具栏、菜单共用同一套光标/选区插入规则。
10. 工具栏新建、统计和 Markdown 快捷按钮继续保留，作为非菜单的可见入口。

### 2.8 Mac Catalyst 本地构建运行入口

1. 人工或 Codex 桌面点击 `Run` action 时，执行 `./script/build_and_run.sh`。
2. 脚本先停止已有 `MDJournal` 进程，避免旧 app 继续占用前台。
3. 脚本用 `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` 构建 `MDJournal.xcodeproj` 的 `MDJournal` scheme。
4. 构建目标固定为 `generic/platform=macOS,variant=Mac Catalyst`。
5. DerivedData 固定写入 `/private/tmp/mdjournal-build-and-run`，不依赖默认 home DerivedData。
6. 构建成功后脚本确认 `MDJournal.app` 和 `Contents/MacOS/MDJournal` 存在。
7. 默认模式用 `/usr/bin/open -n` 启动最新 Mac Catalyst app。
8. `--verify` 模式启动后用 `pgrep -x MDJournal` 确认进程存在；`--debug`、`--logs`、`--telemetry` 分别提供 lldb 和 unified logging 入口。
9. 该脚本只负责本地构建与运行，不读写日记 JSON，不改变 SwiftUI 状态流或持久化规则。

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

输出：展示标题、正文派生摘要、词数、`###` 小节、Markdown 分享文档。

禁止：新增字段时破坏旧 JSON 解码；随意改变分类、心情 rawValue；把临时派生摘要写入 JSON。

### 4.2 `JournalEntryBodyMetrics`

职责：在内存中把正文单次轻量派生为词数、`###` 小节和小节数。

输入：`JournalEntry.body`。

输出：`wordCount`、`sections`、`sectionCount`。

禁止：作为 `JournalEntry` 的持久化字段写入 JSON；绕过 `JournalSection.extract(from:)` 另写一套小节识别规则；改变旧有词数或小节识别语义。

### 4.3 `JournalEntryBodySummary`

职责：在内存中把正文单次派生为摘要，并复用 `JournalEntryBodyMetrics` 提供词数、`###` 小节和小节数。

输入：`JournalEntry.body`。

输出：`excerpt`、`metrics`、`wordCount`、`sections`、`sectionCount`。

禁止：作为 `JournalEntry` 的持久化字段写入 JSON；另写一套词数或小节识别规则；改变旧有摘要、词数或小节识别语义。

### 4.4 `JournalEntryListSnapshot`

职责：把 `[JournalEntry]`、搜索文本和选中分类转成列表展示所需的过滤结果、总数和分类计数。

输入：日记数组、搜索文本、选中分类。

输出：过滤后的日记、分类计数、section 标题。

禁止：写入 JSON；持有缓存状态；改变搜索、分类筛选或分类计数语义。

### 4.5 `JournalStore`

职责：加载、保存、创建、更新、删除和按需排序日记。

输入：用户操作产生的日记变更。

输出：`@Published entries`、`errorMessage`、本地 JSON 文件。

禁止：在其他模块绕过它直接改写日记集合或本地文件。

### 4.6 `MarkdownBlockParser`

职责：把轻量 Markdown 字符串解析成块和 `###` 小节组。

输入：`JournalEntry.body`。

输出：`MarkdownParseResult`、`[MarkdownBlock]`、`[MarkdownSectionGroup]`。

禁止：在未更新 README、测试规范和 flow 文档的情况下改变现有语法含义。

### 4.7 `JournalStatistics`

职责：把 `[JournalEntry]` 转成统计看板所需数据。

输入：日记数组、日历、当前时间。

输出：总量、平均值、连续天数、分布、分布最大值、主导分类/心情、7 天趋势、趋势最大词数和洞察文案。

禁止：在视图层复制统计逻辑。

### 4.8 `JournalListOverviewSnapshot`

职责：把 `[JournalEntry]` 转成列表首页概览卡所需的轻量统计数据。

输入：日记数组、日历、当前时间。

输出：总篇数、总词数、最近连续天数、列表概览洞察、主导分类和小节覆盖率。

禁止：计算完整统计看板的趋势、心情分布、最长连续天数或 7 天图表数据；把派生结果写入 JSON。

### 4.9 `EditorWritingCommand`

职责：集中描述 Mac Catalyst 写作菜单命令、标题、图标、快捷键映射和可选缩进方向。

输入：写作命令枚举值。

输出：菜单标题、系统图标、键盘快捷键、专注写作和缩进命令的路由依据。

禁止：直接修改日记正文、持久化数据或 Markdown 片段内容；与已有新建和 Markdown 片段快捷键重复。

### 4.10 `MarkdownSnippetInsertion`

职责：根据正文、Markdown 片段和 UTF-16 选区生成新的正文和插入后的选区；逐行片段会跳过选区里的空白行，有序列表片段会把非空选中行转换为从 `1. ` 开始连续编号的行。

输入：`JournalEntry.body`、`MarkdownSnippet`、正文 `NSRange` 光标/选区。

输出：更新后的正文和新的 `NSRange`。

禁止：访问视图状态、读写 JSON、改变 `JournalStore` 保存链路或承担 Markdown 预览解析。

### 4.11 `MarkdownLineContinuation`

职责：根据正文、回车 replacement text 和 UTF-16 光标判断是否续写或退出 Markdown 无序列表、待办、引用和有序列表。

输入：`JournalEntry.body`、正文 `NSRange` 光标、replacement text。

输出：可选的更新后正文和新的 `NSRange`；非无序列表/待办/引用/有序列表、非回车、非折叠选区或 fenced code block 内返回空结果。

禁止：访问 UIKit、SwiftUI、JSON、`JournalStore` 或 Markdown 预览解析。

### 4.12 `MarkdownLineIndentation`

职责：根据正文、Tab / Shift-Tab 方向和 UTF-16 光标/选区生成行级缩进或反缩进结果。

输入：`JournalEntry.body`、正文 `NSRange` 光标/选区、缩进方向。

输出：可选的更新后正文和新的 `NSRange`；无可反缩进行返回空结果。

禁止：访问 UIKit、SwiftUI、JSON、`JournalStore` 或 Markdown 预览解析；改变缩进以外的正文内容。

### 4.13 `MarkdownBodyTextView`

职责：用最小 `UITextView` bridge 提供正文编辑、Markdown 安全输入 traits、光标/选区同步、焦点同步、回车续写规则入口和 Tab / Shift-Tab 行缩进入口。

输入：正文 binding、选区 binding、焦点 binding。

输出：用户输入后的正文、当前光标/选区、焦点状态，以及稳定的 Markdown 输入 traits。

禁止：持有第二套正文状态；把 Markdown 字符串规则写进 delegate；绕过 `EntryEditorView` 或 `JournalStore`；关闭 IME 或破坏中文输入。

### 4.14 SwiftUI Views

职责：展示状态、收集用户输入、调用上层 closure 或 binding。

输入：`entries`、`Binding<JournalEntry>`、筛选状态、布局宽度。

输出：界面、用户事件、分享 sheet、iOS/iPadOS 统计 sheet、Mac Catalyst 统计窗口。

禁止：把持久化、复杂统计或 Markdown 解析业务塞进视图。

## 5. 关键边界

- 数据层：`JournalStore` + `JournalEntry` + JSON 编解码。
- 模型/规则层：`JournalEntryBodyMetrics`、`JournalEntryBodySummary`、`JournalEntryListSnapshot`、`JournalListOverviewSnapshot`、`MarkdownBlockParser`、`JournalStatistics`、日期格式化、Markdown snippet、`MarkdownSnippetInsertion`、`MarkdownLineContinuation`、`MarkdownLineIndentation` 和 `EditorWritingCommand`。
- UI 层：`ContentView`、列表、编辑器、预览、统计、空状态、工具栏。
- 工程配置：`MDJournal.xcodeproj/project.pbxproj` 控制 target、bundle id、iOS 版本、Mac Catalyst 支持和方向。
- CI 层：`.github/workflows/ci-results.yml` 负责 main push 后的 iOS build、Mac Catalyst build、XCTest 云端重验证和结果包上传。
- 本地运行辅助层：`script/build_and_run.sh` 和 `.codex/environments/environment.toml` 负责 Mac Catalyst 一键构建/运行。
- 文档与流程层：`AGENTS.md`、`update_log.md`、`md/test/test.md`、`md/flow/`、`md/prompt/`。
- 版本提交层：Agent B 在 `main` 上提交并推送；Agent C 基于 `origin/main` 最新结果包验收。

## 6. 用户入口

- App 启动后进入 `ContentView`。
- 左侧/主列表：查看、搜索、筛选、新建、删除、打开统计。
- 详情编辑器：修改标题、日期、分类、心情、正文，按光标/选区插入 Markdown 片段，分享文档。
- 预览：窄屏切换查看，宽屏与编辑器并排查看；Mac Catalyst 可从写作工具栏或“写作”菜单隐藏/显示预览栏，也可通过专注写作直接隐藏宽屏预览栏并聚焦正文。
- 统计看板：从列表工具栏打开。
- Mac Catalyst：在 macOS 上运行同一 app target，列表支持右键删除，“日记”菜单支持新建和显示统计，“写作”菜单支持聚焦正文、专注写作、增加缩进、减少缩进和显示/隐藏预览，`⌘N` 新建由菜单命令承载，统计以独立窗口展示；“插入 Markdown”菜单和写作工具栏支持按光标/选区插入常用 Markdown 片段，包含有序列表入口。
- 本地 Mac 运行：使用 `./script/build_and_run.sh` 或 Codex `Run` action 构建并启动 Mac Catalyst app。

## 7. 前端 / 数据层 / 模型层 / 测试层关系

- 前端只通过 binding、closure 和 `JournalStore` 暴露的操作改变状态。
- 数据层负责本地文件读写和错误上报。
- 模型层负责兼容解码和派生属性。
- 规则层负责 Markdown 解析与统计。
- 测试层当前包含本地轻量检查、本机可选 Mac Catalyst build、`MDJournalTests` 核心规则、列表快照、列表概览轻量统计快照、Markdown 片段插入规则、Markdown 无序列表/待办/引用/有序列表回车续写规则、Markdown 行缩进规则、写作命令快捷键与 `JournalStore` 写入节流和按需排序 XCTest，以及 GitHub Actions generic iOS build、Mac Catalyst build 和 iOS Simulator XCTest 重验证。

## 8. 已确认的铁律

- 本地 JSON 保存不能静默失败，错误必须进入 `errorMessage`。
- 编辑过程可以节流写盘，但内存状态必须即时更新，应用离开活跃态前必须 flush 待保存变更；`JournalStore.update(_:)` 只在 `createdAt` 改变时重排列表。
- Markdown 预览应复用单次解析结果，避免同一渲染周期重复解析正文。
- 正文词数和 `###` 小节可用 `JournalEntryBodyMetrics` 轻量派生复用；编辑器头部、统计和列表概览在不需要摘要时必须优先使用 metrics；正文摘要可用 `JournalEntryBodySummary` 派生且必须复用 metrics；列表过滤和分类计数可用 `JournalEntryListSnapshot` 单次派生复用；列表首页概览可用 `JournalListOverviewSnapshot` 轻量派生，避免为概览卡构造完整统计看板或正文摘要；这些都只能是非持久化快照，不能改变 JSON schema。
- Mac Catalyst 的核心创建、统计、写作聚焦、预览栏切换和 Markdown 片段插入动作应同时有可见 UI 与菜单入口；统计窗口必须复用同一个 `JournalStore`，重要快捷键不能重复注册；Markdown 片段插入规则必须可单元测试，不能依赖 UIKit delegate 隐式行为。
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

- 扩展 `MDJournalTests` 覆盖更多 Markdown 边界、列表派生边界和数据迁移风险。
- 增强 Markdown 预览语法，但保持轻量并同步测试。
- 继续改善编辑器体验，例如更细的 undo 行为、选区保持或更多 Markdown 边界规则。
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
