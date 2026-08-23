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
- 当前已有 `MDJournalTests` XCTest target，覆盖核心模型、非持久化正文 summary / metrics 派生一致性、正文词数单次扫描边界、`JournalSection.containsLevelThreeSection(in:)` 明确期望及其与完整提取在 ASCII 缩进、非法标题、LF/CR/CRLF、Foundation Unicode newline、空标题和 fenced code 等边界上的等价性、摘要 Markdown 标记清理和空行处理、列表派生快照（含真实空集合与筛选空结果区分）、分类筛选 chip 最小交互高度与可访问文案纯契约、列表概览合法/非法 `###` 聚合及与统计结果一致性、`JournalEntryNavigation` 按输入数组顺序切换较新/较早日记的方向、首尾不循环、空/单篇/`nil`/失效 selection 边界、导航命令元数据以及导航/写作/Markdown/保留 `⌘N` 的快捷键全局唯一性、Markdown 解析（含水平空白行空行判断、行首空格/tab marker 识别、有序列表块识别、代码块空白/空行保留、代码块内 Markdown-like 行不解析、CR-only / CRLF 当前分行行为、尾随换行和 `###` 小节分组）、Markdown 预览纯文本内联快路径与 latest-wins 防抖策略、统计（含分布最大值、主导分类/心情、7 天趋势最大词数派生和乱序输入排序回退）、Markdown snippet（含有序列表片段）、Markdown 片段插入规则（含选区空白行跳过、CR/CRLF 保留、CR-only 空白行、尾随换行、有序编号跳过空白行和 UTF-16/emoji 边界）、Markdown 无序列表/待办/引用/有序列表回车续写规则（含空项退出水平空白边界、fenced code 内回退默认输入、闭合围栏后恢复续写、缩进围栏和非行首围栏边界）、Markdown 行缩进规则（含单空格反缩进、长多行选区、长后续正文、尾随空行、CRLF 结束边界、单次构造混合反缩进和 UTF-16/emoji 行边界）、Markdown 输入配置（含可重入恢复配置）、Markdown 正文字体按需配置、普通输入/回车续写/缩进对正文 Binding 的 `0 getter / 1 setter` 确定性计数、写作命令快捷键、写作工具栏和 Markdown 工具栏快捷键提示文案、写作工具栏辅助功能标签文案、预览切换状态标题、专注写作命令和缩进方向映射，以及 `JournalStore` 写入节流与按需排序；这些 Binding 计数测试只证明 bridge 调用契约，不冒充 Instruments 分配测量或真实键盘/IME 交互测试。focused scene navigation wiring 只由 Swift parse 与云端 Mac Catalyst build 间接覆盖，不冒充真实菜单 disabled 视觉、正文 first responder 持续性或键盘事件分发测试。分类筛选 chip 的纯契约测试不证明真实 frame、hit testing、Dynamic Type 渲染或 VoiceOver 朗读；modifier 顺序由 diff 审查，平台 API 接线由云端 generic iOS 与 Mac Catalyst build 间接覆盖，真实触控、辅助功能与 focus ring 仍需人工验收。Markdown 工具栏 `44×44pt` 矩形交互区、编辑器小节概览懒加载、Mac 专注写作正文输入区宽度约束、Mac 写作工具栏辅助功能标签和 Mac 预览切换按钮辅助功能标签仍由 Swift parse、generic iOS build 和 Mac Catalyst build 覆盖，不把现有单元测试伪装成按钮点击或命中几何验证。
- `JournalEntryTests` v0.77 新增 extraction characterization，精确断言 `JournalSection.extract(from:)` 的 count、title、markdown、excerpt、order、id，覆盖 LF/CR/CRLF/混合 Unicode newline、ASCII 空格/tab 与非法 marker、非 ASCII 空白、空标题、连续 marker、空正文、尾随换行、标题前正文和 fenced code；不写耗时或分配断言。本轮明确不运行本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本或 Instruments，完整验证交给 GitHub Actions artifact。
- `JournalEntryTests` v0.78 新增 shared metrics characterization，精确断言一次派生结果的 wordCount、section count、title、markdown、excerpt、order 和 id，覆盖混合 Foundation newline、emoji/组合字符、非法 marker、空标题、连续正文和 fenced code；生产入口必须消费共享扫描，测试不写耗时或分配断言。本轮本机仍只做 Swift parse、diff、plist、YAML 和版本检查，完整 build/XCTest 交给 GitHub Actions artifact。
- `MarkdownSnippetTests` v0.79 新增 Mac Catalyst `MacWindowLayoutContract` 尺寸契约，锁定 `1120×720pt` 主窗口最小内容尺寸、`260/300/360pt` sidebar 范围、正有限值和 `300pt + EntryEditorLayoutContract.wideLayoutMinimumWidth` 宽屏关系；测试只验证纯值，不冒充真实窗口尺寸、拖拽、恢复、Dynamic Type、VoiceOver 或输入设备交互。本轮本机只做 Swift parse、diff、plist 和版本检查，完整 build/XCTest 交给 GitHub Actions artifact。
- `MarkdownSnippetTests` 另覆盖 `EntryEditorAccessibilityContract.journalDateLabel` 精确等于“日记日期”且去空白后非空。该纯常量测试、Swift parse 和云端 build 不证明 `.labelsHidden()` 后的真实 accessibility tree、VoiceOver 日期值朗读、Mac Catalyst focus ring 或 compact picker 交互，这些仍需人工验收。
- `MarkdownSnippetTests` 另覆盖 `EntryEditorLayoutContract`：`819/820pt × .large/.accessibility1/.accessibility5` 六格矩阵锁定工作区宽屏边界与头部布局彼此独立，普通 `820/.large` 是唯一横向紧凑头部和 `270pt` 统计宽度组合，Accessibility 下元数据、summary、统计 pill 堆叠且标题不限两行；测试同时锁定 `820/270/156pt` 正有限尺寸及小节行数策略。v0.73 artifact 基线为 182 项，v0.74 云端实际总数为 185 项。纯 contract 测试不证明真实 frame、Dynamic Type 像素渲染、`@ScaledMetric` 最终宽度、VoiceOver、focus ring、键盘、鼠标或触控板交互。
- `MarkdownPreviewTests` 新增 4 项确定性策略测试：首次激活立即发布、正文连续变化的 150ms trailing scheduler、generation/entry ID latest-wins、切换日记或 deactivate 后失效，以及相同正文去重。测试使用手动 scheduler，并断言固定延迟，不使用真实 sleep、轮询、GCD、semaphore 或 detached task；它们只证明预览更新边界，不证明真实 Mac 输入延迟、Instruments 分配、像素排版或帧率。v0.75 最终云端结果为 `189 passed / 0 failed / 0 skipped`，以对应未加密 artifact 为完整验证依据。
- v0.76 新增 6 项纯 selection/navigation 测试：`JournalEntrySelectionPolicy` 覆盖 visible retain、hidden -> first visible、empty -> nil、筛选删除后的修复、新建日记匹配/隐藏后的修复，以及把 `JournalEntryListSnapshot.filteredEntries` 传入 `JournalEntryNavigation` 的 filtered navigation。测试直接消费 production policy 和真实列表快照，不使用 SwiftUI host、系统 confirmation dialog、真实菜单、模拟器、截图或 snapshot test；它们不能证明真实筛选输入时序、NavigationSplitView selection/detail 瞬态、菜单 disabled 视觉、焦点、VoiceOver、Dynamic Type 或鼠标/触控板/键盘交互。v0.75 最终云端基线为 189 项，v0.76 最终结果为 `195 passed / 0 failed / 0 skipped`，6 项新增测试各执行一次，完整 build/XCTest/app 只以对应未加密 artifact 为准，本机未运行。
- `JournalStatisticsTests` 另覆盖 `SevenDayBarChartLayoutContract`：普通 `.large` / `.xxxLarge` 不滚动，`.accessibility1` / `.accessibility5` 使用水平滚动，并锁定 92pt 柱图区、14pt 词数最小高度、134pt 图表最小高度和 56pt Accessibility 列宽。纯契约测试不证明真实文字无裁切、滚动手感、普通字号像素级视觉或 Mac Catalyst 输入设备交互；v0.71 云端预期基线为 164 项 XCTest，最终数量以最新 artifact 为准。
- `JournalEntryListSnapshotTests` 另覆盖 `JournalDeletionConfirmationState`：请求后稳定持有完整日记与准确标题、dismiss 幂等清理且不产生确认目标、确认目标只能消费一次，以及新请求替换旧请求且不依赖筛选结果回查。v0.72 新增 4 项纯状态测试，云端预期基线为 `168 passed / 0 failed / 0 skipped`；这些测试不证明真实系统对话框视觉、焦点、Esc、点击外部、右键菜单事件或滑动手势，生产接线和平台 API 由 diff 审查及云端 iOS / Mac Catalyst build 间接覆盖，最终数量以最新 artifact 为准。
- `JournalStoreTests` 在 v0.73 从 5 项重构为 19 项：production writer JSON 字节策略、乱序拒绝、同 revision 幂等、失败重试；starter actor 路径；gate writer 等待期间 MainActor 可运行；手动 scheduler debounce；flush 取消/等待/追赶及无 mutation 不覆写；create/delete 内存即时、在途旧写入与 flush 后磁盘结果；Store 释放不取消已提交 writer 请求；无效删除；旧失败与同 revision 迟到失败仲裁、当前失败重试、读取错误保留和既有排序。gate 在 teardown 中幂等恢复未完成 continuation，测试不使用固定 sleep、轮询、GCD、semaphore、detached task 或真实大文件猜测时序。预期云端总数为 `182 passed / 0 failed / 0 skipped`，最终以最新 artifact 为准；这些测试不替代 Instruments、真实后台挂起、强杀或断电验证。
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
  "version": "<version>",
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
mdjournal-ci-<version>-main-<short_sha>-run<run_id>-attempt<run_attempt>
```

v0.79 Mac Catalyst 窗口与 sidebar 尺寸专项核对：

- manifest 的 `version=v0.79`、`branch`、完整 `commitSha`、`runId` 和 `runAttempt` 必须与最新 `origin/main` 和对应 run 完全一致。
- `MarkdownSnippetTests.testMacWindowLayoutContractPreservesCatalystWideEditorCapacity` 必须执行并通过；XCTest 总数应高于 v0.78 的 197 项。JUnit 的 `tests=4` 仍只表示 static / iOS build / Mac Catalyst build / XCTest 四个 workflow stage，不能替代 XCTest 用例总数。
- static checks、generic iOS build、Mac Catalyst build 和 XCTest 必须 success；三个 `.xcresult` 应存在且分别为 succeeded、无失败或错误。
- Agent C 必须下载未加密 artifact，核对 manifest、JUnit、static/build/Catalyst/test 日志、failure summary、GitHub digest、本地 SHA-256、ZIP CRC、fresh extract 和逐文件完整性。
- 尺寸契约只证明常量与 `300pt + 820pt` 关系；真实 Mac 窗口最小尺寸、sidebar 拖拽、窗口恢复、焦点、Dynamic Type、VoiceOver 和长文帧率仍需人工验收。

v0.75 预览策略专项核对：

- manifest 的 `version=v0.75`、`branch`、完整 `commitSha`、`runId` 和 `runAttempt` 必须与最新 `origin/main` 和对应 run 完全一致。
- `MarkdownPreviewTests` 的 4 项测试必须各执行一次并通过；XCTest 总数必须高于 v0.74 的 185 项。JUnit 的 `tests=4` 仍只表示 static / iOS build / Mac Catalyst build / XCTest 四个 workflow stage，不能替代 XCTest 用例总数。
- static checks、generic iOS build、Mac Catalyst build 和 XCTest 必须 success；三份 xcresult 应存在且分别为 succeeded、0 errors、0 warnings、0 analyzer warnings。
- Agent C 必须下载未加密 artifact，核对 GitHub digest 与本地 SHA-256、ZIP CRC 和逐文件完整性，并记录下载目录、artifact 名称、ID、run id 与 attempt。

v0.75 最终 HEAD 结果：

- HEAD `f8a2d934e670a8a969958a2806f04af4bb24451a` 对应 run `31295125221` attempt `1`，artifact ID `9032726874`，名称 `mdjournal-ci-v0.75-main-f8a2d93-run31295125221-attempt1`，size `425855`，digest `sha256:f40aa954660e4a86b19bfcc51ec140d9c200ece425c56e04c89705a782792efe`。
- Agent C PASS：`189 passed / 0 failed / 0 skipped`；ZIP 共 449 entries、未加密，CRC 与 manifest match。

v0.76 列表筛选选择一致性专项核对：

- manifest 的 `version=v0.76`、`branch`、完整 `commitSha`、`runId` 和 `runAttempt` 必须与最新 `origin/main` 和对应 run 完全一致。
- `JournalEntrySelectionPolicy` 与 filtered navigation 新增测试必须各执行一次并通过，XCTest 总数必须高于 v0.75 的 189 项；JUnit 的 `tests=4` 仍只表示四个 workflow stage，不能替代 XCTest 用例总数。
- static checks、generic iOS build、Mac Catalyst build 和 XCTest 必须 success；三个可用 `.xcresult` 应存在且分别为 succeeded、0 errors、0 warnings、0 analyzer warnings。
- Agent C 必须下载未加密 artifact，核对 manifest、JUnit、static/build/Catalyst/test 日志、failure summary、GitHub digest、本地 SHA-256、ZIP CRC 和逐文件完整性；筛选状态、selection policy 与 Store/JSON/Markdown/保存边界的 diff 也必须复审。
- 纯 policy 测试不能冒充真实 SwiftUI List selection/detail 时序、筛选输入竞态、菜单 disabled 视觉、焦点、VoiceOver、Dynamic Type 或输入设备验收。

v0.76 implementation HEAD 结果：

- HEAD `d3b11c3b63ea4af8d94dfbe1bc4d660766c06627` 对应 run `31296673536` attempt `1`，artifact ID `9033210493`，名称 `mdjournal-ci-v0.76-main-d3b11c3-run31296673536-attempt1`，size `437199`，digest `sha256:86755783b134e7b1ee6ad1c2db1b7d20f1b99476ba7b87e7f445ba60c49b425f`。
- Agent C PASS：`195 passed / 0 failed / 0 skipped`；6 项新增测试各执行一次，三个 xcresult 均 succeeded 且 errors/warnings/analyzer warnings 为 0。ZIP 共 461 entries、未加密、CRC PASS，fresh extract list 与 ZIP 完全一致；下载工作目录另有一个本地 xcresulttool 生成的 `database.sqlite3`，不属于 artifact。
- 最终文档 HEAD `822843b3af15dc180cb940587c10f372369eb69e`、branch `main` 对应 run `31297334280` attempt `1`，artifact ID `9033466495`，名称 `mdjournal-ci-v0.76-main-822843b-run31297334280-attempt1`，size `439409`，digest `sha256:7974609e893693967c7e47d848f58be1e132c729bd083fe90bedaa00a54e2fb1`。Agent C 已从 `/private/tmp/mdjournal-c-review-31297334280/` 下载并核对 PASS：manifest/JUnit/outcomes 通过，`195 passed / 0 failed / 0 skipped`，6 项新增测试各执行一次，三份 xcresult succeeded 且 errors/warnings/analyzer warnings 为 0；ZIP 共 461 entries、未加密、CRC PASS，fresh extract 文件清单差异为 0。下载工作目录中的本地 xcresulttool 生成 `database.sqlite3` 不属于 artifact；普通 build/XCTest/app 未在本机运行。
- 该结果包只验证 implementation HEAD；文档收敛提交会触发新的 run，不能沿用本 artifact 作为新 HEAD 的云端结果。完整 build/XCTest/app 仍只以 GitHub Actions artifact 为准，本机未运行。

## 3. Agent C 下载和复判

Agent C 必须先具备 GitHub CLI 权限：

当前使用已有的 GitHub CLI 授权状态下载 artifact；本轮不执行 `gh auth login`，不修改认证配置。

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
- `junit.xml` 或等价摘要中的 `failures`、`errors` 和 `skipped`，并确认 XCTest 不是 skipped。
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
- Mac Catalyst 写作工具栏中的预览切换按钮在宽屏预览可见、宽屏预览隐藏和窄屏预览模式下，hover/help 与辅助功能标签分别表达“隐藏预览”“显示预览”或“回到编辑”。
- Mac Catalyst 写作工具栏中的聚焦正文、专注写作、减少缩进、增加缩进使用对应命令标题作为辅助功能标签；插入 Markdown 菜单使用 `插入 Markdown` 辅助功能标签。
- 选中文本后，加粗、斜体、代码块能包裹选区，引用、列表、待办和有序列表能逐行转换选区，并跳过空白行；CR/CRLF、尾随换行、emoji/UTF-16 选区和有序编号跳过空白行边界应保持稳定。
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
- CI job 限时 25 分钟；XCTest 优先解析可用 `iPhone 16`（否则较新 iOS runtime 的 iPhone），并使用 `-destination-timeout 60` 与 720 秒 alarm，避免模拟器挂起阻塞结果包上传。

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
