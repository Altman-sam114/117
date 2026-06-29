# 项目核心流程文档

## 0. 一句话总览

MD Journal 的当前主链路是：用户在 SwiftUI 界面创建和编辑日记，`JournalEntry` 承载标题、正文、日期、分类和心情，`JournalStore` 负责本地 JSON 加载与保存，列表、编辑器、Markdown 预览和统计看板根据同一份日记状态实时渲染。

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
  -> MarkdownBlockParser.parse
  -> MarkdownPreviewView 渲染块级 Markdown
  -> MarkdownBlockParser.groupedByLevelThree
  -> ### 小节分组预览、日记卡片小节摘要、统计小节覆盖率

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
4. `JournalStore.update` 更新 `updatedAt`、替换数组中的日记、重新排序并保存。
5. 保存失败时设置 `errorMessage`。
6. `ContentView` 通过 alert 展示保存或读取错误。

### 2.4 列表、筛选与删除

1. `EntryListView` 接收 `entries` 和 `selection`。
2. 搜索文本匹配标题、正文、分类、心情。
3. 分类芯片通过 `selectedCategory` 过滤列表。
4. `EntryRowView` 展示分类、心情、日期、摘要、词数、小节数和小节标题。
5. 用户滑动删除时调用 `ContentView.deleteEntry(_:)`。
6. `JournalStore.delete(_:)` 从数组移除日记并保存。
7. `ContentView.repairSelection` 确保选中项仍然有效。

### 2.5 Markdown 预览

1. `EntryEditorView` 在窄屏用 segmented picker 切换编辑和预览。
2. 宽度大于等于 `820` pt 时，编辑和预览左右分栏同时展示。
3. `MarkdownPreviewView` 调用 `MarkdownBlockParser.parse` 获取块级内容。
4. 如果存在非开篇 `###` 分组，则按 `MarkdownSectionGroup` 渲染小节卡片。
5. 否则按普通块序列渲染。
6. 内联 Markdown 通过 `AttributedString(markdown:)` 做轻量渲染。

### 2.6 统计看板

1. 用户点击列表工具栏“统计”。
2. `EntryListView` 以 sheet 形式打开 `StatisticsDashboardView`。
3. `StatisticsDashboardView` 用当前 `entries` 构造 `JournalStatistics`。
4. 统计计算总篇数、总词数、平均词数、小节覆盖率、连续天数、本周数据、分类分布、心情分布和最近 7 天趋势。
5. 宽度大于等于 `820` pt 时使用两列布局，否则使用单列滚动布局。

## 3. 核心状态对象 / 模块

### 3.1 `JournalEntry`

职责：描述单篇日记和派生展示信息。

输入：标题、正文、创建时间、更新时间、分类、心情。

输出：展示标题、摘要、词数、`###` 小节、Markdown 分享文档。

禁止：新增字段时破坏旧 JSON 解码；随意改变分类、心情 rawValue。

### 3.2 `JournalStore`

职责：加载、保存、创建、更新、删除和排序日记。

输入：用户操作产生的日记变更。

输出：`@Published entries`、`errorMessage`、本地 JSON 文件。

禁止：在其他模块绕过它直接改写日记集合或本地文件。

### 3.3 `MarkdownBlockParser`

职责：把轻量 Markdown 字符串解析成块和 `###` 小节组。

输入：`JournalEntry.body`。

输出：`[MarkdownBlock]`、`[MarkdownSectionGroup]`。

禁止：在未更新 README、测试规范和 flow 文档的情况下改变现有语法含义。

### 3.4 `JournalStatistics`

职责：把 `[JournalEntry]` 转成统计看板所需数据。

输入：日记数组、日历、当前时间。

输出：总量、平均值、连续天数、分布、7 天趋势和洞察文案。

禁止：在视图层复制统计逻辑。

### 3.5 SwiftUI Views

职责：展示状态、收集用户输入、调用上层 closure 或 binding。

输入：`entries`、`Binding<JournalEntry>`、筛选状态、布局宽度。

输出：界面、用户事件、分享 sheet、统计 sheet。

禁止：把持久化、复杂统计或 Markdown 解析业务塞进视图。

## 4. 关键边界

- 数据层：`JournalStore` + `JournalEntry` + JSON 编解码。
- 模型/规则层：`MarkdownBlockParser`、`JournalStatistics`、日期格式化和 Markdown snippet。
- UI 层：`ContentView`、列表、编辑器、预览、统计、空状态、工具栏。
- 工程配置：`MDJournal.xcodeproj/project.pbxproj` 控制 target、bundle id、iOS 版本和方向。
- 文档与流程层：`AGENTS.md`、`update_log.md`、`md/test/test.md`、`md/flow/`、`md/prompt/`。
- 版本提交层：Agent C 最终验收通过后，按版本号 stage 并 git commit；验收不通过时退回 Agent B，不得提交。

## 5. 用户入口

- App 启动后进入 `ContentView`。
- 左侧/主列表：查看、搜索、筛选、新建、删除、打开统计。
- 详情编辑器：修改标题、日期、分类、心情、正文，插入 Markdown 片段，分享文档。
- 预览：窄屏切换查看，宽屏与编辑器并排查看。
- 统计看板：从列表工具栏打开。

## 6. 前端 / 数据层 / 模型层 / 测试层关系

- 前端只通过 binding、closure 和 `JournalStore` 暴露的操作改变状态。
- 数据层负责本地文件读写和错误上报。
- 模型层负责兼容解码和派生属性。
- 规则层负责 Markdown 解析与统计。
- 测试层当前以静态检查和构建为主，未来应为解析、统计、兼容解码补充 XCTest。

## 7. 已确认的铁律

- 本地 JSON 保存不能静默失败，错误必须进入 `errorMessage`。
- 旧数据缺失 `updatedAt`、`category`、`mood` 时必须能解码。
- 日记排序按 `createdAt` 倒序。
- 新建日记必须包含默认 `###` 小节模板。
- `###` 是当前小节分组的核心标记。
- iPhone 需要支持竖屏、横屏左、横屏右。
- 宽屏阈值当前为 `820` pt。
- 文档-only 变更也要至少跑 `git diff --check` 并记录结果。
- Agent C 通过才允许形成版本提交；提交说明必须包含版本号和简短工作概括。
- Agent C 不通过时必须回退给 Agent B 修复，不得提交半成品版本。

## 8. 未来扩展点

- 为 `MarkdownBlockParser`、`JournalStatistics`、`JournalEntry` 解码兼容补充 XCTest。
- 增强 Markdown 预览语法，但保持轻量并同步测试。
- 改善插入片段后的光标位置。
- 增加导入/导出或备份功能。
- 增加更可靠的模拟器或真机视觉验证流程。
- 为文档增加 markdown lint。

## 9. 不允许破坏的行为

- 日记能创建、编辑、删除并保存到本地 JSON。
- 重启后能加载已有日记。
- 分类、心情、日期、标题、正文都能编辑。
- 搜索标题、正文、分类、心情可用。
- Markdown 预览能显示当前支持的块类型。
- `###` 小节能驱动预览分组、列表摘要和统计覆盖率。
- 统计看板能在无数据和有数据时稳定展示。
- 宽屏编辑器双栏和统计两列不能在窄屏造成重叠。

## 10. 测试映射

- `JournalEntry` 改动：Probe / Fast + Stage Regression；未来补兼容解码 XCTest。
- `JournalStore` 改动：Probe / Fast + Smoke；涉及数据迁移时 Full。
- `MarkdownBlockParser` 改动：Probe / Fast + Stage Regression；未来补解析 XCTest。
- `JournalStatistics` 改动：Probe / Fast + Stage Regression；未来补统计 XCTest。
- UI 视图改动：Probe / Fast + Smoke；涉及横屏和布局时补手动视觉验证。
- 文档-only 改动：`git diff --check`，必要时补 `plutil` 和 Swift 解析确认基线未漂移。
