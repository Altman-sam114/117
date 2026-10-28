# MD Journal

原生 SwiftUI Markdown 日记，支持 iPhone、iPad 和 Mac Catalyst。纸本界面、墨绿强调色与中文写作工具让记录保持安静；日记保存在应用私有目录，不设账号或自建日记服务器。

## 功能

- iPhone 原生资料库/详情导航，iPad 与 Mac 分栏；支持搜索、分类、年月分组、删除确认与相邻日记快捷键。
- 标题与正文统一焦点处理，支持 Markdown 快捷插入、列表续写、缩进、预览与 `###` 小节；正文保留 UTF-16 选区和组合输入的跨篇隔离。
- 适配深色、辅助字号和竖横屏；单栏写作宽度上限 760pt，实际详情宽度达到 1120pt 且非辅助字号时可双栏预览。
- 免费外观与写作偏好：跟随系统/浅色/深色纸页，圆润/书页/等宽正文、三档字号和疏朗行距；编辑与预览共用设置，保留系统辅助字号与组合输入。
- 编辑器与设置展示真实保存状态；未写盘、失败与读取保护明确区分，保存失败可主动重试，重复的无变化编辑不延后保存或刷新修改时间。
- 免费完整 JSON 备份与安全合并导入：先校验、预览和确认，只追加新 ID，冲突保留本机版本；读取失败时禁止覆盖原文件，可导出原始字节并重读。
- 默认隐藏多任务预览，不要求开启锁或购买；可选应用锁使用系统设备所有者认证，窗口级遮罩覆盖非活跃内容及 sheet；后台锁定、过期认证拒绝与有限后台保存保持独立。
- StoreKit 2 月/年 Pro 订阅，价格来自真实商品，仅接受已验证且有效的权益；高级功能为按日期/分类筛选的批量 Markdown 与分页 PDF 导出，PDF 可加自定义名称、日期范围与篇数的纸本封面。
- 基础编辑、预览、统计、单篇分享和 JSON 备份始终免费；无广告、跟踪、第三方分析或日记云同步。系统设备备份仍可能包含本机日记。

## 数据与架构

`MDJournalApp` 共享 `JournalStore`、`JournalSubscriptionStore` 和 `JournalAppLockStore`。`ContentView` 拥有导航、选中、筛选和错误展示；所有日记修改均通过 Store，JSON 文件名为 `md-journal-entries.json`，保留 Codable 兼容规则与 ISO-8601 日期。

`EntryEditorView` 负责元数据、正文和布局；`MarkdownBodyTextView` 承载 UIKit 输入与 UTF-16 选区。`MarkdownBlockParser` 轻量解析 Markdown，预览采用 150ms latest-wins 防抖和同文档缓存；`JournalStatistics` 负责统计计算。完整数据流见 [核心流程](md/flow/flow.md) 和 [流程图](md/flow/flowchart.md)。

最低 iOS 16.0、Mac Catalyst deployment target 13.0。工程不默认引入第三方依赖。

## 开发与验证

用户给出目标后，由当前模型自行规划、开发、验证和收口，默认不创建子智能体。计划、编辑范围、进度和恢复点保存在 [work.md](work.md)，完成后清空任务内容；长期规则见 [AGENTS.md](AGENTS.md)。

默认在 `main` 实现并直推 `origin/main`，模型按本轮改动主动发起 GitHub Actions 云端验证，而不是每次 push 自动跑全套。日常使用任务配置指定测试类/方法、脚本测试文件或必要构建平台；完整测试、图片与发布归档保留为显式完整配置。具体参数、选择规则和结果包要求见 [测试规范](md/test/test.md)。

本机仅执行相关静态/轻量检查，例如：

```sh
git status --short --branch
git diff --check
```

**未经用户特别要求，禁止本机构建、XCTest、App/模拟器运行和性能采集，包括 Mac Catalyst。** 用户明确要求本机 iOS 操作时，只能使用 UDID 以 `FAC4325D` 开头的唯一现有模拟器，禁止新建或选择其他设备；云端不限。`script/build_and_run.sh` 是需用户明确授权的本机 Mac 开发入口，不是默认验证步骤。

纯文档只检查 diff、链接和相关文档一致性，不触发 App 构建、截图或发布归档。任务测试只覆盖直接/必要关联影响，部分通过不冒充全量回归；结果必须注明实际被测 SHA、run/attempt 与验证范围，历史证据集中在 [更新日志](update_log.md)。

## 发布边界

[发布配置与提审材料](docs/app-store-release.md) 包含 Bundle ID、商品 ID、商店文案、隐私与支持 URL、账号步骤和审核备注。[隐私政策](docs/privacy.md) 与 [支持页面](docs/support.md) 可作为公开元数据链接。

账号、开发者团队和正式签名后置，不阻塞发布前软件与相关云端测试。云端 unsigned archive、ad-hoc Mac 包、StoreKitTest、合成画布或截图不代表正式签名、真机/Sandbox/TestFlight、上传或审核通过。真实中文输入、VoiceOver、系统认证及锁屏保存需对应设备证据。

## 文档入口

- [AGENTS.md](AGENTS.md)：自主迭代流程、架构与安全规则。
- [work.md](work.md)：当前任务与上下文恢复点，完成后清空。
- [核心流程](md/flow/flow.md) / [流程图](md/flow/flowchart.md)：当前数据流和执行流。
- [测试规范](md/test/test.md)：按影响范围选择的云端验证与证据要求。
- [历史方案](md/prompt/README.md)：按需参考，不是执行前提。
- [更新日志](update_log.md)：版本、实际验证和遗留事项。
