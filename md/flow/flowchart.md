# 项目流程图

本文用 Mermaid 图描述 MD Journal 当前真实核心数据流、执行流和多 Agent 云端迭代流。每张图前都有通俗读图说明，方便人工快速判断系统怎么运转。

## 核心逻辑图

读图说明：从左到右看，用户在 SwiftUI 界面操作日记；状态变化进入 `JournalStore`；数据保存到本地 JSON；同一份日记数据再派生出列表、编辑器、预览和统计。图中每个节点都对应当前项目里的真实模块。

```mermaid
flowchart TD
  Platform["iOS / iPadOS / Mac Catalyst"] --> User["用户操作：新建、编辑、删除、搜索、筛选、分享"]
  Platform --> Menu["Mac Catalyst 菜单：新建日记、显示统计、写作、插入 Markdown"]
  Platform --> LocalRun["本地 Mac 运行：Codex Run action / script/build_and_run.sh"]
  LocalRun --> CatalystBuild["xcodebuild：构建 Mac Catalyst Debug app"]
  CatalystBuild --> Platform
  User --> CV["ContentView：维护选中日记和导航"]
  Menu --> CV
  CV --> List["EntryListView：列表、搜索、分类筛选、统计入口"]
  CV --> Editor["EntryEditorView：标题、日期、分类、心情、正文编辑"]
  Menu --> SnippetCommand["插入 Markdown 命令：focused value 路由到当前编辑器"]
  SnippetCommand --> Editor
  Menu --> WritingCommand["写作命令：聚焦正文、专注写作、增加/减少缩进、显示/隐藏预览；工具栏提示显示快捷键"]
  WritingCommand --> Editor
  Editor --> BodyTextView["MarkdownBodyTextView：UITextView bridge，配置 Markdown 输入 traits，同步正文、光标/选区和焦点，承载 Tab / Shift-Tab；placeholder 非分配判断"]
  Editor --> WritingIndent["EntryEditorView.applyIndentation：菜单/工具栏缩进入口"]
  WritingIndent --> LineIndentation
  BodyTextView --> LineContinuation["MarkdownLineContinuation：无序列表/待办/引用/有序列表回车续写或退出"]
  LineContinuation --> Binding
  BodyTextView --> LineIndentation["MarkdownLineIndentation：当前行或多行选区缩进/反缩进，删除 tab 或最多两个行首空格"]
  LineIndentation --> Binding
  BodyTextView --> SnippetInsertion["MarkdownSnippetInsertion：按光标/选区生成 Markdown 片段替换结果，跳过选区空白行，含有序列表编号"]
  SnippetInsertion --> Binding
  Editor --> PreviewToggle["Mac Catalyst 宽屏预览栏显示/隐藏与专注写作"]
  PreviewToggle --> Preview
  List --> CreateDelete["创建/删除请求：滑动或右键删除都通过 closure 回到 ContentView"]
  Editor --> Binding["Binding<JournalEntry>：把编辑结果写回 ContentView"]
  CreateDelete --> Store["JournalStore：唯一日记集合修改入口，按 createdAt 变化排序"]
  Binding --> Store
  Store --> Model["JournalEntry：日记模型、兼容解码、展示标题"]
  Store --> JSON["Documents/md-journal-entries.json：本地 JSON 持久化"]
  JSON --> Store
  Model --> MetricsNode["JournalEntryBodyMetrics：非持久化词数、### 小节"]
  Model --> Summary["JournalEntryBodySummary：单次扫描清理 Markdown 标记，生成非持久化摘要并复用 metrics"]
  Store --> ListSnapshot["JournalEntryListSnapshot：单次派生搜索、分类筛选、分类计数"]
  ListSnapshot --> List
  Store --> ListOverview["JournalListOverviewSnapshot：通过 metrics 轻量派生总篇数、总词数、连续天数和洞察"]
  ListOverview --> List
  Model --> Parser["MarkdownBlockParser.parseDocument：单次解析块级 Markdown、有序列表和 ### 小节"]
  Parser --> Preview["MarkdownPreviewView：复用解析结果和小节分组判断，用索引迭代渲染普通预览、列表项或小节分组预览"]
  Store --> Stats["JournalStatistics：已倒序输入跳过重复排序，每篇一次 metrics 派生，单轮聚合统计、分布最大值、主导项和趋势最大词数"]
  CV --> StatsSurface["统计展示：iOS/iPadOS sheet，Mac Catalyst 独立窗口"]
  StatsSurface --> Dashboard["StatisticsDashboardView：统计看板，宽屏两列/窄屏单列"]
  Stats --> Dashboard
  Summary --> Row["EntryRowView：列表卡片、分类心情、摘要、小节条"]
  Summary --> EditorStats["EntryEditorView：头部词数和懒加载小节概览"]
  MetricsNode --> Stats
  MetricsNode --> ListOverview
  Store --> Error["errorMessage：读取/保存失败"]
  Error --> Alert["ContentView Alert：展示本地数据错误"]
```

## 执行流图

读图说明：这张图按时间顺序展示 App 启动、加载、创建、编辑、保存和错误处理。重点看 `JournalStore`：它是读写本地数据的唯一中心。

```mermaid
flowchart TD
  App["MDJournalApp 启动"] --> InitStore["初始化 App 级 @StateObject JournalStore"]
  InitStore --> Scenes["创建主窗口；Mac Catalyst 额外注册统计窗口"]
  Scenes --> Content["创建 ContentView 并注入 JournalStore"]
  InitStore --> Locate["定位 Documents/md-journal-entries.json"]
  Locate --> Exists{"本地 JSON 是否存在？"}
  Exists -- "不存在" --> Starter["创建 starterEntry 默认日记"]
  Starter --> SaveA["保存 JSON"]
  Exists -- "存在" --> Decode["JSONDecoder ISO8601 解码 [JournalEntry]"]
  Decode --> SortA["按 createdAt 倒序排序"]
  SaveA --> Render["SwiftUI 渲染列表和详情"]
  SortA --> Render
  Render --> Select["ContentView 选择第一篇或修复选中项"]
  Select --> Edit{"用户操作类型"}
  Edit -- "新建" --> Create["JournalStore.createEntry 插入默认 ### 模板"]
  Edit -- "编辑" --> Update["JournalStore.update 更新时间并替换日记"]
  Edit -- "删除" --> Delete["JournalStore.delete 移除日记"]
  Create --> SortSave["排序并立即保存 JSON"]
  Update --> DebouncedSave["仅 createdAt 改变时排序，并安排短延迟保存"]
  DebouncedSave --> Flush["连续编辑合并写盘；inactive/background 时 flush"]
  Flush --> SortSave
  Delete --> SortSave
  SortSave --> OK{"保存是否成功？"}
  OK -- "成功" --> Render
  OK -- "失败" --> SaveError["设置 errorMessage"]
  SaveError --> Alert["ContentView 弹出错误提示"]
```

## 本地 Mac 运行图

读图说明：这张图展示 Codex Run action 和 `script/build_and_run.sh` 如何构建并启动现有 Mac Catalyst app。它是本地运行辅助链路，不改变 app 内部数据流。

```mermaid
flowchart TD
  RunAction["Codex Run action"] --> Script["script/build_and_run.sh"]
  Terminal["终端执行脚本"] --> Script
  Script --> KillOld["pkill -x MDJournal：停止旧进程"]
  KillOld --> Xcodebuild["xcodebuild：MDJournal scheme / Mac Catalyst Debug"]
  Xcodebuild --> DerivedData["/private/tmp/mdjournal-build-and-run"]
  DerivedData --> Bundle["MDJournal.app"]
  Bundle --> Open["open -n MDJournal.app"]
  Open --> Verify{"--verify 模式？"}
  Verify -- "是" --> Pgrep["pgrep -x MDJournal"]
  Verify -- "否" --> App["Mac Catalyst app 启动"]
  Pgrep --> App
  Script --> Debug["--debug：lldb app binary"]
  Script --> Logs["--logs：log stream process == MDJournal"]
  Script --> Telemetry["--telemetry：log stream subsystem == com.codex.mdjournal.mac"]
```

## Markdown 与统计派生图

读图说明：正文和日记数组不会直接变成预览或统计，先经过解析器和统计器派生。后续改 Markdown 或统计口径时，应优先检查这张图对应的模块。

```mermaid
flowchart LR
  Body["JournalEntry.body 正文"] --> MetricsNode2["JournalEntryBodyMetrics：非持久化词数和 ### 小节"]
  Body --> Summary["JournalEntryBodySummary：单次扫描清理 Markdown 标记，摘要并复用 metrics"]
  Body --> BodyText["MarkdownBodyTextView：正文编辑、输入 traits 和 UTF-16 光标/选区同步"]
  BodyText --> ContinueRule["MarkdownLineContinuation：无序列表/待办/引用/有序列表回车续写"]
  ContinueRule --> Body
  BodyText --> IndentRule["MarkdownLineIndentation：Tab / Shift-Tab 行缩进，反缩进删除 tab 或最多两个行首空格"]
  IndentRule --> Body
  BodyText --> InsertRule["MarkdownSnippetInsertion：空选区插入、选区包裹、逐行前缀、空白行跳过和有序列表编号"]
  InsertRule --> Body
  MetricsNode2 --> MetricsData["词数、### 小节、小节数"]
  Summary --> Excerpt["摘要 + metrics"]
  Excerpt --> RowEditor["列表卡片复用"]
  MetricsData --> Statistics["JournalStatistics：已倒序输入跳过重复排序，每篇一次 metrics，单轮聚合"]
  MetricsData --> EditorHeader["EntryEditorView 头部：词数和 ### 小节懒加载概览"]
  Body --> Parse["MarkdownBlockParser.parseDocument"]
  Parse --> Result["MarkdownParseResult：blocks + sectionGroups"]
  Result --> Blocks["MarkdownBlock：标题、段落、引用、无序列表、有序列表、待办、代码、分割线"]
  Blocks --> Preview["MarkdownPreviewView 索引迭代普通块和列表项渲染"]
  Result --> Sections["MarkdownSectionGroup：### 小节分组"]
  Sections --> SectionPreview["小节卡片预览"]
  Entries["[JournalEntry] 日记数组"] --> Statistics
  Entries --> ListSnapshot2["JournalEntryListSnapshot：搜索、分类筛选、分类计数"]
  ListSnapshot2 --> ListView["EntryListView：过滤列表、section 标题、分类 chip"]
  Entries --> ListOverview2["JournalListOverviewSnapshot：列表概览轻量统计"]
  MetricsData --> ListOverview2
  ListOverview2 --> ListView
  Statistics --> Metrics["总篇数、总词数、平均值、连续天数"]
  Statistics --> Distributions["分类分布、心情分布、分布最大值和主导项"]
  Statistics --> Trend["最近 7 天趋势和趋势最大词数"]
  Statistics --> Coverage["### 小节覆盖率"]
  Metrics --> Dashboard["统计看板"]
  Distributions --> Dashboard
  Trend --> Dashboard
  Coverage --> Dashboard
```

## Agent X 主控云端迭代流程图

读图说明：人工用 `agentx:` 给出总目标 X；Agent X 只做主控调度，把总目标拆成有限小轮次。每轮仍由 Agent A 写提示词、Agent B 在 `main` 上实现并 push、GitHub Actions 生成未加密 artifact、Agent C 下载并核对 manifest、日志和摘要。Agent X 根据 Agent C 结果判断继续下一轮、退回修复、暂停等待人工或宣布总目标完成。

```mermaid
flowchart TD
  Human["人工：给 Agent X 总目标 X、限制、验收标准"] --> AgentXPlan["Agent X：拆分有限轮次目标"]
  AgentXPlan --> RoundGoal["当前轮次：目标、非目标、关键文件、验证要求"]
  RoundGoal --> Context["读取 AGENTS、update_log、flow、test、prompt README 和相关文件"]
  Context --> AgentA["Agent A：分析轮次目标并写版本化提示词"]
  AgentA --> Prompt["md/prompt/vX（阶段）/vX.Y（任务）.md"]
  Prompt --> AgentBStart["Agent B：同步最新 origin/main"]
  AgentBStart --> MainOK{"当前是否为 main 且可同步 origin/main？"}
  MainOK -- "否" --> Blocked["记录阻塞：缺少远端、权限或工作区冲突"]
  Blocked --> Pause
  MainOK -- "是" --> AgentBWork["Agent B：小步实现并跑本地轻量检查"]
  AgentBWork --> LocalTests["本地轻量检查 + 可用时 XCTest 尝试"]
  LocalTests --> Commit["git commit：只提交本轮相关文件"]
  Commit --> Push["git push origin main"]
  Push --> Actions["GitHub Actions：ci-results workflow"]
  Actions --> Checks["静态检查 + generic iOS Debug build + Mac Catalyst build + XCTest"]
  Checks --> Artifact["上传未加密 CI 结果包"]
  Artifact --> AgentCDownload["Agent C：gh auth login 后下载 artifact"]
  AgentCDownload --> Verify["核对 manifest、commitSha、runId、runAttempt、JUnit、日志"]
  Verify --> CDecision{"Agent C artifact 验收是否通过？"}
  CDecision -- "不通过" --> AgentXFail["Agent X 判断：退回修复或暂停"]
  AgentXFail --> CanFix{"问题是否可由追加修复 commit 解决？"}
  CanFix -- "是" --> ReturnB["退回 Agent B：列出问题"]
  ReturnB --> FixCommit["Agent B 在 main 上追加修复 commit"]
  FixCommit --> Push
  CanFix -- "否" --> Pause["暂停：等待人工确认、权限、账号、密钥或冲突处理"]
  CDecision -- "通过" --> UpdateDocs["确认 flow、flowchart、test、README、update_log 已同步"]
  UpdateDocs --> AgentXNext{"Agent X 判断总目标状态"}
  AgentXNext -- "继续下一轮" --> NextRound["生成下一轮小目标"]
  NextRound --> RoundGoal
  AgentXNext -- "暂停" --> Pause
  AgentXNext -- "完成" --> Done["宣布总目标完成并汇总版本、commit、run、artifact"]
```

## CI 结果包验收图

读图说明：Agent C 不能只看文字汇报，必须下载最新 `origin/main` 对应 run 的 artifact，并核对结果包里的机器可读信息。

```mermaid
flowchart LR
  OriginMain["origin/main 最新 commit"] --> Run["GitHub Actions 最新 run"]
  Run --> Artifact["未加密 artifact"]
  Artifact --> Manifest["ci-artifact-manifest.json"]
  Artifact --> JUnit["junit.xml"]
  Artifact --> BuildLog["xcodebuild.log"]
  Artifact --> CatalystLog["maccatalyst-build.log"]
  Artifact --> TestLog["xctest.log"]
  Artifact --> Summary["ci-failure-summary.md"]
  Artifact --> XCResult["MDJournal.xcresult（可用时）"]
  Artifact --> CatalystResult["MDJournalMacCatalyst.xcresult（可用时）"]
  Artifact --> TestResult["MDJournalTests.xcresult（可用时）"]
  Manifest --> Match{"branch、commitSha、runId、runAttempt 是否匹配？"}
  JUnit --> Outcome{"检查和构建是否通过？"}
  BuildLog --> Outcome
  CatalystLog --> Outcome
  TestLog --> Outcome
  Summary --> Outcome
  CatalystResult --> Outcome
  Match --> Accept{"Agent C 结论"}
  Outcome --> Accept
  Accept -- "通过" --> Record["记录版本、artifact 名称和遗留事项"]
  Accept -- "不通过" --> Repair["退回 Agent B 追加修复 commit"]
```
