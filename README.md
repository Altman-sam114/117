# MD Journal

MD Journal 是一个原生 SwiftUI iOS Markdown 日记应用，目标是简洁、美观、快速写作，并能随时切换预览。

## 功能

- 按日期创建、编辑、删除日记。
- 本地 JSON 自动保存，不依赖服务器。
- 支持日常、工作学习、灵感、旅行、健康分类，并可在列表中按分类筛选。
- Markdown 编辑器，带 `###` 小节、加粗、引用、列表、待办、代码块和分割线快捷按钮。
- Markdown 预览，支持标题、段落、引用、列表、待办、代码块和分割线渲染。
- 正文包含 `###` 时，预览会按三级标题分组显示每个日记小节。
- 日记列表用卡片展示分类、心情、日期、词数和 `###` 小节摘要。
- 统计看板展示总篇数、总词数、连续记录天数、最近 7 天写作趋势、分类分布、心情分布和小节覆盖率。
- 日记列表支持搜索标题、正文、分类和心情。
- 支持选择日记日期、心情、分类和系统分享。
- iPhone 支持竖屏、横屏左和横屏右。
- 宽屏下编辑器使用左右分栏，同时展示编辑区和 Markdown 预览。
- 统计看板在宽屏下使用两列布局，列表概览和小节摘要会自适应窄屏与横屏空间。

## 日记结构建议

正文推荐用三级标题组织日记：

```md
### 今天发生了什么

- 一件具体的事
- 一个值得记住的细节

### 我的感受

> 写下真实状态。

### 明天可以做的小事

- [ ] 一个容易完成的行动
```

## 运行

1. 用 Xcode 打开 `MDJournal.xcodeproj`。
2. 选择 `MDJournal` scheme。
3. 选择 iPhone 模拟器或真机运行。

## 验证

默认验证策略是“本机轻量检查 + GitHub Actions 云端重验证”。每次改动后先执行：

```sh
git diff --check
```

修改 Xcode 工程时执行：

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

修改 Swift 源码时执行：

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

修改 workflow 时执行：

```sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

当前已建立 `MDJournalTests` 单元测试 target，覆盖核心模型、Markdown 解析、统计和 Markdown 快捷片段。需要本机尝试 XCTest 时使用：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  test
```

除非人工明确要求，本机不默认跑完整构建；Agent B 提交后 push 到 `origin/main`，由 `MD Journal CI Results` workflow 执行 generic iOS Debug build 和 XCTest，并上传未加密结果包。人工明确要求本机 build 时使用：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前环境的 CoreSimulator 服务不可用，因此未启动 iOS 模拟器做交互运行验证。

## 协作与云端验证

- `agenta` / `a:` 召唤 Agent A 写版本化实现提示词。
- `agentb` / `b:` 召唤 Agent B 在 `main` 上实现、本地轻量检查、commit 并 push 到 `origin/main`。
- `agentc` / `c:` 召唤 Agent C 下载 GitHub Actions 未加密结果包，核对 manifest、JUnit 或等价摘要、主日志和失败摘要。
- 当前默认不使用候选分支或 PR；云端验证阻塞时必须记录缺少的远端、权限或 artifact，而不是伪装通过。

## 后续维护

- 后续 Codex agent 必须先阅读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、本 README、当前 git 状态和最近提交记录。
- 每次完成实际开发、修复或重构后，都要同步更新本 README、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/test/test.md` 中受影响的部分。
- 每轮 Agent A 写给 Agent B 的详细实现提示词保存在 `md/prompt/`，按版本号管理。
- Agent B 默认在 `main` 上直推 `origin/main` 触发云端重验证；Agent C 最终以最新结果包验收，不通过时退回 Agent B 追加修复 commit。

## 完成记录

- 2026-07-03：建立 `MDJournalTests` XCTest 基线，覆盖模型兼容解码、`###` 小节、Markdown 解析、统计和片段契约；CI 结果包新增真实 `testOutcome`、`xctest.log` 和测试 `.xcresult`。验证结果见 `update_log.md`。
- 2026-07-03：升级协作制度为 main 直推、GitHub Actions 云端重验证和 Agent C 结果包验收；新增 `MD Journal CI Results` workflow。验证结果见 `update_log.md`。
- 2026-06-29：更新多 Agent 工作流，明确 Agent C 验收不通过时退回 Agent B，最终通过后按版本号自动提交，并用简短提交说明概括该版本工作。验证结果见 `update_log.md`。
- 2026-06-28：建立多 Agent 迭代文档体系，新增 `AGENT.md`、`update_log.md`、`md/prompt/`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`；README 改为指向标准入口。已验证指定文档存在、`git diff --check` 通过、`plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本轮只改文档，未重跑 Xcode 构建。
- 2026-06-27：补充 `agent.md` 作为后续 Codex 系统提示词和项目维护规范；README 同步记录横屏、响应式布局、验证命令和后续维护要求。已验证 `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过，`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本次仅改文档，未重跑 Xcode 构建。
