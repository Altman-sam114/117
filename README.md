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

推荐每次代码改动后执行：

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

已在本机通过 Xcode.app 执行 generic iOS Debug 构建：

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

## 后续维护

- 后续 Codex agent 必须先阅读 `AGENT.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、本 README、当前 git 状态和最近提交记录。
- 每次完成实际开发、修复或重构后，都要同步更新本 README、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/test/test.md` 中受影响的部分。
- 每轮 Agent A 写给 Agent B 的详细实现提示词保存在 `md/prompt/`，按版本号管理。

## 完成记录

- 2026-06-28：建立多 Agent 迭代文档体系，新增 `AGENT.md`、`update_log.md`、`md/prompt/`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`；README 改为指向标准入口。已验证指定文档存在、`git diff --check` 通过、`plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本轮只改文档，未重跑 Xcode 构建。
- 2026-06-27：补充 `agent.md` 作为后续 Codex 系统提示词和项目维护规范；README 同步记录横屏、响应式布局、验证命令和后续维护要求。已验证 `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过，`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过；本次仅改文档，未重跑 Xcode 构建。
