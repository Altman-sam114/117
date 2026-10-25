# MD Journal

原生 SwiftUI Markdown 日记，支持 iPhone、iPad 和 Mac Catalyst。纸本界面、墨绿强调色与中文写作工具让记录保持安静；日记保存在应用私有目录，不设账号或自建日记服务器。

## 当前交付：v0.95 iOS 发布候选

本轮按用户最新指令由多个子智能体按模块并行实现，统一集成和云端验证。手机导航与写作、设置与数据保护、StoreKit 订阅与高级导出分别负责；不再把 A→B→C 串行交接作为开工前提。此前版本的串行验收记录保留在 `update_log.md`。

当前代码已加入以下功能，完整构建、交易测试、截图与现代 SDK archive 结果必须以本轮最新 SHA 对应结果包为准，不能使用 v0.94 的通过记录代替：

- 手机以原生 NavigationStack 直接绑定 UUID 状态数组，打开日记、返回和重开后同步有效选中项；路径独立于列表的原生选择，iPad 常规宽度及 Mac 保留分栏选择。新建成功后清除搜索与分类筛选，直接打开新日记。
- 标题与正文统一处理完成、预览和写作命令的焦点；长标题、低高度、深色与辅助字号延续纸本布局。UTF-16 选区、中文组合输入和 Markdown 快捷输入边界保持。
- 分享在实际传输时生成完整 Markdown；正文展示派生使用有限摘要，避免先物化整篇摘要与每个小节 Markdown。完整词数与小节识别仍需扫描正文，不宣称整体 O(1) 或未经测量的帧率。
- 资料库设置入口提供免费完整 JSON 备份和安全合并导入。导入前校验并预览，只追加新 ID；冲突保留本地版本，过期预览需重新确认。
- 读取本地 JSON 失败后保持独立写保护，新建、修改、删除、导入与 flush 都不能覆盖原文件。首次建库只接受明确的文件不存在错误；暂不可访问保持保护，恢复导出不受导入的 25 MiB 限制。设置中可导出原始文件并重试读取，关闭错误提示不解除保护。
- 可选应用锁使用系统设备所有者身份验证。窗口级遮罩覆盖非活跃内容及已呈现 sheet，解锁入口沿用应用明暗主题的强调色；前后台切换使过期认证失效。应用锁是界面访问保护，不能替代设备密码或保护另行导出的文件。
- iOS 日记文件显式使用系统首次解锁后可访问的文件保护。保留用户数据的系统备份；隐私说明明确 iCloud 设备备份可能包含日记，应用没有自行进行日记云同步。
- 原生 StoreKit 2 月度/年度 Pro 订阅，仅接受已验证且有效的白名单订阅，处理待批准、取消、恢复、到期、退款撤销与有限宽限期。仅对已验证交易所属组查询订阅状态，未订阅用户不会因目录中有方案而额外等待组状态。价格来自真实 App Store 商品；没有商品时明确不可购买。
- Pro 增加按日期和分类筛选的批量 Markdown 与分页 PDF 导出。生成前后核对有效期限，到期刷新先清除过期权益，系统查询等待不能延长缓存权限。Markdown 按 64 KiB 字节块生成，PDF 按篇排版并自动分页，均支持取消生成；单篇排版和最终文件仍需要内存。基础编辑、预览、统计、单篇分享与 JSON 备份免费，订阅到期不锁住日记。
- 本地隐私页、公开隐私/支持文档、Apple 标准 EULA、Face ID 用途说明与 PrivacyInfo.xcprivacy 已接线。公开链接与商品 ID 由显式 `MDJournal/Info.plist` 提供，云端检查最终 App 中的实际值。没有广告、跟踪或第三方分析 SDK。

## 数据与核心结构

`MDJournalApp` 共享 `JournalStore`、`JournalSubscriptionStore` 和 `JournalAppLockStore`。`ContentView` 拥有导航、选中项、搜索/分类和错误展示。所有日记修改均通过 Store；JSON 文件名为 `md-journal-entries.json`，原有 Codable 兼容规则与 ISO-8601 日期格式保持。

`EntryEditorView` 负责元数据、标题、正文与编辑/预览布局；`MarkdownBodyTextView` 承载 UIKit 输入和 UTF-16 选区。`MarkdownBlockParser` 解析轻量 Markdown，预览采用 150ms latest-wins 防抖与同文档内联缓存。`JournalStatistics` 负责计算，视图消费缓存和结果。

推荐用 `###` 组织小节，支持列表、待办、引用、有序列表与代码块。资料库按年月组织，保留搜索、分类、删除确认与相邻日记快捷键。宽度达到 1120pt 且非辅助字号时可双栏预览，单栏写作限制为 760pt；低高度减少头部和工具占用。

## 验证与运行

默认只在本机执行轻量检查，完整构建、XCTest 和图片都在 GitHub Actions：

```sh
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournalTests)
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s script/tests -v
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

功能回归固定 macos-15 / Xcode 16.4 / iOS 18.5，使用一个已存在的云端 iPhone，提前启动后，专用 MDJournalCI scheme/test plan 显式选择本地 StoreKit 配置，先独立检查真实交易环境与两项导航，再串行执行全部 306 项测试并导出 25 张图片，成功再构建两平台，测试失败跳过重复构建且终门仍失败。手机生产 host 临时替换既有前台 key window 的根控制器并完整恢复；所有手机导航用例均使用包含式测试画布，保留系统窗口的原生尺寸。隐私门夹具按被测真实 UIWindowScene 的状态和通知传递生命周期。筛选空态同时检查数据、导航和真实渲染文字，详情图片等待导航转场结束。预检失败会阻止完整回归并保留失败状态，仍执行另一项预检取证；测试期间每 25 秒采样存活宿主，失败时保留可导出的诊断。另一个并行 job 使用 Xcode 26.2 / iPhoneOS 26.2 构建并检查 Release 设备 archive，完全不启动模拟器。

验收需要下载最新同 SHA/run/attempt 的两个未加密 artifact，核对 manifest、JUnit、日志、xcresult、PNG、ZIP digest/CRC/逐文件哈希及 archive SDK/架构/资源。实际计数和结果见 [测试规范](md/test/test.md) 与 [更新日志](update_log.md)。StoreKitTest 是本地商店配置测试，不能冒充 Apple Sandbox 或真实付费交易。

商店尺寸素材独立保存于功能包的 `app-store-screenshots/`，保留原 25 张审查图：iPhone 资料库与详情从云端原生窗口直接以 3x 渲染为 1179×2556；iPad 为生产 ContentView 的完整 1366×1024pt 画布，直接以 2x 渲染为 2732×2048。PNG 不从旧图放大，打包检查尺寸、无透明通道、完整性和来源摘要；iPad 画布不代表已在 iPad 设备运行，仍需逐图确认及发布前设备验收。

DEBUG 的 XCTest 宿主默认窗口只安装空根视图，不保留另一套生产导航、焦点或隐私视图树；专项用例自行安装真实生产视图。首个手机导航用例使用完整 JournalPrivacyGate → ContentView 组合和独立关闭的锁，先等待真实活跃 scene 且无遮罩，再执行全部打开、返回、重开和截图断言。宿主也不自动查询订阅，防止测试配置建立前的 Sandbox 查询与本地 StoreKit 会话竞争；每个交易测试仍显式创建真实订阅 Store 和会话，自动 transaction listener 也单独实测。普通开发启动和 Release 保持完整生产界面、自动加载、监听和回前台刷新。

签名失败回归先完成真实购买，再要求 StoreKit 的 latest/currentEntitlements 返回未验证交易及精确签名错误，由生产权益读取器拒绝；这不等同于购买 API 的未验证文案分支已执行。冷启动批准、退款与到期等待真实状态传播后才断言。最近提交 `e76f69f` 的功能日志为 149 项启动、144 项通过、1 项场景前置失败、3 项 watchdog 和 1 项未结束；xcresult 未封口，不能验收完整图片。现代设备 Release archive 独立通过，仍 unsigned、未上传。本轮追加的数据保护、导出内存/取消、真实场景夹具与 StoreKit 专用计划须以新的同 SHA 云端结果核验，尚不宣称超时已消除。

本机 iOS 编译/运行必须人工明确要求，而且只能使用 UDID 以 `FAC4325D` 开头的那台既有模拟器；禁止创建或选择其他设备。云端不受此限制。Mac 人工开发入口为 `./script/build_and_run.sh`；本轮未启动本机 App 或模拟器。

## App Store 提交

[发布配置与提审材料](docs/app-store-release.md) 包含 Bundle ID、商品 ID、商店文案、隐私与支持 URL、账号步骤和审核备注。[隐私政策](docs/privacy.md) 与 [支持页面](docs/support.md) 可作为公开元数据链接。

Apple 自 2026-04-28 起要求 Xcode 26 和 iOS 26 SDK。云端设备 archive 明确标记为 unsigned；需要真实团队的 Distribution 签名、App Store Connect 商品与合同、实际定价、开发者联系/版权/分级信息后才能上传。不能把构建通过、Mac 内部包或本地 StoreKit 测试等同于已经可提交或已过审。

真实设备上的中文输入、VoiceOver、系统认证、锁屏保存、Sandbox/TestFlight 与正式签名仍须按实际结果核验。项目不包含服务器、日记账号、第三方依赖或日记数据上传功能。

## 项目入口

- `AGENTS.md`：当前协作规则、文件边界与安全限制。
- `md/flow/flow.md` 和 `md/flow/flowchart.md`：当前真实状态流及云端执行流。
- `md/test/test.md`：检查层次、云端门槛和证据边界。
- `md/prompt/`：版本化方案；v0.95 初稿的串行前提已由本轮人工并行指令覆盖。
- `update_log.md`：版本、实际验证证据与遗留事项。
