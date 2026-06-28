# 测试规范

本文指导 Agent B 和 Agent C 选择测试层级、记录命令和判断当前基线。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/md`。
- Xcode 工程：`MDJournal.xcodeproj`。
- Scheme：`MDJournal`。
- 当前最低 iOS 版本：16.0。
- 当前没有第三方依赖和包管理器。
- 当前没有正式 XCTest target。
- 当前环境 CoreSimulator 服务不可用时，不要求模拟器交互验证，但必须记录原因。
- generic iOS build 建议使用 `/private/tmp` 下的 DerivedData，避免污染仓库：

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

## 测试分层

### 1. Probe / Fast

最快发现项目文件、Swift 语法和文档 diff 的断点。

触发条件：

- 任意文档、Swift 文件或 Xcode 工程文件改动。
- Agent B 开始实现后第一次自检。

命令：

```sh
git diff --check
```

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

当前基线：

- `git diff --check` 应无输出并返回 0。
- `plutil` 应输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- `swiftc -parse` 应返回 0 且无错误输出。

### 2. Smoke

验证主要集成路径能构建。

触发条件：

- 修改 Swift 源码。
- 修改 Xcode 工程。
- 修改 App 入口、模型、存储、导航、编辑器、预览或统计。
- 发布给人工前需要确认主构建链路。

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

### 3. Stage Regression

覆盖当前阶段核心模块的行为风险。

触发条件：

- 修改 `JournalEntry`、`JournalStore`、`MarkdownBlockParser`、`JournalStatistics`。
- 修改数据格式、解码兼容、统计口径或 Markdown 解析语义。
- 修改横屏/宽屏核心布局。

命令：

```sh
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
```

人工或可用模拟器环境下还应手动验证：

- 新建日记后生成默认 `###` 小节模板。
- 编辑标题、日期、分类、心情和正文后能保存。
- 重启后本地 JSON 数据仍能加载。
- Markdown 预览能渲染标题、段落、引用、列表、待办、代码块、分割线和 `###` 分组。
- 搜索和分类筛选可用。
- 统计看板指标随数据变化。
- iPhone 竖屏和横屏布局不重叠。

当前基线：

- 自动化层面以 Probe / Fast + Smoke 为基线。
- 手动交互验证尚无本地可用模拟器基线。

### 4. Full

全量测试，适用于重要里程碑或准备交付。

触发条件：

- 正式版本发布。
- 大范围重构。
- 数据迁移。
- 新增测试 target 或 CI。
- 人工明确要求完整验证。

命令：

```sh
git status --short --branch
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如未来新增 XCTest target，再补充：

```sh
xcodebuild test ...
```

当前基线：

- 当前仓库还没有可执行 XCTest 基线。
- Full 的自动化部分目前等同于 Probe / Fast + Smoke + 工作区状态检查。

## 静态检查

- Git 空白检查：`git diff --check`。
- Xcode project plist 检查：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- Swift 解析检查：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- Xcode generic build：见 Smoke。
- Markdown lint：当前未配置；如后续引入，必须在本文件记录命令和基线。

## 规则

- 每次实现前先读本文件。
- 默认从最小测试开始。
- 根据改动范围扩大测试。
- 不得伪造测试结果。
- 不得用“验证过”替代具体命令和结果。
- 文档-only 修改可只跑静态检查，但必须说明未跑完整测试的原因。
- 若新增测试 target、脚本或 CI，必须同步更新本文件、`README.md` 和 `update_log.md`。
