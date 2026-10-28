# MD Journal

原生 SwiftUI Markdown 日记，支持 iPhone、iPad 和 Mac Catalyst。纸本界面、墨绿强调色与中文写作工具让记录保持安静；日记保存在应用私有目录，不设账号或自建日记服务器。

## 当前交付：v0.95 iOS 发布候选

本轮按用户最新指令由多个子智能体按模块并行实现，统一集成和云端验证。手机导航与写作、设置与数据保护、StoreKit 订阅与高级导出分别负责；不再把 A→B→C 串行交接作为开工前提。此前版本的串行验收记录保留在 `update_log.md`。人工最新明确账号、团队与正式签名后置，本轮先完成软件，不将账号配置作为软件收敛阻塞。

当前代码已加入以下功能，完整构建、交易测试、截图与现代 SDK archive 结果必须以本轮最新 SHA 对应结果包为准，不能使用 v0.94 的通过记录代替：

- 手机以原生 NavigationStack 直接绑定 UUID 状态数组，打开日记、返回和重开后同步有效选中项；路径独立于列表的原生选择，iPad 常规宽度及 Mac 保留分栏选择。新建成功后清除搜索与分类筛选，直接打开新日记。
- 标题与正文统一处理完成、预览和写作命令的焦点；长标题、低高度、深色与辅助字号延续纸本布局。UTF-16 选区、中文组合输入和 Markdown 快捷输入边界保持。
- 导航与编辑命令通过原生 FocusedObject 传递稳定场景对象，不再发布函数型 focused values；命令读取当前绑定、离场清空目标，应用锁期间仍逐次拒绝操作。
- 分享在实际传输时生成完整 Markdown；正文展示派生使用有限摘要，避免先物化整篇摘要与每个小节 Markdown。完整词数与小节识别仍需扫描正文，不宣称整体 O(1) 或未经测量的帧率。
- 资料库设置入口提供免费完整 JSON 备份和安全合并导入。导入前校验并预览，只追加新 ID；冲突保留本地版本，过期预览需重新确认。
- 读取本地 JSON 失败后保持独立写保护，新建、修改、删除、导入与 flush 都不能覆盖原文件。首次建库只接受明确的文件不存在错误；暂不可访问保持保护，恢复导出不受导入的 25 MiB 限制。设置中可导出原始文件并重试读取，关闭错误提示不解除保护。
- 可选应用锁使用系统设备所有者身份验证。窗口级遮罩覆盖非活跃内容及已呈现 sheet，同时同步处理本窗口的场景失活、后台与激活通知；后台立即锁定并使过期认证失效。应用锁是界面访问保护，不能替代设备密码或保护另行导出的文件。
- 离开活跃态时同步申请系统有限后台执行时间，再执行 Store 的合并保存；同一 Store 去重在途任务，完成或系统到期只释放一次。申请失败仍尝试保存，不无限续期，也不承诺强制终止或超大文件下必然落盘。
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

功能回归固定 macos-15 / Xcode 26.2 / iOS 26.2，使用一个已存在的云端 iPhone，提前启动后，专用 MDJournalCI scheme/test plan 显式选择本地 StoreKit 配置，先独立检查商店空快照、取消与验签，以及两项导航和真实焦点/切篇；六项预检全部通过后，再串行执行全部 310 项测试并导出 25 张图片，成功再构建两平台，测试失败跳过重复构建且终门仍失败。手机生产 host 临时替换既有前台 key window 的根控制器并完整恢复；所有手机导航用例均使用包含式测试画布，保留系统窗口的原生尺寸。隐私门夹具按被测真实 UIWindowScene 的状态和通知传递生命周期。筛选空态同时检查数据、导航和真实渲染文字，详情图片等待导航转场结束。预检失败会阻止完整回归并保留失败状态，仍执行另一项预检取证；测试期间每 25 秒采样存活宿主，失败时保留可导出的诊断。另一个并行 job 使用 Xcode 26.2 / iPhoneOS 26.2 构建并检查 Release 设备 archive，完全不启动模拟器。

验收需要下载最新同 SHA/run/attempt 的两个未加密 artifact，核对 manifest、JUnit、日志、xcresult、PNG、ZIP digest/CRC/逐文件哈希及 archive SDK/架构/资源。实际计数和结果见 [测试规范](md/test/test.md) 与 [更新日志](update_log.md)。StoreKitTest 是本地商店配置测试，不能冒充 Apple Sandbox 或真实付费交易。

商店尺寸素材独立保存于功能包的 `app-store-screenshots/`，保留原 25 张审查图：iPhone 资料库与详情从云端原生窗口直接以 3x 渲染为 1179×2556；iPad 为生产 ContentView 的完整 1366×1024pt 画布，直接以 2x 渲染为 2732×2048。PNG 不从旧图放大，打包检查尺寸、无透明通道、完整性和来源摘要；iPad 画布不代表已在 iPad 设备运行，仍需逐图确认及发布前设备验收。

DEBUG 的 XCTest 宿主默认窗口只安装空根视图，不保留另一套生产导航、焦点或隐私视图树；专项用例自行安装真实生产视图。首个手机导航用例使用完整 JournalPrivacyGate → ContentView 组合和独立关闭的锁，先等待真实活跃 scene 且无遮罩，再执行全部打开、返回、重开和截图断言。宿主也不自动查询订阅，防止测试配置建立前的 Sandbox 查询与本地 StoreKit 会话竞争；每个交易测试仍显式创建真实订阅 Store 和会话，自动 transaction listener 也单独实测。普通开发启动和 Release 保持完整生产界面、自动加载、监听和回前台刷新。

最近 `5c3ad48` / run `40624082017` 已下载核对：原三项预检通过，完整 309 项为 303 通过、6 失败、无跳过；SwiftUI 程序化状态警告与导航反馈警告均归零。现代设备 archive 通过，仍 unsigned、未上传。失败证据证明命令 router 的旧 Binding 确实误改前一篇；同一测试内创建两个 StoreKit 会话还导致本地交易文件失效及后续污染，因此不能放行，也不能把图片文件齐全视为有效 Pro 状态证明。

本轮将完整编辑命令目标安装移到稳定外层，显式捕获当前 Binding；GeometryReader 只更新布局，不得覆盖目标日记。按钮与菜单统一走同一 router，切篇绑定不匹配时拒绝命令。取消与签名验证拆成各自单会话测试并显式异步清理；云端先运行两组各 3 项有针对性的预检，再执行完整 310 项及原构建/图片门槛。

正文输入桥在初始正文/选区配置完成后才安装 delegate，程序化同步期间不回写 SwiftUI Binding；marked text、UTF-16 和一次性发布 token 规则保留。新增真实桥回归要求初始化及外部同步零 setter，用户选区仍准确回写；当前源码共 310 项。取消和签名失败分别在独立测试方法中使用单个真实 StoreKit 会话，异步 teardown 显式清除并读回两种 API 模拟错误，后者仍须先实际购买并验证 Pro，再注入精确签名错误并要求生产权益读取器拒绝。新 SHA 必须以自己的完整云端结果为准。

`02fe8a4` / run `40621962623` 的三次等价 Debug 模型派生测量中，约 15.9 万字符正文的旧路径中位数 204.01ms、有界路径 53.37ms；这只测同步模型派生，不代表输入延迟、UI 帧率或内存分配。

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
