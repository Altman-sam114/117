# 测试规范

本文指导 Agent A、Agent B、Agent C 和未来 Agent X 主控循环选择测试层级、记录命令和判断当前基线。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/md`。
- 默认协作分支：`main`。
- 默认远端目标：`origin/main`。
- Xcode 工程：`MDJournal.xcodeproj`。
- Scheme：`MDJournal`。
- 当前最低 iOS 版本：16.0。
- 当前 Mac 版本路径：Mac Catalyst，Mac deployment target 为 13.0。
- 当前没有第三方依赖和包管理器。
- 当前已有 `MDJournalTests` XCTest target，覆盖核心模型、非持久化正文 summary / metrics 派生一致性、摘要 Markdown 标记清理和空行处理、列表派生快照、列表概览轻量统计快照、Markdown 解析（含有序列表块识别和 `###` 小节分组）、统计（含分布最大值、主导分类/心情、7 天趋势最大词数派生和乱序输入排序回退）、Markdown snippet（含有序列表片段）、Markdown 片段插入规则（含选区空白行跳过）、Markdown 无序列表/待办/引用/有序列表回车续写规则、Markdown 行缩进规则（含单空格反缩进）、Markdown 输入配置（含可重入恢复配置）、Markdown 正文字体按需配置、写作命令快捷键、工具栏快捷键提示文案、专注写作命令和缩进方向映射，以及 `JournalStore` 写入节流与按需排序；编辑器小节概览懒加载和正文 bridge 状态写回去重属于 SwiftUI/UIKit bridge 展示容器优化，由 Swift parse、iOS build 和 Mac Catalyst build 覆盖。
- 当前默认策略：本机先跑轻量检查；新增或修改测试 target 时尝试本机 XCTest；修改 Mac Catalyst 支持时尝试本机 Catalyst build；最终重验证交给 GitHub Actions。
- 若仓库没有 `origin` 远端、GitHub Actions 权限或 artifact 下载权限，必须记录阻塞，不能伪装云端验证完成。
- Agent X 只负责主控调度；每一小轮仍以 Agent B 本地轻量检查、GitHub Actions artifact 和 Agent C 下载复判作为验证链路。

## 1. 本地轻量检查

本地轻量检查用于尽快发现空白、配置、语法和 workflow 断点。除非人工明确要求，本机不默认跑完整 build。

### 1.1 通用检查

触发条件：

- 任意文档、Swift 文件、Xcode 工程文件或 workflow 改动。
- Agent B 实现后、commit 前。

命令：

```sh
git diff --check
```

当前基线：

- 无输出并返回 0。

### 1.2 Xcode project 检查

触发条件：

- 修改 `MDJournal.xcodeproj/project.pbxproj`。
- 修改构建配置或需要确认 project 文件未损坏。

命令：

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

当前基线：

- 输出 `MDJournal.xcodeproj/project.pbxproj: OK`。

### 1.3 Swift 解析检查

触发条件：

- 修改 Swift 源码。
- 修改可能影响 Swift 编译输入的工程结构。

命令：

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

当前基线：

- 返回 0 且无错误输出。

### 1.4 Workflow YAML 检查

触发条件：

- 新增或修改 `.github/workflows/*.yml` 或 `.github/workflows/*.yaml`。

命令：

```sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

当前基线：

- 输出 `yaml ok` 并返回 0。

### 1.4.5 Mac Catalyst 构建检查

触发条件：

- 修改 Mac Catalyst 支持、Xcode target 平台、桌面入口或 `.github/workflows/ci-results.yml` 的 Catalyst 阶段。
- 修改 SwiftUI scene commands、菜单命令或 Mac Catalyst 专属交互入口。
- 修改 `script/build_and_run.sh` 或 `.codex/environments/environment.toml`。

命令：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  -resultBundlePath /private/tmp/mdjournal-derived-data/MDJournalMacCatalyst.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前基线：

- 应以 `** BUILD SUCCEEDED **` 结束。
- 当前本机 CoreSimulator 服务可能仍输出无关连接错误；只要 Mac Catalyst build 返回 0 且构建成功，应记录为本轮 Catalyst 构建通过。

### 1.4.6 Mac Catalyst 一键运行入口检查

触发条件：

- 修改 `script/build_and_run.sh`。
- 修改 `.codex/environments/environment.toml`。
- 修改本地 Mac Catalyst 运行入口说明。

默认命令：

```sh
bash -n script/build_and_run.sh
test -x script/build_and_run.sh
```

当前基线：

- `bash -n` 返回 0。
- `test -x` 返回 0。
- 不把本机 GUI 启动作为默认验收路径；Mac Catalyst build、XCTest 和 artifact manifest 以 GitHub Actions 回传结果包为准。
- 只有人工明确要求本机运行时，才执行 `./script/build_and_run.sh --verify` 并记录结果。

### 1.5 JSON 检查

触发条件：

- 新增或修改本地 JSON 示例、manifest 模板或其他 JSON 文件。

命令：

```sh
python3 -m json.tool path/to/file.json >/dev/null
```

当前基线：

- 返回 0。

### 1.6 本机 XCTest 尝试

触发条件：

- 新增或修改 `MDJournalTests`。
- 修改 `JournalEntry`、`JournalSection`、`MarkdownBlockParser`、`JournalStatistics`、`JournalEntryListSnapshot`、`JournalListOverviewSnapshot`、`MarkdownSnippet`、`MarkdownSnippetInsertion`、`MarkdownLineContinuation`、`MarkdownLineIndentation` 或 `EditorWritingCommand` 等已有 XCTest 覆盖的核心规则。
- 修改 `MarkdownBodyTextView`、正文输入 traits、Tab / Shift-Tab 行缩进、`EntryEditorView.insertSnippet(_:)` 或正文选区/焦点同步路径时，至少尝试本机 XCTest；CoreSimulator 不可用时记录错误并以 CI artifact 为准。
- 若人工明确要求不跑本机构建、运行或测试，则跳过本机 XCTest 尝试，并在交付中说明最终只采用 GitHub Actions artifact。
- 修改 `JournalStore` 加载、创建、更新、删除、保存、排序、节流或 flush 行为。
- 修改 Xcode scheme、target 或 CI test 命令。

命令：

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

当前基线：

- 可用 Xcode/CoreSimulator 环境下应以 `** TEST SUCCEEDED **` 结束。
- 若当前机器没有 `iPhone 16`，先用 `xcrun simctl list devices available` 查找可用 iPhone simulator。
- 若 Xcode 或 CoreSimulator 不可用，必须记录关键错误；最终仍以 GitHub Actions artifact 为准。

## 2. 云端重验证

云端重验证是默认主验证路径。Agent B push 到 `origin/main` 后，GitHub Actions 运行 `.github/workflows/ci-results.yml` 并上传未加密结果包。

触发条件：

- `main` 分支 push。
- 手动触发 `workflow_dispatch`。

workflow 名称：

- `MD Journal CI Results`

云端命令基线：

```sh
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
xcrun swiftc -parse -parse-as-library $(git ls-files 'MDJournal/*.swift' 'MDJournal/**/*.swift')
```

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath "$RUNNER_TEMP/mdjournal-derived-data" \
  -resultBundlePath ci-results/MDJournal.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination "$RESOLVED_IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath "$RUNNER_TEMP/mdjournal-derived-data" \
  -resultBundlePath ci-results/MDJournalTests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
```

云端结果包至少包含：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `static-checks.log`
- `xcodebuild.log`
- `maccatalyst-build.log`
- `xctest.log`
- `junit.xml`
- `MDJournal.xcresult`，如果 `xcodebuild` 成功生成
- `MDJournalMacCatalyst.xcresult`，如果 Mac Catalyst build 成功生成
- `MDJournalTests.xcresult`，如果 `xcodebuild test` 成功生成

manifest 至少包含：

```json
{
  "version": "v0.39",
  "branch": "main",
  "commitSha": "...",
  "shortSha": "...",
  "runId": "...",
  "runAttempt": "...",
  "workflowName": "MD Journal CI Results",
  "createdAt": "...",
  "projectName": "MD Journal",
  "scheme": "MDJournal",
  "destination": "generic/platform=iOS",
  "buildDestination": "generic/platform=iOS",
  "macCatalystBuildDestination": "generic/platform=macOS,variant=Mac Catalyst",
  "testDestination": "platform=iOS Simulator,id=...",
  "resultBundlePath": "ci-results/MDJournal.xcresult",
  "macCatalystResultBundlePath": "ci-results/MDJournalMacCatalyst.xcresult",
  "testResultBundlePath": "ci-results/MDJournalTests.xcresult",
  "junitPath": "ci-results/junit.xml",
  "buildLogPath": "ci-results/xcodebuild.log",
  "macCatalystBuildLogPath": "ci-results/maccatalyst-build.log",
  "testLogPath": "ci-results/xctest.log",
  "failureSummaryPath": "ci-results/ci-failure-summary.md",
  "staticChecksOutcome": "success/failure",
  "buildOutcome": "success/failure",
  "macCatalystBuildOutcome": "success/failure",
  "testOutcome": "success/failure",
  "projectSpecificReports": []
}
```

artifact 命名规则：

```text
mdjournal-ci-v0.39-main-<short_sha>-run<run_id>-attempt<run_attempt>
```

## 3. Agent C 下载和复判

Agent C 必须先具备 GitHub CLI 权限：

```sh
gh auth login
```

下载缓存默认位置：

```text
/private/tmp/mdjournal-c-review-<run_id>/
```

推荐命令：

```sh
gh run list --branch main --workflow "MD Journal CI Results" --limit 5
gh run download <run_id> --dir /private/tmp/mdjournal-c-review-<run_id>
```

Agent C 必须核对：

- `origin/main` 最新 commit SHA。
- GitHub Actions run id 和 run attempt。
- `ci-artifact-manifest.json` 的 `branch`、`commitSha`、`runId`、`runAttempt`。
- `junit.xml` 或等价摘要中失败数，并确认 XCTest 不是 skipped。
- `static-checks.log`、`xcodebuild.log` 和 `xctest.log` 的关键错误。
- `maccatalyst-build.log` 的结尾和 `macCatalystBuildOutcome`。
- `ci-failure-summary.md` 是否与实际 outcome 一致。
- `MDJournalMacCatalyst.xcresult` 是否存在；若不存在，manifest 和日志中必须能解释原因。
- `MDJournalTests.xcresult` 是否存在；若不存在，manifest 和日志中必须能解释原因。
- artifact 是否来自本轮最新 run，而不是旧 run 或旧输出。

## 3.5 Agent X 循环下的验证规则

触发条件：

- 人工使用 `agentx`、`x:` 或 `X:` 提供总目标，并要求 Agent X 进入主控循环。
- Agent X 判断总目标需要多轮 Agent A/B/C 迭代。

每轮必须满足：

- Agent A 先生成本轮版本化提示词，明确本轮目标、非目标、验证命令、CI 要求、artifact 要求和 Agent C 验收要求。
- Agent B 按提示词实现，本地运行本文件要求的轻量检查，提交并 push 到 `origin/main`。
- GitHub Actions 为该次 push 生成最新 run 和未加密 artifact。
- Agent C 下载该最新 run 对应 artifact，并核对 manifest、JUnit 或等价摘要、主日志、失败摘要和关键结果包产物。
- Agent X 只能基于 Agent C 的 artifact 验收结论判断继续、退回、暂停或完成。

禁止：

- Agent X 跳过 Agent C artifact 验收。
- Agent X 在 Agent C 未通过时继续下一轮并伪装成功。
- Agent X 使用旧 run、旧 artifact、本地输出或文字汇报替代本轮最新云端结果包。
- Agent X 为了推进循环扩大无关改动范围。

## 4. 本机完整构建

只有人工明确要求“本机测试”“本地 build”“本地 xcodebuild”“本地跑模拟器”等，或云端环境缺失导致必须本机补证时，才默认运行本机完整构建。

命令：

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

当前基线：

- generic iOS Debug build 应以 `** BUILD SUCCEEDED **` 结束。
- 若 Xcode 或 CoreSimulator 环境问题导致失败，必须贴出关键错误并说明是否与本轮代码相关。

## 5. 手动交互验证

当前环境 CoreSimulator 服务不可用时，不要求本机模拟器交互验证，但必须记录原因。

人工或可用模拟器环境下建议验证：

- 新建日记后生成默认 `###` 小节模板。
- 编辑标题、日期、分类、心情和正文后能保存。
- 重启后本地 JSON 数据仍能加载。
- Markdown 预览能渲染标题、段落、引用、无序列表、有序列表、待办、代码块、分割线和 `###` 分组。
- 正文工具栏、Mac Catalyst “插入 Markdown”菜单和键盘快捷键能在当前光标处插入片段，其中有序列表片段会插入 `1. `，选中多行时对非空行递增编号。
- Mac Catalyst “写作”菜单和写作工具栏中的“专注写作”能切回编辑、聚焦正文，并在宽屏下隐藏预览栏。
- 选中文本后，加粗、斜体、代码块能包裹选区，引用、列表、待办和有序列表能逐行转换选区，并跳过空白行。
- 搜索和分类筛选可用。
- 统计看板指标随数据变化。
- iPhone 竖屏和横屏布局不重叠。

## 6. Full

Full 适用于重要里程碑、数据迁移、大范围重构、新增测试 target 或人工明确要求完整验证。

当前 Full 包含：

1. 本地轻量检查。
2. push 到 `origin/main`。
3. GitHub Actions 云端重验证。
4. Agent C 下载并核对结果包。
5. 必要时补本机完整构建或人工交互验证。

当前基线：

- 当前仓库已有 `MDJournalTests` 单元测试基线。
- 自动化重验证由 `MD Journal CI Results` workflow 承担，包含静态检查、generic iOS Debug build、Mac Catalyst Debug build 和 XCTest。

## 7. 规则

- 每次实现前先读本文件。
- 默认本地轻量检查 + 云端重验证。
- 不得伪造本地测试、云端 run、artifact 下载或结果包核对。
- 不得用“验证过”替代具体命令、run id、artifact 名称和结果。
- 文档-only 修改可只跑本地轻量检查，但若本轮目标包含云端流程验证，必须说明是否已 push 并下载 artifact。
- 若新增测试 target、脚本或 CI，必须同步更新本文件、`README.md` 和 `update_log.md`。

## 8. 测试数据与下载容量限制

本项目默认采用小数据量验证策略，避免下载过大 artifact、模型、数据集、缓存或结果包，把本机、CI runner 或临时目录容量撑爆。

规则：

- 测试数据必须尽量小，只覆盖必要边界。
- CI artifact 只上传必要文件：manifest、JUnit 或测试摘要、关键日志、失败摘要、必要结果包。
- 不上传大体积 DerivedData、完整 build cache、无关截图、视频、模型文件、历史 artifact 或重复压缩包。
- Agent C 下载 artifact 前优先确认只下载最新 run 对应的必要结果包。
- 下载缓存默认放在 `/private/tmp/<project>-review-<run_id>/`。
- 下载后应检查目录大小：

```sh
du -sh /private/tmp/<project>-review-<run_id>/
```

- 禁止使用非 `Altman-sam114` 的 GitHub 账号伪装完成 push、CI 或 artifact 验收。
- 禁止默认下载大体积测试数据、模型、历史 artifact 或无关产物，导致本机或 CI 容量被撑爆。
