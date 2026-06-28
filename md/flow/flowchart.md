# 项目流程图

本文用 Mermaid 图描述 MD Journal 当前真实核心数据流、执行流和多 Agent 迭代流。每张图前都有通俗读图说明，方便人工快速判断系统怎么运转。

## 核心逻辑图

读图说明：从左到右看，用户在 SwiftUI 界面操作日记；状态变化进入 `JournalStore`；数据保存到本地 JSON；同一份日记数据再派生出列表、编辑器、预览和统计。图中每个节点都对应当前项目里的真实模块。

```mermaid
flowchart TD
  User["用户操作：新建、编辑、删除、搜索、筛选、分享"] --> CV["ContentView：维护选中日记和导航"]
  CV --> List["EntryListView：列表、搜索、分类筛选、统计入口"]
  CV --> Editor["EntryEditorView：标题、日期、分类、心情、正文编辑"]
  List --> CreateDelete["创建/删除请求：通过 closure 回到 ContentView"]
  Editor --> Binding["Binding<JournalEntry>：把编辑结果写回 ContentView"]
  CreateDelete --> Store["JournalStore：唯一日记集合修改入口"]
  Binding --> Store
  Store --> Model["JournalEntry：日记模型、兼容解码、派生标题/摘要/词数/小节"]
  Store --> JSON["Documents/md-journal-entries.json：本地 JSON 持久化"]
  JSON --> Store
  Model --> Parser["MarkdownBlockParser：解析块级 Markdown 和 ### 小节"]
  Parser --> Preview["MarkdownPreviewView：渲染普通预览或小节分组预览"]
  Store --> Stats["JournalStatistics：计算总量、连续天数、分布、7天趋势"]
  Stats --> Dashboard["StatisticsDashboardView：统计看板，宽屏两列/窄屏单列"]
  Model --> Row["EntryRowView：列表卡片、分类心情、摘要、小节条"]
  Store --> Error["errorMessage：读取/保存失败"]
  Error --> Alert["ContentView Alert：展示本地数据错误"]
```

## 执行流图

读图说明：这张图按时间顺序展示 App 启动、加载、创建、编辑、保存和错误处理。重点看 `JournalStore`：它是读写本地数据的唯一中心。

```mermaid
flowchart TD
  App["MDJournalApp 启动"] --> Content["创建 ContentView"]
  Content --> InitStore["初始化 @StateObject JournalStore"]
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
  Create --> SortSave["排序并保存 JSON"]
  Update --> SortSave
  Delete --> SortSave
  SortSave --> OK{"保存是否成功？"}
  OK -- "成功" --> Render
  OK -- "失败" --> Error["设置 errorMessage"]
  Error --> Alert["ContentView 弹出错误提示"]
```

## Markdown 与统计派生图

读图说明：正文和日记数组不会直接变成预览或统计，先经过解析器和统计器派生。后续改 Markdown 或统计口径时，应优先检查这张图对应的模块。

```mermaid
flowchart LR
  Body["JournalEntry.body 正文"] --> Parse["MarkdownBlockParser.parse"]
  Parse --> Blocks["MarkdownBlock：标题、段落、引用、列表、待办、代码、分割线"]
  Blocks --> Preview["MarkdownPreviewView 普通块渲染"]
  Body --> Group["MarkdownBlockParser.groupedByLevelThree"]
  Group --> Sections["MarkdownSectionGroup：### 小节分组"]
  Sections --> SectionPreview["小节卡片预览"]
  Sections --> SectionSummary["列表小节摘要和小节数"]
  Entries["[JournalEntry] 日记数组"] --> Statistics["JournalStatistics"]
  Statistics --> Metrics["总篇数、总词数、平均值、连续天数"]
  Statistics --> Distributions["分类分布、心情分布"]
  Statistics --> Trend["最近 7 天趋势"]
  Statistics --> Coverage["### 小节覆盖率"]
  Metrics --> Dashboard["统计看板"]
  Distributions --> Dashboard
  Trend --> Dashboard
  Coverage --> Dashboard
```

## Agent 迭代流程图

读图说明：人工先提出目标；Agent A 只负责分析并写给 Agent B 的实现提示词；Agent B 实现和测试；Agent C 验收并更新核心逻辑文档；人工复核后进入下一轮。

```mermaid
flowchart TD
  Human["人工：提出目标、限制、验收标准"] --> Context["提供 AGENT、update_log、flow、test 和相关上下文"]
  Context --> AgentA["Agent A：分析目标，不默认写代码"]
  AgentA --> Prompt["md/prompt/vX（阶段）/vX.Y（任务）.md：详细实现提示词"]
  Prompt --> AgentB["Agent B：按提示词实现、测试、记录结果"]
  AgentB --> Diff["实际 diff、测试命令、结果、风险说明"]
  Diff --> AgentC["Agent C：验收实现、核对架构边界和测试"]
  AgentC --> FlowUpdate["更新 md/flow/flow.md 和 md/flow/flowchart.md"]
  AgentC --> LogUpdate["必要时更新 update_log.md 和 README.md"]
  FlowUpdate --> HumanReview["人工复核：通过、退回或提出下一轮目标"]
  LogUpdate --> HumanReview
  HumanReview --> Human
```
