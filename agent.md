# MD Journal 后续 Codex 系统提示词

你是本项目的后续编程 agent。进入仓库后，先阅读本文件、`README.md`、`git status --short --branch` 和最近的 git 记录，再开始改代码。本文件既是项目总结，也是后续维护规范；后续每次完成实际开发、修复或重构，都必须同步更新测试规范和 README 完成记录。

## 1. 项目定位

- 项目名称：MD Journal。
- 类型：原生 SwiftUI iOS Markdown 日记应用。
- 仓库路径：`/Users/a114514/Desktop/codex/md`。
- Xcode 工程：`MDJournal.xcodeproj`。
- 当前分支：`main`。
- 目标体验：简洁、美观、快速写作，支持 Markdown 编辑、预览、分类、心情、统计和横竖屏自适应。
- 数据策略：本地 JSON 持久化，不依赖服务器，不引入账号体系。

## 2. 当前实现摘要

### 2.1 应用结构

- `MDJournal/MDJournalApp.swift`：App 入口。
- `MDJournal/ContentView.swift`：使用 `NavigationSplitView` 组织列表与详情，维护当前选中日记。
- `MDJournal/Models/JournalEntry.swift`：日记模型、分类、心情、展示标题、摘要、词数、小节提取入口。
- `MDJournal/Stores/JournalStore.swift`：`@MainActor ObservableObject`，负责本地 JSON 加载、保存、新建、更新、删除和排序。
- `MDJournal/Utilities/`：日期格式化、统计计算、Markdown 解析、小节和快捷片段。
- `MDJournal/Views/`：列表、编辑器、预览、工具栏、统计看板、空状态等 SwiftUI 视图。

### 2.2 已有功能

- 按日期创建、编辑、删除日记。
- 本地 JSON 自动保存，写入 Documents 下的 `md-journal-entries.json`。
- 分类：日常、工作学习、灵感、旅行、健康。
- 心情：平静、开心、疲惫、专注、低落。
- 列表支持按标题、正文、分类和心情搜索。
- 列表支持按分类筛选。
- Markdown 编辑器支持快捷插入小节、加粗、引用、列表、待办、代码块和分割线。
- Markdown 预览支持标题、段落、引用、列表、待办、代码块、分割线。
- 正文包含 `###` 时，预览会按三级标题分组展示。
- 统计看板展示总篇数、总词数、连续记录天数、最近 7 天趋势、分类分布、心情分布和小节覆盖率。
- 支持系统分享 Markdown 文档。
- iPhone 支持竖屏、横屏左、横屏右。
- 宽屏布局阈值目前为 `820` pt：
  - 编辑器宽屏时采用左右分栏：左侧编辑，右侧预览。
  - 统计看板宽屏时采用两列布局。
  - 列表概览指标使用自适应网格。
  - 日记卡片的小节摘要使用横向滚动条，避免窄屏挤压。

## 3. 编程原则

- 优先沿用现有 SwiftUI 写法、命名和文件组织。
- 不要引入第三方依赖，除非用户明确要求并说明原因。
- 优先使用 SwiftUI 原生能力，避免 UIKit 包装。
- 保持变更范围小而完整，不做与任务无关的大重构。
- 新增视图、模型、工具类型时，按现有目录归类；复杂类型不要长期堆在一个文件里。
- 面向 iOS 16.0 当前工程配置编写代码；如要提高 deployment target，必须说明影响并同步更新 README。
- 使用 SF Symbols 和系统色，保持当前安静、实用、偏工具型的界面风格。
- 卡片圆角保持当前 8 pt 风格，避免夸张装饰。
- 宽窄屏都要考虑，新增页面或控件必须在 iPhone 竖屏和横屏下可用。
- 文案使用中文，保持简洁，避免把使用说明塞进 App 界面。
- 不要删除或覆盖用户未要求处理的本地文件、git 改动或数据。

## 4. SwiftUI 规范

- 修改 SwiftUI 代码前，先阅读可用的 `swiftui-pro` 技能说明；如涉及具体领域，再按需读取相关参考。
- 优先使用 `NavigationStack`、`NavigationSplitView`、`ToolbarItem`、`ShareLink`、`Menu`、`LazyVStack`、`LazyVGrid` 等现代 SwiftUI API。
- 对布局使用明确的响应式约束，例如 `GeometryReader`、`GridItem(.adaptive)`、`frame(maxWidth:)`、`fixedSize(horizontal:vertical:)`。
- 交互控件要有清晰的 Label 或可被 VoiceOver 识别的语义。
- 避免在 `body` 中写过重计算；统计、解析等逻辑应放在模型或工具类型中。
- 列表、统计、预览类视图要注意 Dynamic Type、长文本、空状态和窄屏换行。
- 编辑器相关改动要确认键盘工具栏、焦点状态和 Markdown 插入逻辑没有退化。
- Markdown 解析规则目前是轻量自研，不是完整 CommonMark；扩展语法时要同步更新 README 功能说明。

## 5. 数据与兼容性规范

- `JournalEntry` 已通过自定义 `Codable` 兼容旧数据缺失 `updatedAt`、`category`、`mood` 的情况。新增字段时也要考虑向后兼容。
- 保存格式使用 `JSONEncoder` 的 `.prettyPrinted` 和 `.sortedKeys`，不要随意改变，避免用户数据 diff 噪声。
- 本地保存失败和读取失败必须通过 `errorMessage` 暴露给 UI，不能静默吞错。
- 删除、迁移、重写用户数据前必须非常谨慎；没有用户明确要求，不做破坏性数据操作。

## 6. 测试与验证规范

每次完成代码改动后，至少执行以下验证，并把实际结果写入 README 的“验证”或“完成记录”：

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

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

如果改动只涉及文档，可以不跑 Xcode 构建，但必须说明原因。  
如果验证失败，先修复；如果因为本机环境限制无法验证，必须在 README 和最终回复中记录具体失败原因。

## 7. README 更新规范

每次实际开发后都要检查 `README.md`，至少确认以下内容是否需要同步：

- “功能”：新增、删除或改变用户可见能力时必须更新。
- “运行”：工程、scheme、平台或最低系统版本改变时必须更新。
- “验证”：测试命令、验证范围、环境限制改变时必须更新。
- “完成记录”：记录日期、变更摘要和已执行验证。
- 如果新增已知问题、限制或待办，也应写入 README，避免后续 agent 误判项目状态。

## 8. Git 与工作区规范

- 开始前运行 `git status --short --branch`，确认是否有用户未提交改动。
- 不要使用 `git reset --hard`、`git checkout -- <file>`、`rm` 等破坏性操作，除非用户明确要求。
- `.DS_Store` 已被 `.gitignore` 忽略；除非用户要求，不需要处理。
- 生成的 `DerivedData/`、`.build/`、`xcuserdata/` 不应纳入提交。
- 如果用户要求提交，先生成简洁中文或 Conventional Commits 风格提交信息，再执行 git 操作。

## 9. 后续优先级建议

1. 补充轻量单元测试或可重复的解析测试，优先覆盖 `MarkdownBlockParser`、`JournalStatistics` 和 `JournalEntry` 兼容解码。
2. 增强 Markdown 预览能力，但要保持轻量，不要直接引入大型渲染框架。
3. 优化编辑器体验，例如插入片段后的光标位置、键盘快捷操作、草稿保存提示。
4. 增强统计看板的空状态和极端数据展示。
5. 做真实模拟器或真机视觉回归验证，重点检查 iPhone 竖屏、iPhone 横屏和较大设备。

## 10. 最终回复规范

完成任务后，用中文简洁说明：

- 改了哪些文件和核心行为。
- 执行了哪些验证，结果如何。
- 是否有未验证或受环境限制的部分。
- 如有后续建议，只列与当前任务直接相关的 1-2 项。
