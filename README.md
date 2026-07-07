# MD Journal

MD Journal 是一个原生 SwiftUI Markdown 日记应用，支持 iOS/iPadOS，并通过 Mac Catalyst 构建 macOS app。目标是简洁、美观、快速写作，并能随时切换预览。

## 功能

- 按日期创建、编辑、删除日记。
- 本地 JSON 自动保存，不依赖服务器。
- 编辑时先即时更新界面状态，再短延迟合并写入本地 JSON；正文等非日期更新不会触发无效列表重排，减少长文本输入时的频繁磁盘写入和主线程排序成本。
- 列表筛选、分类计数、编辑器头部和统计看板复用非持久化派生结果；统计和列表概览使用轻量正文 metrics，词数统计采用单次扫描，避免不需要摘要时生成 excerpt 或为词数创建 split 片段；正文和小节摘要使用单次扫描清理 Markdown 标记，减少中间字符串分配；统计看板预计算分布条最大值、主导分类/心情和最近 7 天趋势最大词数，并在输入已倒序时跳过重复排序。
- 编辑器头部直接使用轻量正文 metrics 展示词数和 `###` 小节，横向小节概览采用懒加载，避免正文输入时为未展示的摘要或离屏小节卡片做额外构建。
- 编辑器正文占位提示使用非分配空白判断，长文输入重渲染时不为 placeholder 条件创建临时字符串。
- 列表首页概览使用轻量统计快照，只计算总篇数、连续天数、总词数和概览洞察，避免编辑正文时反复构造完整统计看板数据或正文摘要。
- 支持日常、工作学习、灵感、旅行、健康分类，并可在列表中按分类筛选。
- Markdown 编辑器，带 `###` 小节、加粗、引用、无序列表、有序列表、待办、代码块和分割线快捷按钮；片段会按当前光标或选区插入，引用、列表、待办和有序列表转换选区时用 LF 单次扫描增量构造结果，跳过空白行并保留 CR/CRLF 和尾随换行语义，Mac Catalyst 下也可从“插入 Markdown”菜单、写作工具栏和键盘快捷键触发。
- Markdown 无序列表、待办、引用和有序列表支持回车续写；非空项会延续同缩进前缀，有序列表会递增编号，空项按回车退出当前结构，空项判断直接扫描水平空白、不创建临时 trimmed 字符串，代码围栏内回车保持系统默认输入。
- Markdown 正文支持 Tab / Shift-Tab 对当前行或多行选区缩进和反缩进；反缩进会删除一个 tab 或最多两个行首空格，Mac Catalyst 下也可从“写作”菜单和写作工具栏触发。
- Markdown 正文输入会禁用智能引号、智能破折号和智能插入删除，并只在配置被重置时重新写入 traits，避免系统自动改写 Markdown 标记。
- Markdown 正文输入 bridge 按需配置 rounded body 字体，只在目标字体变化时写入；正文、光标/选区或焦点也只在真实变化时写回 SwiftUI binding，减少长文写作时的无效状态刷新。
- Markdown 预览，支持标题、段落、引用、无序列表、有序列表、待办、代码块和分割线渲染。
- 正文包含 `###` 时，预览会按三级标题分组显示每个日记小节。
- Markdown 预览在单次渲染中复用同一份解析结果和小节分组判断；解析器空行判断直接扫描水平空白，行首 marker 判断使用原行切片，不创建临时 trimmed 字符串；内联文本没有 Markdown 触发字符时直接走纯文本 `AttributedString`，并用索引迭代渲染块和列表项，减少大正文编辑时的重复解析、重复派生和临时数组分配。
- 日记列表用卡片展示分类、心情、日期、词数和 `###` 小节摘要。
- 统计看板展示总篇数、总词数、连续记录天数、最近 7 天写作趋势、分类分布、心情分布、主导分类/心情和小节覆盖率。
- 日记列表支持搜索标题、正文、分类和心情；搜索、分类筛选和分类计数由单次列表快照派生。
- 支持选择日记日期、心情、分类和系统分享。
- iPhone 支持竖屏、横屏左和横屏右。
- 支持 Mac Catalyst 构建，可在 macOS 上以 Mac app 形态运行同一套本地 JSON 日记数据模型。
- Mac Catalyst 下保留列表、编辑器、预览和统计主流程，并补充右键删除、“日记”菜单、“写作”菜单、`⌘N` 新建、独立统计窗口、Markdown 片段菜单、写作工具栏入口、光标/选区片段插入、可见缩进/反缩进入口和专注写作入口；写作工具栏和 Markdown 片段工具栏 hover 提示会显示对应 `⌘⌥` 快捷键。
- 宽屏下编辑器使用左右分栏，同时展示编辑区和 Markdown 预览；Mac Catalyst 写作工具栏可隐藏或显示预览栏，也可一键进入专注写作状态，隐藏预览栏并聚焦正文，给长文输入更多空间并减少实时预览解析压力。
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

Mac 版本当前采用 Mac Catalyst 路径：在 Xcode 中选择 `My Mac (Mac Catalyst)`，或直接运行项目内脚本：

```sh
./script/build_and_run.sh
```

Codex 桌面环境已配置 `Run` action，指向同一个 `./script/build_and_run.sh`。脚本会停止旧的 `MDJournal` 进程、构建 Mac Catalyst Debug app，并启动最新构建产物；该入口用于人工本机开发，自动验收仍以 GitHub Actions 回传结果包为准。

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

需要验证 Mac Catalyst 构建时执行：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
```

修改 Mac Catalyst 一键运行入口时，默认通过 GitHub Actions 结果包验收；本机只需按需检查脚本语法和执行位：

```sh
bash -n script/build_and_run.sh
test -x script/build_and_run.sh
```

当前已建立 `MDJournalTests` 单元测试 target，覆盖核心模型、正文 summary / metrics 派生一致性、词数单次扫描边界、列表派生快照、列表概览轻量统计快照、Markdown 解析（含有序列表块和 `###` 小节分组）、统计、Markdown 快捷片段、片段插入规则（含选区空白行跳过、CR/CRLF、尾随换行、有序编号跳过空白行和 UTF-16/emoji 边界）、无序列表/待办/引用/有序列表回车续写规则（含空项退出的水平空白边界）、Markdown 行缩进规则（含单空格反缩进）、Markdown 输入配置和正文字体按需配置、写作命令快捷键和缩进方向映射、`JournalStore` 写入节流和更新按需排序。需要本机尝试 XCTest 时使用：

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

除非人工明确要求，本机不默认跑完整构建；Agent B 提交后 push 到 `origin/main`，由 `MD Journal CI Results` workflow 执行 generic iOS Debug build、Mac Catalyst Debug build 和 XCTest，并上传未加密结果包。结果包中的 `junit.xml` 会显式记录 `tests`、`failures`、`errors` 和 `skipped`，供 Agent C 机器复判。人工明确要求本机 iOS build 时使用：

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
- `agentx` / `x:` 召唤 Agent X 启动主控循环；Agent X 不直接替代 A/B/C，而是围绕总目标调度 A -> B -> C 多轮迭代。
- 当前默认不使用候选分支或 PR；云端验证阻塞时必须记录缺少的远端、权限或 artifact，而不是伪装通过。

## 后续维护

- 后续 Codex agent 必须先阅读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、本 README、当前 git 状态和最近提交记录。
- 每次完成实际开发、修复或重构后，都要同步更新本 README、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/test/test.md` 中受影响的部分。
- 每轮 Agent A 写给 Agent B 的详细实现提示词保存在 `md/prompt/`，按版本号管理。
- Agent B 默认在 `main` 上直推 `origin/main` 触发云端重验证；Agent C 最终以最新结果包验收，不通过时退回 Agent B 追加修复 commit。

## 完成记录

- 2026-07-07：v0.54 补齐 Markdown 工具栏快捷键提示；正文 Markdown 图标工具栏 hover 提示复用片段菜单快捷键，例如“加粗（⌘⌥B）”。
- 2026-07-07：v0.53 修正 CI 结果包 JUnit 错误字段和验收记录；`junit.xml` 显式写入 `errors="0"`，并区分 v0.52 实现 commit 与最终记录 commit 的 artifact 复判。
- 2026-07-07：v0.52 优化 Markdown 解析行首裁剪；`MarkdownBlockParser` 的行首空格/tab 裁剪改为返回 `Substring`，减少长文预览解析中的临时行字符串。
- 2026-07-07：v0.51 优化 Markdown 解析空行判断；`MarkdownBlockParser` 改为直接扫描水平空白识别空白行，减少长文预览解析中的临时 trimmed 字符串。
- 2026-07-06：v0.50 优化 Markdown 选区片段转换；引用、无序列表、待办和有序列表对多行选区改用 LF 单次扫描和增量构造，保留 CR/CRLF、尾随换行、空白行跳过、有序编号和 UTF-16 选区语义。
- 2026-07-06：v0.49 优化 Markdown 回车空项退出判断；空列表/待办/引用/有序列表项改为直接扫描 `.whitespaces` 水平空白，避免 `Substring` 转 `String` 后 trim。
- 2026-07-07：v0.48 优化 Markdown 回车续写代码围栏判断；光标前 fenced code 状态改为单次索引扫描，避免长文回车时 `split` 和逐行临时字符串。
- 2026-07-07：v0.47 优化 Markdown 预览纯文本内联渲染；普通文本片段跳过 `AttributedString(markdown:)`，有 Markdown 触发字符时保留原解析路径。
- 2026-07-07：v0.46 优化正文词数统计；`JournalEntryBodyMetrics` 改用单次字符扫描计数，避免为词数统计创建 `split` 片段。
- 2026-07-06：v0.45 优化正文字体配置写入；`MarkdownBodyTextView` 在刷新中只构造一次目标 rounded body 字体，并在当前字体不匹配时才写入。
- 2026-07-06：v0.44 优化正文输入 traits 配置；`MarkdownBodyTextView` 只在智能引号、智能破折号或智能插入删除配置被重置时重新写入 `.no`。
- 2026-07-06：v0.43 优化正文桥接状态写回；`MarkdownBodyTextView` 只在正文、选区或焦点真实变化时同步 binding，减少输入过程中的无效 SwiftUI 刷新。
- 2026-07-06：v0.42 优化摘要 Markdown 清理；正文摘要和小节摘要改用单次扫描清理 Markdown 标记，减少列表/小节摘要派生中的中间字符串分配。
- 2026-07-06：v0.41 打磨 Mac 写作工具栏提示；Mac Catalyst 写作工具栏的 hover help 复用写作命令快捷键文案，提升桌面快捷键可发现性。
- 2026-07-06：v0.40 优化统计排序成本；`JournalStatistics` 对已按 `createdAt` 倒序的输入直接复用，只有乱序输入才回退排序。
- 2026-07-06：v0.39 复用 Markdown 预览分组判断；同一次预览渲染中只派生一次 `shouldUseSectionGroups`，避免重复扫描小节分组。
- 2026-07-06：v0.38 优化编辑器正文占位判断；placeholder 可见条件改为非分配字符扫描，保持全空白正文显示提示的语义。
- 2026-07-06：v0.37 优化 Markdown 预览索引迭代；预览块、小节块、无序列表、有序列表和待办列表改用 `indices` 驱动 `ForEach`，减少实时预览中的临时数组分配。
- 2026-07-06：v0.36 懒加载编辑器小节概览；头部横向 `###` 小节卡片改用 `LazyHStack`，减少多小节长文输入时离屏卡片同步构建成本。
- 2026-07-06：v0.35 增加 Mac 专注写作命令；“写作”菜单和 Mac Catalyst 工具栏可一键隐藏宽屏预览栏并聚焦正文，窄屏下回到编辑模式并聚焦正文。
- 2026-07-06：v0.34 优化编辑器头部正文派生成本；头部词数和 `###` 小节概览改用 `JournalEntryBodyMetrics`，不再为未展示的摘要生成 excerpt。
- 2026-07-06：v0.33 预计算统计主导分类和主导心情；统计看板不再在读取主导项时重复扫描分类/心情分布，并补充平局规则测试。
- 2026-07-06：v0.32 增加 Mac 写作缩进菜单和工具栏入口；“写作”菜单与 Mac Catalyst 工具栏可触发增加缩进和减少缩进，并复用现有 Markdown 行缩进规则。
- 2026-07-06：v0.31 修正 Markdown 单空格反缩进规则；Shift-Tab 可删除一个 tab 或最多两个行首空格，多行选区混合缩进按行处理。
- 2026-07-06：v0.30 优化 Markdown 选区片段插入；引用、列表、待办和有序列表转换多行选区时跳过空白行，有序列表按非空行连续编号。
- 2026-07-06：v0.29 拆分正文统计轻量 metrics；统计和列表概览只计算词数与 `###` 小节信息，不再为这些路径生成正文摘要。
- 2026-07-05：v0.28 预计算最近 7 天趋势最大词数；趋势柱状图不再在每根柱子计算高度时重复扫描 7 天数组。
- 2026-07-05：v0.27 预计算统计看板分布最大值；分类和心情分布条不再在每一行渲染时重复扫描分布数组。
- 2026-07-05：v0.26 补齐 Markdown 有序列表插入入口；工具栏、Mac 插入菜单和快捷键可插入 `1. `，选中多行时会递增编号。
- 2026-07-05：v0.25 清理正文输入静态警告；修正 `UITextViewDelegate` replacement text 参数声明，让云端 Swift parse 不再产生重复参数标签 warning。
- 2026-07-05：v0.24 支持 Markdown 有序列表预览；`数字. ` 行会解析为有序列表块，并在预览中保留用户输入编号对齐渲染。
- 2026-07-05：v0.23 支持 Markdown 有序列表回车续写；正文中 `1. ` 项按回车会递增为下一编号，空有序列表项按回车退出列表。
- 2026-07-05：v0.22 支持 Markdown 引用回车续写；正文中 `> ` 引用按回车会延续前缀，空引用行按回车退出引用。
- 2026-07-05：v0.21 优化列表概览统计成本；新增 `JournalListOverviewSnapshot`，列表首页不再为概览卡构造完整统计看板数据。
- 2026-07-05：v0.20 支持 Markdown 行缩进；正文编辑中 Tab / Shift-Tab 可对当前行或多行选区缩进和反缩进，并通过纯规则测试覆盖 UTF-16 选区边界。
- 2026-07-05：v0.19 配置 Markdown 安全输入；正文输入禁用智能引号、智能破折号和智能插入删除，减少 Markdown 标记被系统改写的风险。
- 2026-07-05：v0.18 支持 Markdown 列表回车续写；正文中列表、待办和缩进子项按回车会延续前缀，空项按回车退出列表。
- 2026-07-05：v0.17 增加 Mac Catalyst 一键构建/运行入口；新增 `script/build_and_run.sh` 和 Codex Run action，支持 run、verify、debug、logs、telemetry 模式。
- 2026-07-05：v0.16 优化 `JournalStore.update(_:)` 排序成本；正文、标题、分类、心情等非日期更新不再触发无效列表重排，日期变化仍保持 `createdAt` 倒序。
- 2026-07-05：v0.15 支持 Markdown 片段按光标/选区插入；加粗、斜体、代码块可包裹选区，引用、列表和待办可逐行转换选区。
- 2026-07-04：v0.14 增加 Mac 写作工具栏 polish；Mac Catalyst 下新增“写作”菜单、聚焦正文、顶部片段菜单和宽屏预览栏显示/隐藏。
- 2026-07-04：v0.13 优化列表派生快照；列表搜索、分类筛选和分类计数改为单次非持久化派生，并新增快照测试。
- 2026-07-04：v0.12 增加 Markdown 片段菜单命令；Mac Catalyst/硬件键盘可从“插入 Markdown”菜单追加片段，窄屏预览触发插入后会回到编辑模式。
- 2026-07-04：v0.11 增加 Mac Catalyst 统计独立窗口；Mac 下“显示统计”打开独立窗口，iOS/iPadOS 保持统计 sheet，主窗口与统计窗口复用同一个 `JournalStore`。
- 2026-07-04：v0.10 优化正文派生和统计计算；新增非持久化 `JournalEntryBodySummary`，列表、编辑器和统计看板复用单次派生结果，`JournalStatistics` 改为单轮聚合。
- 2026-07-04：v0.9 增加 Mac Catalyst 菜单命令入口；新增“日记”菜单，提供新建日记和显示统计命令，统计 sheet 上移到 `ContentView` 统一复用。
- 2026-07-04：v0.8 优化 Markdown 预览解析性能；`MarkdownPreviewView` 改为消费 `MarkdownBlockParser.parseDocument(_:)` 的单次解析结果，避免同一渲染周期重复解析正文。
- 2026-07-04：v0.7 优化编辑写入性能；`JournalStore.update(_:)` 改为内存即时更新、短延迟合并保存，应用离开活跃态时 flush 待保存变更，并新增 `JournalStoreTests` 覆盖写入节流。
- 2026-07-04：v0.6 启用 Mac Catalyst 构建；现有 `MDJournal` target 支持 macOS Catalyst，CI 结果包新增 Mac Catalyst build outcome、日志和 result bundle，列表新增桌面右键删除与 `⌘N` 新建入口。
- 2026-07-04：v0.5 引入 Agent X 循环迭代文档基线；更新入口规则、核心流程、流程图、测试规范、prompt 规则和协作说明。本轮只做文档准备，不启动真实 Agent X 循环，不改 Swift 源码。
- 2026-07-03：建立 `MDJournalTests` XCTest 基线，覆盖模型兼容解码、`###` 小节、Markdown 解析、统计和片段契约；CI 结果包新增真实 `testOutcome`、`xctest.log` 和测试 `.xcresult`。验证结果见 `update_log.md`。
- 2026-07-03：升级协作制度为 main 直推、GitHub Actions 云端重验证和 Agent C 结果包验收；新增 `MD Journal CI Results` workflow。验证结果见 `update_log.md`。
- 2026-06-29：更新多 Agent 工作流，明确 Agent C 验收不通过时退回 Agent B，最终通过后按版本号自动提交，并用简短提交说明概括该版本工作。验证结果见 `update_log.md`。
- 2026-06-28：建立多 Agent 迭代文档体系，新增 `AGENT.md`、`update_log.md`、`md/prompt/`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`；README 改为指向标准入口。已验证指定文档存在、`git diff --check` 通过、`plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本轮只改文档，未重跑 Xcode 构建。
- 2026-06-27：补充 `agent.md` 作为后续 Codex 系统提示词和项目维护规范；README 同步记录横屏、响应式布局、验证命令和后续维护要求。已验证 `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过，`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本次仅改文档，未重跑 Xcode 构建。
