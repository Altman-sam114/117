# 项目版本更新记录

本文记录 MD Journal 的正式版本、重要维护事项、关键决策和遗留问题。它不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。

## 当前状态

- 当前阶段：`v0.x` 项目初始化与协作规范阶段。
- 当前应用：原生 SwiftUI Markdown 日记应用，支持 iOS/iPadOS，并通过 Mac Catalyst 构建 macOS app。
- 当前数据：本地 JSON 持久化，文件名 `md-journal-entries.json`。
- 当前测试基线：`MDJournalTests` 单元测试 target + 本地轻量检查 + Mac Catalyst build 尝试 + GitHub Actions 云端 iOS build / Mac Catalyst build / XCTest 重验证。
- 当前已知限制：CoreSimulator 服务在当前环境不可用，尚未做模拟器交互验证。
- 当前远端状态：本地仓库已配置 `origin/main`，Agent B 可直推触发 GitHub Actions；远端 URL 中的访问 token 不写入文档或最终回复。

## 关键决策

- 使用 SwiftUI 原生实现，不默认引入第三方框架。
- 使用 `NavigationSplitView` 作为主导航结构。
- `JournalStore` 作为唯一日记集合修改和保存入口。
- Markdown 预览采用轻量自研解析器，不承诺完整 CommonMark 支持。
- 日记正文推荐使用 `###` 三级标题组织小节，并以此驱动预览分组和统计。
- iPhone 支持竖屏、横屏左、横屏右；宽屏阈值当前为 `820` pt。
- Mac 版本当前采用 Mac Catalyst 路径，不新增独立 native macOS target。
- 后续迭代采用“人工 -> Agent A -> Agent B main 直推 -> GitHub Actions 结果包 -> Agent C 下载复判 -> 人工复核”的文档化流程。
- 未来可使用 `agentx`、`x:` 或 `X:` 召唤 Agent X 主控循环；Agent X 只调度 A/B/C 多轮迭代，不替代 Agent A 提示词、Agent B 实现 push 或 Agent C artifact 验收。
- `main` 是默认唯一上传、提交、推送和云端验证分支；本阶段不使用候选分支或 PR 流程。
- Agent C 不通过时退回 Agent B 在 `main` 上追加修复 commit，不默认回滚；最终通过必须核对最新 `origin/main` 对应的未加密 CI 结果包。

## 历史记录

### v0.9 / Mac Catalyst 菜单命令入口

日期：2026-07-04

核心变更：

- `MDJournalApp` 新增 scene-level “日记”菜单，提供“新建日记”和“显示统计”命令。
- `ContentView` 通过 focused scene value 暴露创建日记和显示统计动作，菜单与列表工具栏复用同一套入口。
- 统计 sheet 状态从 `EntryListView` 上移到 `ContentView`，为菜单命令和列表按钮提供统一展示路径。
- `⌘N` 快捷键改由菜单命令承载，工具栏新建按钮保留可见入口但不重复注册快捷键。
- GitHub Actions 结果包版本更新为 `v0.9`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/ContentView.swift`
- `MDJournal/Views/EntryListView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.9（MacCatalyst菜单命令入口）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机未运行 iOS Simulator XCTest：本轮未改 XCTest 或模型规则，且当前机器 CoreSimulatorService 不可用；最终 XCTest 结果以 GitHub Actions artifact 为准。
- 云端 artifact 验收需在本轮 commit push 到 `origin/main` 后由 Agent C 下载最新结果包复判。

遗留事项：

- 本轮只新增菜单命令入口，尚未做独立统计窗口、多窗口同步或 native macOS target。
- 后续可继续做正文派生快照与统计计算单次化。

### v0.8 / Markdown 预览解析单次化

日期：2026-07-04

核心变更：

- 新增 `MarkdownParseResult` 和 `MarkdownBlockParser.parseDocument(_:)`，用同一次块级解析结果派生普通块和 `###` 小节分组。
- `MarkdownPreviewView` 改为在单次 body 渲染中只解析一次正文，再复用 `blocks`、`sectionGroups` 和 `shouldUseSectionGroups`。
- 新增 `MarkdownBlockParserTests` 覆盖 `parseDocument(_:)` 的块解析、小节分组和 `shouldUseSectionGroups` 语义。
- GitHub Actions 结果包版本更新为 `v0.8`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步更新 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.8（Markdown预览解析单次化）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束；首次运行因临时 `.xcresult` 路径已存在未进入编译，换新路径后通过。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Simulator `build-for-testing`，第二次 `-quiet` 重跑返回 0；首次尝试日志已输出 `** TEST BUILD SUCCEEDED **`，但进程返回 133，未作为通过依据。
- 本机 iOS Simulator XCTest 未运行成功：当前机器 CoreSimulatorService 不可用，且没有可匹配的 `iPhone 16` simulator；命令返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `ecce25cc53042990f88102c39ebbc8ca2afefffd` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28702960797`，run attempt `1`，artifact `mdjournal-ci-v0.8-main-ecce25c-run28702960797-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28702960797/`。
- manifest 核对通过：`version=v0.8`、`branch=main`、`commitSha=ecce25cc53042990f88102c39ebbc8ca2afefffd`、`runId=28702960797`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认新增 `MarkdownBlockParserTests` 通过，包括 `parseDocument(_:)` 复用块解析和代码块内 `###` 不误判为小节。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只优化 Markdown 预览在单次渲染中的重复解析，尚未缓存列表卡片 `JournalEntry.sections` 或统计派生计算。
- 后续可继续做列表小节摘要缓存、统计计算去重和更完整的 Mac 菜单命令。

### v0.7 / 编辑写入节流

日期：2026-07-04

核心变更：

- `JournalStore.update(_:)` 改为内存即时更新、短延迟合并保存，减少正文连续输入时的 JSON 编码和原子写盘次数。
- `JournalStore.createEntry()` 和 `delete(_:)` 仍立即保存，避免创建和删除丢失。
- 新增 `JournalStore.flushPendingSave()`，`ContentView` 在 scene phase 进入 inactive/background 时立即写入待保存变更。
- 新增 `JournalStoreTests`，覆盖创建立即写盘、编辑延迟写盘和 flush 立即写盘。
- GitHub Actions 结果包版本更新为 `v0.7`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步更新 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Stores/JournalStore.swift`
- `MDJournal/ContentView.swift`
- `MDJournalTests/JournalStoreTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.7（编辑写入节流）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -list -project MDJournal.xcodeproj`，返回 0；当前机器仍输出 CoreSimulatorService 连接错误。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS 目的地 `build-for-testing`，`MDJournalTests` 编译通过并以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS Simulator XCTest 未运行成功：当前机器 CoreSimulatorService 不可用，且没有可匹配的 `iPhone 16` simulator；命令返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `3b73eb3277a8a8a78f69bbe1149f1a68307a5fad` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28702125850`，run attempt `1`，artifact `mdjournal-ci-v0.7-main-3b73eb3-run28702125850-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28702125850/`。
- manifest 核对通过：`version=v0.7`、`branch=main`、`commitSha=3b73eb3277a8a8a78f69bbe1149f1a68307a5fad`、`runId=28702125850`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认新增 `JournalStoreTests` 3 个用例均通过：创建立即写盘、编辑延迟写盘、flush 立即写盘。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只优化写入节流，尚未缓存 Markdown 预览解析或统计派生计算。
- 后续可继续做大正文预览缓存、列表小节摘要缓存和更完整的 Mac 菜单命令。

### v0.6 / 启用 Mac Catalyst 构建

日期：2026-07-04

核心变更：

- 启用 `MDJournal` app target 的 Mac Catalyst 支持，保留 iOS 16.0 和现有 iPhone/iPad 方向设置。
- CI 结果包新增 Mac Catalyst Debug build、`maccatalyst-build.log`、`MDJournalMacCatalyst.xcresult` 和 manifest/JUnit 中的 Catalyst outcome。
- 列表新增 Mac Catalyst 友好的右键删除入口，删除仍通过 `ContentView.deleteEntry(_:)` 和 `JournalStore.delete(_:)`。
- 新建日记按钮新增 `⌘N` 快捷键，提升桌面写作入口效率。
- 新增本轮 Agent A 提示词，并同步 README、测试规范、核心流程和流程图。

关键文件：

- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `MDJournal/Views/EntryListView.swift`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.6（启用MacCatalyst构建）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、workflow YAML 解析。
- 本机已通过：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -list -project MDJournal.xcodeproj`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机 `xcodebuild` 仍输出 CoreSimulatorService 连接错误，但 Catalyst build 返回 0，且该错误与本轮 Catalyst 构建结果无关。
- GitHub Actions artifact 验收需在本轮 commit push 到 `origin/main` 后由 Agent C 下载最新结果包复判。

遗留事项：

- 本轮先建立 Mac Catalyst 可构建基线，尚未新增独立 native macOS target。
- 后续应继续优化桌面写作体验，例如更完整的菜单命令、独立统计窗口、编辑保存节流和大正文预览缓存。
- 本轮未做真实 macOS 窗口截图或交互视觉验收。

### v0.5 / 引入 Agent X 循环迭代文档基线

日期：2026-07-04

核心变更：

- 新增 Agent X 召唤、职责、循环判断和停止条件。
- 将现有 Agent A/B/C 云端验证流程扩展为可被 Agent X 多轮调度。
- 更新 flow、flowchart、test、prompt README 和 README 中的协作说明。
- 明确本轮只做文档准备，不启动真实自动循环。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `md/prompt/v0（协作自动化）/v0.5（引入AgentX循环迭代）.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- 已 push `d6e3ade957188e335377bf7d3b41e8ec452a31c5` 到 `origin/main`。
- Agent C 已下载并核对最新 `origin/main` 对应 GitHub Actions 结果包：run id `28681864701`，run attempt `1`，artifact `mdjournal-ci-v0.4-main-d6e3ade-run28681864701-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28681864701/`。
- manifest 核对通过：`branch=main`、`commitSha=d6e3ade957188e335377bf7d3b41e8ec452a31c5`、`runId=28681864701`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=3`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束，10 个测试用例均通过。
- `MDJournal.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 后续人工可用 `agentx:` 提供总目标 X，启动 Agent X 主控循环。
- Agent X 真正执行循环时，仍必须经过 Agent A 提示词、Agent B 实现 push、Agent C 云端 artifact 验收。

### v0.4 / 建立 XCTest 基线

日期：2026-07-03

核心变更：

- 新增 `MDJournalTests` XCTest target，并通过共享 `MDJournal` scheme 纳入测试。
- 新增第一批核心规则单元测试，覆盖 `JournalEntry` 旧 JSON 兼容解码、空标题展示、starter `###` 模板、`JournalSection` 小节抽取、`MarkdownBlockParser` 块解析与 `###` 分组、`JournalStatistics` 固定日期统计口径和 `MarkdownSnippet` 工具栏片段契约。
- 修正 `JournalSection.extract` 与 `MarkdownBlockParser` 对 `### ` 空标题的识别，确保回退为“未命名小节”。
- 更新 `MD Journal CI Results` workflow：保留静态检查和 generic iOS Debug build，新增 simulator XCTest，artifact 增加 `xctest.log` 和 `MDJournalTests.xcresult`，manifest 的 `testOutcome` 改为真实 `success/failure`。
- 同步更新 README、测试规范、核心流程和流程图中的测试基线、CI 结果包内容和远端状态。

关键文件：

- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournal.xcodeproj/xcshareddata/xcschemes/MDJournal.xcscheme`
- `.github/workflows/ci-results.yml`
- `MDJournalTests/JournalEntryTests.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `update_log.md`

验证结果：

- Agent B 本地轻量检查通过：`git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、Swift parse、workflow YAML 解析、scheme XML 解析和 `xcodebuild -list`。
- Agent B 本机 XCTest 未运行成功：当前机器 CoreSimulatorService 连接失效且没有匹配的 iPhone 16 simulator；`build-for-testing -destination 'generic/platform=iOS Simulator'` 返回 0。
- Agent B 已 push `d55de09a0f02421394f94003e1851f53ec02249a` 到 `origin/main`。
- Agent C 已下载并核对最新 `origin/main` 对应 GitHub Actions 结果包：run id `28671607692`，run attempt `1`，artifact `mdjournal-ci-v0.4-main-d55de09-run28671607692-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28671607692/`。
- manifest 核对通过：`branch=main`、`commitSha=d55de09a0f02421394f94003e1851f53ec02249a`、`runId=28671607692`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=3`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束，10 个测试用例均通过。
- `MDJournal.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本机环境仍未完成真实 iOS Simulator XCTest 和交互视觉验证，原因是当前机器 CoreSimulator 服务不可用；本轮最终重验证以 GitHub Actions artifact 为准。
- 本轮未新增 UI test 或模拟器交互视觉验证。

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
