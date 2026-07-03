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
- 当前测试基线：本地轻量检查 + GitHub Actions 云端重验证；尚未建立正式 XCTest target。
- 当前已知限制：CoreSimulator 服务在当前环境不可用，尚未做模拟器交互验证。
- 当前远端状态：本地仓库当前未配置 `origin` 远端，真实 `main` push、Actions run 和 artifact 下载会被阻塞，直到人工配置远端和权限。

## 关键决策

- 使用 SwiftUI 原生实现，不默认引入第三方框架。
- 使用 `NavigationSplitView` 作为主导航结构。
- `JournalStore` 作为唯一日记集合修改和保存入口。
- Markdown 预览采用轻量自研解析器，不承诺完整 CommonMark 支持。
- 日记正文推荐使用 `###` 三级标题组织小节，并以此驱动预览分组和统计。
- iPhone 支持竖屏、横屏左、横屏右；宽屏阈值当前为 `820` pt。
- 后续迭代采用“人工 -> Agent A -> Agent B main 直推 -> GitHub Actions 结果包 -> Agent C 下载复判 -> 人工复核”的文档化流程。
- `main` 是默认唯一上传、提交、推送和云端验证分支；本阶段不使用候选分支或 PR 流程。
- Agent C 不通过时退回 Agent B 在 `main` 上追加修复 commit，不默认回滚；最终通过必须核对最新 `origin/main` 对应的未加密 CI 结果包。

## 历史记录

### v0.3 / 升级 main 直推云端验证流程

日期：2026-07-03

核心变更：

- 将协作制度从“Agent C 本地验收后提交”升级为“Agent B main 直推、GitHub Actions 云端重验证、Agent C 下载未加密结果包复判”。
- 新增 Agent A/B/C 召唤前缀和最终回复身份标识规则。
- 明确 `main` 是默认唯一上传、提交、推送和云端验证分支；本阶段不设计 `smalldata_test`、`develop`、`codeb/...` 或 PR 流程。
- 新增 `.github/workflows/ci-results.yml`，在 `main` push 和手动触发时运行静态检查、generic iOS Debug build，并上传 manifest、failure summary、日志、JUnit 和 `.xcresult`。
- 更新测试规范为“本地轻量检查 + 云端重验证”默认策略，保留人工明确要求时的本机完整 build 命令。
- README 仅新增简短“协作与云端验证”说明，不替代入口规则。

对比判断：

- 可复用 AITRANS 的制度骨架：main 直推、CI 结果包、manifest 可追溯、Agent C 下载复判、失败后追加修复 commit。
- 不照搬 AITRANS 的项目特例：漫画探针、GGUF、模型 Release、`test/1.png`、`smalldata_test`、候选分支和 PR 合并流。
- MD Journal 是 SwiftUI iOS / Xcode 项目，结果包重点是 project lint、Swift parse、generic iOS build 日志、JUnit 摘要和 `.xcresult`。

关键文件：

- `AGENTS.md`
- `.github/workflows/ci-results.yml`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `README.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过。
- 未运行本机完整 Xcode build：本轮是流程和 CI 改造，且新规范默认由云端重验证承担完整 build。
- 未完成真实 `main` push、GitHub Actions run 和 artifact 下载：当前 `git remote -v` 无输出，仓库未配置 `origin` 远端。

遗留事项：

- 人工需要配置 `origin` 远端和 GitHub Actions 权限后，执行首次 `git push origin main`。
- Agent C 需要在可访问仓库的环境中 `gh auth login`，下载 `/private/tmp/mdjournal-c-review-<run_id>/` 缓存并核对结果包。
- 项目仍未建立 XCTest target；CI 结果包中的 XCTest 当前标记为 `skipped`。

### v0.2 / 更新 Agent C 验收提交规则

日期：2026-06-29

核心变更：

- 明确 Agent C 验收不通过时退回 Agent B，并列出问题与修复要求。
- 明确 Agent C 最终通过后按版本号自动 stage 并 git commit。
- 规定提交说明使用“版本号 + 简短工作概括”，用于概括该版本工作内容。
- 同步更新入口规则、核心流程、流程图、README 和更新日志。

关键文件：

- `AGENTS.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `rg -n "[ \t]+$" AGENTS.md update_log.md README.md md` 无输出。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本轮仅修改文档流程，未重跑 Xcode generic iOS build。

遗留事项：

- 本轮仅修改文档流程，不涉及 Swift 源码和 Xcode 工程。

### v0.1 / 建立多 Agent 迭代文档体系

日期：2026-06-28

核心变更：

- 新增标准入口 `AGENT.md`，后续工作区入口调整为 `AGENTS.md`。
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
