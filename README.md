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

已在本机通过 Xcode.app 执行 generic iOS Debug 构建：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前环境的 CoreSimulator 服务不可用，因此未启动 iOS 模拟器做交互运行验证。
