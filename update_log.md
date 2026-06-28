# 项目版本更新记录

本文记录 MD Journal 的正式版本、重要维护事项、关键决策和遗留问题。它不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。

## 当前状态

- 当前阶段：`v0.x` 项目初始化与协作规范阶段。
- 当前应用：原生 SwiftUI iOS Markdown 日记应用。
- 当前数据：本地 JSON 持久化，文件名 `md-journal-entries.json`。
- 当前测试基线：项目文件 lint、Swift 解析、generic iOS Debug 构建；尚未建立正式 XCTest target。
- 当前已知限制：CoreSimulator 服务在当前环境不可用，尚未做模拟器交互验证。

## 关键决策

- 使用 SwiftUI 原生实现，不默认引入第三方框架。
- 使用 `NavigationSplitView` 作为主导航结构。
- `JournalStore` 作为唯一日记集合修改和保存入口。
- Markdown 预览采用轻量自研解析器，不承诺完整 CommonMark 支持。
- 日记正文推荐使用 `###` 三级标题组织小节，并以此驱动预览分组和统计。
- iPhone 支持竖屏、横屏左、横屏右；宽屏阈值当前为 `820` pt。
- 后续迭代采用“人工 -> Agent A -> Agent B -> Agent C -> 人工复核”的文档化流程。

## 历史记录

### v0.1 / 建立多 Agent 迭代文档体系

日期：2026-06-28

核心变更：

- 新增标准入口 `AGENT.md`。
- 新增 `update_log.md` 记录版本、决策和遗留问题。
- 新增 `md/prompt/` 提示词目录和本轮 v0.1 提示词。
- 新增 `md/test/test.md` 测试分层与当前基线。
- 新增 `md/flow/flow.md` 项目核心逻辑文档。
- 新增 `md/flow/flowchart.md` Mermaid 可视化流程图。
- README 调整为指向标准文档体系。

关键文件：

- `AGENT.md`
- `update_log.md`
- `md/prompt/README.md`
- `md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `agent.md`

验证结果：

- `test -f AGENT.md && test -f update_log.md && test -f md/prompt/README.md && test -f 'md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md' && test -f md/test/test.md && test -f md/flow/flow.md && test -f md/flow/flowchart.md` 通过。
- `git diff --check` 通过。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本轮只改文档，未重跑 Xcode generic iOS build。

遗留事项：

- 尚未建立 XCTest target。
- 尚未建立 Markdown lint。
- 当前环境 CoreSimulator 不可用，模拟器交互验证待真机或可用模拟器环境补做。
- 当前 macOS 工作区大小写不敏感，历史跟踪路径为小写 `agent.md`；本轮已通过 `git mv -f agent.md AGENT.md` 登记大小写重命名，标准入口为 `AGENT.md`。

## 历史维护记录

### 2026-06-27 / 初版后续 Codex 提示词

- 新增小写 `agent.md`，记录项目总结和后续 Codex 编程规范。
- README 补充横屏、响应式布局、验证命令和维护说明。
- 已验证 `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- 已验证 `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本次新规范建立后，小写 `agent.md` 改为兼容入口，标准入口为大写 `AGENT.md`。

### 2026-06-25 前后 / 应用基础实现与响应式优化

- 建立 SwiftUI iOS 日记应用基础功能。
- 实现本地 JSON 保存、列表、编辑器、Markdown 预览、分类、心情、统计看板。
- 增加 iPhone 横屏方向支持。
- 宽屏编辑器改为编辑/预览左右分栏。
- 宽屏统计看板改为两列布局。
- 列表概览指标和小节摘要适配横屏与窄屏。
- 历史 Xcode generic iOS Debug 构建曾通过；当前记录以最新测试规范为准。
