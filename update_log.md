# 项目版本更新记录

本文记录 MD Journal 的正式版本、重要维护事项、关键决策和遗留问题。它不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。

## 当前状态

- 当前任务 v0.95：按用户最新指令改为模块并行，整合手机写作、长文派生、设置/隐私/数据安全、StoreKit订阅/高级导出与iOS26 Release archive；本轮新SHA完整云端结果待实际下载核对，不复用旧通过记录。
- v0.90 最终云端基线通过：`7283b1e4116bd6c776019aa4ff772c97856567b0`，run `39806459795` attempt `1`，artifact `mdjournal-ci-v0.90-main-7283b1e-run39806459795-attempt1`（ID `12439121176`，8335208 bytes，SHA-256 `ff47f396f082f697a5b17018bf8424b64a3674359682037e7eb9afc7bec9048e`）。245/245 XCTest、11张图、588个未加密ZIP文件、CRC/fresh extract/逐文件SHA-256均通过。用户后续要求“不多开子智能体”，已停止子智能体；这份最终结果包由当前线程串行核对，不标记独立 Agent C。v0.91 已完成性能改动和云端Mac内部包，最新CI受重复模拟器启动阻塞未通过；本地只读包核对通过，不作发布验收。

- 当前阶段：v0.95 iOS发布候选集成；v0.94/14854d3/run40054782075/attempt1已独立下载核对起点629文件/257项/16图。用户已明确不再按A→B→C逐轮等待，最新规则写入AGENTS顶部。
- 当前应用：原生 SwiftUI Markdown 日记应用，支持 iOS/iPadOS，并通过 Mac Catalyst 构建 macOS app。
- 当前数据：本地 JSON 持久化，文件名 `md-journal-entries.json`。
- 当前测试基线：257项XCTest（含22项JournalStoreTests）、8项纯Python设备fixture、16张生产图、iOS/Catalyst Debug与universal Mac Release。v0.94实现de710e1/run40053762957/attempt1已通过当前线程串行下载复核；Swift源码编译警告0。历史版本数量与独立C证据保留在各版本条目，不代表当前SHA。
- v0.85 docs-close 已完成：最终 docs HEAD 为 `ae8e85073a13b7a50be003d7dc54d3a52173faf1`，run `32646077288`、attempt `1`，artifact `mdjournal-ci-v0.85-main-ae8e850-run32646077288-attempt1`，artifact ID `9494991741`，size `457085` bytes，digest `sha256:3aede2a533be7d38db1ff6ba4f97693a2c51671ad26f4899cf5b77019b2803ce`；static checks、generic iOS build、Mac Catalyst build 和 XCTest 四阶段均为 `success`，XCTest 为 `205/205 passed`，481/481 ZIP entries 全部未加密且 CRC、fresh extract、逐文件 SHA-256 均通过。Agent C 已从 `/private/tmp/mdjournal-c-review-32646077288/` 下载并核对。
- `JournalEntryNavigationTests` 覆盖按当前数组顺序切换较新/较早日记、首尾不循环、空/单篇/无效 selection、搜索/分类筛选快照驱动的 selection repair 与相邻导航、命令元数据和跨导航/写作/Markdown/`⌘N` 快捷键唯一性。
- 当前已知限制：本轮没有运行本机App/模拟器或重探CoreSimulator；真实Mac输入、IME、VoiceOver与性能未实测，正式Developer ID签名、公证与公开发布验收尚未完成。
- 当前远端状态：本地仓库已配置 `origin/main`，Agent B 可直推触发 GitHub Actions；远端 URL 中的访问 token 不写入文档或最终回复。
- v0.86 bridge 行为保持：Coordinator 仅在正文实际发布时记录正文与选区 token；选区变化不建立正文快速路径。非 marked 更新只有正文和 UTF-16 选区都匹配才消费一次性快速路径，正文不同、选区不匹配或已消费时仍走外部同步；marked text 延迟覆盖。本轮不改 bridge。

### v0.95 / iOS 发布候选并行集成（实现完成，云端待核）

日期：2026-10-24。

- 人工从原手机UI/性能目标扩展为设置、隐私、安全和真实高级订阅，并明确要求子智能体按模块直接并行。初稿三轮串行计划已覆盖：B负责手机导航/焦点/延迟分享/有界派生，A负责Store保护/备份导入/应用锁/设置隐私，C负责StoreKit和两种Pro导出，主线程负责工程、现代SDK、集成和验收。不声称本轮有独立Agent C验收阶段。
- 手机compact改原生NavigationStack+UUID value link，regular仍SplitView；新建成功才清筛选并直达新ID；标题与正文完成/预览/写作焦点统一，原UTF16/marked-text bridge不改。分享延迟生成完整Markdown。正文展示流式有界派生，旧summary作精确语义对照；仍完整扫描metrics，不预称帧率或速度。
- Store新增独立readFailure保护，坏JSON/重复ID原字节保留，所有mutation/flush拒写，关闭提示不解除；恢复导出与重读、安全JSON预览合并（只追加、不覆冲突、revision防过期）。iOS显式系统文件保护，免费备份不截断原文，导入25MiB/10000篇限制已说明。
- 设置入口、系统所有者认证App锁、同步window隐私shield覆盖sheet及键盘、过期认证防绕过、隐私/支持页和PrivacyInfo UserDefaults CA92.1。root也在应用锁期间禁用并guard所有菜单/快捷动作，防隐藏视图focused action绕过。日记不自建云同步，但诚实说明系统设备备份可能包含内容。
- StoreKit2真实月/年Product、价格/期限、验证/待批准/取消/恢复/管理/撤销/到期/宽限期；Pro新增日期分类筛选的完整Markdown集和CoreText分页PDF，后台生成前后都核有效权益，旧写作/统计/分享/JSON备份免费。.storekit仅测试资源，无DEBUG假权益开关。
- 保留257项和16图基线，新增生产host导航/真实responder、保护/导入/认证、StoreKitTest真实本地交易、分页/正文末尾与bounded等价和性能JSON；当前目标25图。Python fixture由8增至13（5项archive拒绝边界）。最终XCTest数量以源码声明和最新xcresult一致为准。
- 云端并行保留Xcode16.4/iOS18.5稳定全测与Mac内部包，新增Xcode26.2/iPhoneOS26.2 generic Release设备archive。核实际arm64/platform2/SDK、图标/隐私/FaceID/加密说明与文件/ZIP哈希；产物明确unsigned/未上传，避免重蹈现代模拟器冷启动历史阻塞。
- 关键文件：ContentView/Editor/List/App、Store/Writer/BodyPresentation、Bounded/Backup/AppLock/Subscription/PremiumExport及相关Views与测试、PrivacyInfo、project、workflow、archive/verify脚本和13项Pythonfixtures；README/test/flow/flowchart/AGENTS与docs隐私支持和发布材料同步。
- 未本机build/XCTest/App/simctl/Instruments。现有本机只有开发证书，未发现正式Distribution签名条件；未复制私钥或伪造账号商品。Apple Team/App记录、商品/价格/合同税务/银行、开发者法定联系方式/版权/分级、Sandbox/TestFlight及真机输入/VoiceOver/系统认证仍需对应实际证据。不能宣布已上传App Store或已通过审核。
- 实际本机轻检退出0：全应用/测试Swift parse、project与PrivacyInfo plist、13/13纯Pythonfixture、14个workflow run块bash语法/3个Python heredoc/全部Python AST、asset及StoreKit JSON、全部源文件注册、301项XCTest声明与25图矩阵、git diff --check。未做本机完整构建。提交/push与最新两个artifact、截图和性能结果仍需随后实际记录。
- 首轮整合1284abd已推，空标题fixture的有意尾空格改显式插值后追加c503996并推main；旧run40065066892请求取消，不作验收。c503996/run40065109562/attempt1现代Release明确失败：Xcode26.2/SDK26.2编译报告JournalAppLockStore.init在state初始化前读取wrapped self.isEnabled。已按实际错误改为局部enabled值初始化两属性，不改变认证语义；同步补政策中iOS删除/Mac容器区别、支持页导入上限，并更正初始资料库图来源描述。新SHA须重新云端验证，失败包不放行。

- 第二轮85fb7ec/run40065704141/attempt1现代设备archive已独立下载通过：artifact12548953625（2463324bytes，digest fbfab529af34d8017f33f81125216e01755bf82f3f99d5a5608d71f2bd30dd00），实际iphoneos26.2/Xcode2620/arm64/build205.1，13外层文件与嵌套设备archive全部11文件哈希/CRC/未加密通过，JUnit1/0/0/0、Archive xcresult succeeded，仍unsigned未上传。功能明确失败于JournalSubscriptionTests:252 lazy closure缺显式self，TEST BUILD FAILED，301项与25图均未执行；不使用wrapper step conclusion冒充通过。仅修辅助函数捕获语义，另优化CI为先全测/25图再两平台构建，失败时跳过重复构建但最终六阶段全success门槛不变。下一SHA仍须两个自己的包。

- 追加修复`2cd328e8131ec7b474b00267f4776269915f6288`已推origin/main，run`40066534128`/attempt`1`。最新现代archive已按该SHA独立下载核验：artifact `mdjournal-ios-release-v0.95-main-2cd328e8131ec7b474b00267f4776269915f6288-run40066534128-attempt1`（ID12549104689，2463284bytes，SHA256 f5af2e9418855c953380f272d2b6c5f499439789e3fb1222ee31c443f5ebc59b），13外层文件、25条内ZIP项目、11个archive文件的身份/digest/CRC/未加密/独立解压/逐文件哈希及只读verifier均通过。JUnit1/0/0/0，Archive xcresult build/action succeeded，构建错误与警告0；实际iPhoneOS26.2/Xcode2620(17C52)/arm64/iOS16.0/1.0(build206.1)，Release无测试商品配置。内设备archive ZIP 2438127bytes，SHA256 b0cc54c5078aaa5cf0349c59800ceec0121cfea9dfb0081353bb6dad9fa1e9e9。缓存`/private/tmp/mdjournal-c-review-40066534128/`；仍unsigned、未上传。
- 同run功能明确失败：301项实际执行，6个用例失败、12条失败记录（其中3条wait throw的unexpected）；新增手机host导航/预览/regular切换、安全window渲染、订阅到期与自动启动时序暴露问题，compact详情图缺失，不能放行。本轮按所属模块追加诊断修复，全部301项和25图要求保留。工作流同时改为可读xcresult在失败时也保存真实summary，仍保留执行失败状态和六阶段全success终门；订阅页图片说明更正为购买前真实catalog，导出页才是verified权益。
- 该失败包已下载核对：artifact12548929306，86036845bytes，SHA256 50139eb0370cbe74cec4b8455e4b26d4c4e836738be7bc665a5d4c05156bf546，1710个ZIP文件的身份/未加密/CRC/独立解压与gh下载逐hash通过；raw实际为295pass+6failed，24张图、只含已执行的测试xcresult，其他三个构建按规则跳过。此包的7项有界派生测试通过，159190 Character/325830 UTF8字节/40小节的Debug同步模型基准，旧路径3次中位253.091708ms，新路径49.3695ms，结果等价；不代表整轮通过、真机帧率或输入延迟。
- 逐图和归档实物另发现原自动Info忽略两项自定义INFOPLIST_KEY，实际缺隐私/支持链接，导致订阅页禁购；先前archive仅通过旧结构门槛，不能当可售配置通过。已新增显式MDJournal/Info.plist，Debug/Release合并公开URL和两商品ID，并增加实际Bundle断言与archive拒绝条件；新版只读verifier确实拒绝2cd328e实物，15项Pythonfixtures通过。手机/安全host改接现有前台UIWindowScene、恢复keywindow、同步UIKit size class、触发List真实主动作，保留原导航/焦点/遮罩断言；订阅生产初始化并行商品与权益刷新，目录去重及加载状态只覆盖商品请求，verified终态覆盖旧缓存，原测试补回归。所有新增修复须以新SHA自己的完整结果重新验收。
- 本次追加修复轻检全部退出0：全应用与全测试Swift parse，project/Info/PrivacyInfo三个plist，15/15纯Pythonfixtures，workflow YAML/14个bash run块/3个Python heredoc和脚本AST，asset/StoreKit JSON，源文件注册、301项声明和25图矩阵，git diff --check。原始实物缺URL的拒绝回归已实际运行。未本机完整build、XCTest、App、simctl；下一提交继续云端全测及现代archive，不复用旧结果。
- 上述修复已以`f568ee59c6f43deb9027698af12e5745b8e2a3ed`推main，run`40068172166`/attempt`1`现代archive通过新增严格检查，实际App含两条正确公开HTTPS链接和月/年ID，链接均200；iPhoneOS26.2/Xcode2620(17C52)/arm64/iOS16.0/1.0(build207.1)。artifact `mdjournal-ios-release-v0.95-main-f568ee59c6f43deb9027698af12e5745b8e2a3ed-run40068172166-attempt1`（ID12549833677，2470935bytes，SHA256 47e3c0ea8a90b040dd14942cb2a67b3186b83612f209beccdb5ca94414065cdd），13外层文件/25条内ZIP/11个archive文件身份、未加密、CRC、digest、独立解压逐hash与新verifier通过，JUnit1/0/0/0，Archive xcresult succeeded且错误/警告0。内archive ZIP2446770bytes，SHA256 28beee710b428a930c0f01639f12779ed49309b37ad9ea7ea59d0dc6d7a8bd18，仍unsigned未上传。
- f568同run功能未完成：实际前75项通过（含7项有界派生），第76项compact筛选中新建host在06:01:20开始后出现SwiftUI “Modifying state during view update”及持续UI更新，720秒全局限制终止。未收尾xcresult、无完整summary/25图，订阅及后续用例未执行。失败artifact12550478250（2825142bytes，SHA256 df85da51564c3292cf03917e0e948b8e50d198e55d6ba3233cd797b476fe9f0b）166个文件的身份/未加密/CRC/独立解压逐hash核对通过，不能当功能验收。已移除compact List原生选择对同一selectedID的第二回写入口，保留SplitView原生选择及全部301项/25图；四个手机host用例增加60秒逐用例watchdog，CI默认/最大180秒且整体720秒不变，超时仍失败，不以延时或删断言掩盖导航问题。新SHA仍需全套实跑。
- 手机选择修复本机轻检退出0：全应用/测试Swift parse、三项plist、15/15纯Pythonfixture、workflow YAML与14个shell块/内嵌Python AST、301项声明/25图矩阵和4个host watchdog一致性、git diff --check；另只读SDK XCTestCase头文件和xcodebuild手册确认超时API/参数存在，未本机build、XCTest或启动模拟器。
- `2cf8980a1e46b2fcb2032a0712cfef58b91605ed` 已推main，run`40069875397`/attempt`1`现代archive独立下载核验通过：artifact `mdjournal-ios-release-v0.95-main-2cf8980a1e46b2fcb2032a0712cfef58b91605ed-run40069875397-attempt1`（ID12551210517，2471773bytes，SHA256 e6b21c27a49595526e553e64739286e1d4b4869150f24af2b7a001c01b06a03a），13外层文件/25条内ZIP/11个archive文件的身份、未加密、CRC、digest、独立解压逐hash及严格verifier通过。JUnit1/0/0/0，Archive xcresult succeeded，错误/警告0；实物iPhoneOS26.2/Xcode2620(17C52)/arm64/iOS16.0/1.0(build208.1)，两条HTTPS链接及月/年ID正确，公开URL均200。内archive ZIP2447300bytes，SHA256 ecceb4c70872ff322ab566a30646a7fbcccea241c112282427fd25a13dbb1c52；仍unsigned未上传。
- 同run功能日志已确认前75项通过，第76项compact create在06:28:19开始，06:29:17明确触发1分钟watchdog，随后宿主继续更新；移除List原生选择尚不足以解决超时。旧日志缺动作阶段标记，不能把卡点归于新建之后。已准备更严格的新建fixture：Gregorian初始两行确实渲染、阻断筛选下真实空态可见后才调用生产create，保留新ID/清筛选/编辑器/持久化全部断言。并将四项手机host隔离为既有key window临时替换root并完整恢复，以排除同scene双focusedSceneValue树这一已确认夹具变量；不删除生产快捷键或焦点功能，不宣称已证实根因。新CI在测试失败后增加有外部超时的宿主sample/xcresult diagnostics；下一SHA仍需301项/25图及两个自己的包。
- 上述夹具/诊断补强本机轻检退出0：全应用与测试Swift parse、project/Info/PrivacyInfo三个plist、15/15纯Pythonfixture、workflow YAML/14个bash块/3个Python heredoc及脚本AST、asset/StoreKit JSON、58个Swift源注册、301项声明/25图与4项host恢复/watchdog一致性、git diff --check。仅语法和静态检查，不代替类型检查或运行验收；未本机build/XCTest/App/模拟器。
- 2cf完整失败包后续已独立核对：artifact `mdjournal-ci-v0.95-main-2cf8980-run40069875397-attempt1`（ID12551740433，6676402bytes，SHA256 af8013b7250d74d893b71326ba52387fbd6b22bc55e1f399d1fee114495fa526），361文件身份/未加密/CRC/独立解压逐hash通过。完整日志去重为148项启动、142项通过、2项有限失败、3项watchdog、1项未完成，发生3次runner重启；不是301项完整结果。手机后仍执行了Security10、Statistics9、Store22、PremiumExport5和Subscription6纯逻辑并通过，不能说订阅全未运行。NavLink未push、Done未关标题键盘失败；compact create/宽窄导航/真实StoreKit取消验证分别60/60/180秒超时，PendingApproval未结束，summary0B且xcresult缺Info。只读恢复3份spindump并记录来源哈希；订阅时App低CPU异步等待、storekitd数据库队列停滞，仍不能确定哪个Swift await，不能据此盲改生产。
- 单窗夹具补强`0ff66bc217ddb31a67b93c3c325289a07de2be9e`已推main，run`40070923331`/attempt`1`现代archive实包严格核验通过：artifact `mdjournal-ios-release-v0.95-main-0ff66bc217ddb31a67b93c3c325289a07de2be9e-run40070923331-attempt1`（ID12550993228，2473313bytes，SHA256 86a29fb9dda62520c0d4bbb294595cf0fe71ed1b357cbe9ae535a2c2749e4f9a），13外层文件/25条内ZIP/11个archive文件身份、未加密、CRC、digest、独立解压逐hash与verifier通过。JUnit1/0/0/0，Archive succeeded且源码/构建警告0；实物iPhoneOS26.2/Xcode2620(17C52)/arm64/iOS16.0/1.0(build209.1)，公开URL均200，月/年ID正确。内archive ZIP2448220bytes，SHA256 6f863574188f3e7920ab91370ab31cf040bf04a3d5a79cbce177d948b057a028；仍unsigned未上传。新手机日志已证明挂载、初始两行和失败后的窗口恢复均返回；筛选空态复合条件、列表激活、标题Done仍有限失败，宽窄切换仍60s超时，单窗隔离不能当整体验收已通过。
- 继续按真实证据补强测试：公开集合视图选择/主动作顺序、自动化子树与FocusState/真实responder对照，以及宽窄切换的逐步标记；保留全部导航/焦点断言。StoreKit取消与未验证测试原先只断言未解锁，普通购买错误也可能假绿；现保留真实SDK购买并要求取消无错误文案、未验证进入精确错误分支、isPurchasing复位，同时读回注入错误并即时记录每个SDK阶段。生产订阅逻辑未因模拟器服务停滞而盲改；下一SHA仍需完整301项/25图及同SHA两个结果包。
- 0ff完整功能包已核：artifact `mdjournal-ci-v0.95-main-0ff66bc-run40070923331-attempt1`（ID12551453767，178173371bytes，SHA256 eb819055b6342da4df90299ed4d0f846def851e5b8269708712535115100c6e2），2079文件的身份、未加密、CRC、双下载与独立解压逐hash通过。可读xcresult与去重日志一致为301实际执行/294通过/7失败/0跳过、3次重启，无总时限截断；手机3项有限断言失败与regular60s、订阅cancel180s/pending180s及refund末断言失败。24张PNG已导出，缺compact-detail使矩阵失败；其余平台构建按规则跳过，不能放行。cancel spindump明确storekitd某队列等待自身的deadlock，pending只有等待服务队列、无同样Deadlock头，App均低CPU异步等待。regular附件仅No samples，不能假称有主线程证据。真实云系统日志确认退款状态在断言之后约1.1秒才更新，已改为有界等待真实撤销传播，保留原权益断言。性能附件同159190字符/325830UTF8/40小节、Debug各3次语义等价，中位数旧221.212334ms、新52.689208ms，仅模型同步派生，不是UI/输入/分配测量。
- 本次逐图先核设置/隐私/锁及3张Pro和compact资料库8图；实际商品价格、可购买/不可购买内容、辅助字号与锁遮罩均显示。仅发现UIKit解锁按钮沿用系统蓝色，已接入动态JournalAccent主题，44pt点击区和认证边界保持，不为此新增镜像实现的测试；最终仍需新SHA自己的完整25图。手机夹具补强未删生产快捷键或编辑逻辑；StoreKit reader追踪仍调用真实生产SDK。
- 0ff云系统日志还确认测试配置前App自动查询Sandbox目录，会话建立时切到XcodeTest且有并行交易同步；cancel配置reset/clear已返回，之后才进入catalog/初始权益链，不能把它说成已执行invalidSignature购买。已在App接线中仅对DEBUG XCTest宿主关闭全局订阅自动启动/前台刷新，让各交易测试拥有会话；显式真实Store、自动监听用例与全部301项保留，普通DEBUG与Release仍自动启动。不预称该环境隔离已消除daemon停滞，仍待新SHA云端实测。
- 本次10文件整合本机轻检均退出0：全应用Swift DEBUG分支和测试parse、三plist、15/15纯Pythonfixture、workflow YAML/14shell/3Python heredoc与脚本AST/bash、9资源JSON（含实际storekit）、58源注册、301项/25图、git diff --check。未做本机build/XCTest/App/模拟器；普通与DEBUG语法检查不代替云端类型检查和交易/交互运行。

### v0.94 / 界面验收收尾（实现云端通过）

日期：2026-10-24。

- 从最新main/cc46e09且干净工作区开始，先完整复核v0.93的257项/16图/双平台与Mac包，再针对图片实际问题修正，不启动子智能体。
- 资料库新建按钮改独立图标与可换行全文，辅助字号隐藏Mac快捷键提示；新增JournalOnAccent四外观颜色并显式用于资料库/空库/详情空态主按钮，修复深色浅绿底白字低对比。统计辅助字号隐藏装饰图标，文字占满宽度。
- 扩展已有语义颜色用例，断言实际UIColor在浅/深和普通/高对比下的主按钮色对比至少4.5:1；保留257项和16图。四处预览测试显式parseDocument参数，清理Swift弃用警告，不改解析/调度/断言。
- 关键文件：JournalTheme、JournalOnAccent.colorset、EntryListView、EmptyStateView、StatisticsDashboardView、JournalInterfaceTests、MarkdownPreviewTests、workflow VERSION和版本化prompt；README/test/flow/flowchart同步。
- 本机只轻量检查，不改持久化/缓存/IME/UTF16/焦点/部署版本/第三方依赖；正式签名、公证、真实Mac输入与性能仍未完成。
- 实际轻量检查全部退出0：应用与测试`swiftc -parse -parse-as-library`、project `plutil -lint`、8/8纯Python设备fixture、workflow YAML/11个run块bash语法/2个Python heredoc及全部Python AST、8份asset JSON、257个XCTest声明/16图矩阵一致性、`git diff --check`。四格资源色对比独立计算为7.24/8.91/10.17/13.06:1，实际UIColor解析断言随后在云端通过。本机没有build/XCTest/simctl/App。
- 实现提交`de710e1352dae2492289333c2f7e4948a37cd278`已推origin/main；run`40053762957`/attempt`1`六阶段success，257/257 XCTest、四份xcresult实际请求阶段succeeded、6项JUnit为0失败/错误/跳过，实际UIColor对比断言通过，Swift源码编译警告0。artifact `mdjournal-ci-v0.94-main-de710e1-run40053762957-attempt1`（ID12544597517，9227178bytes，SHA256 1eb659a02e1913eb441344a4aa8ebb01cd759b0890807534fd5b4fafd4357ab4）。当前线程下载至`/private/tmp/mdjournal-c-review-40053762957/review-g9xxqd2q/`核对629个未加密文件、digest/CRC/独立解压与gh下载逐文件SHA256、manifest/JUnit/log/xcresult；16图逐张确认三处视觉问题已修正，输入身份和选区回归继续通过，不标独立Agent C。
- Mac `MDJournal-v0.94-mac-universal-de710e1.zip`（1608580bytes，SHA256 68d2e07e19e8c1d54baa1c8e742f23418dae8c7059d4e3f26d2698df3db31411）为Release 1.0/build201.1、最低macOS13.0、arm64+x86_64。另以本地只读解压核对平台6、图标、ad-hoc签名、完整内容/权限与原CI清单一致，未启动App、未Developer ID签名/公证。CI仍有未使用AppIntents与上游Actions运行时提示，不称所有工具输出无warning。
- 收尾文档同步当前通过状态，修正README/test旧版本失败文案、本机默认测试触发及按名称选模拟器的旧示例；所有本机iOS示例要求FAC4325D前缀的既有完整UDID。本文记录的是实现SHA证据，最终文档提交也按自身SHA/run/attempt重新下载复核，不复用此artifact；完成交付后停止本轮有限迭代。

### v0.93 / 纸本界面与高效写作（云端通过，视觉问题在v0.94收尾）

日期：2026-10-23。

- 原生界面重构覆盖资料库引导/新建与日期页码行、标题优先纸面、统一24pt正文边距、手机写作菜单、编号阅读小节、顶对齐统计与无嵌套大数字、纸本空态和轻渐变；沿用暖白/墨绿及深色/高对比语义颜色。
- 行只保存可见标量投影并显式Equatable，避免输入时对不变行的无关渲染；比较不含body/sections/updatedAt。缓存派生、Store、JSON、IME/UTF16/焦点和Markdown语义不改。最近编辑时间仅展开详情时格式化；“仅在本机”不冒充已落盘。
- 新增7项确定性测试，预期257项；保留原身份/选区/焦点回归及全部250项，界面矩阵11扩16。没有实测帧率/分配/真实Mac输入的虚假声明。
- 关键文件：Theme、List/Row、Editor/ChromeLayout、BodyTextView创建布局、Preview展示、Statistics/EmptyState、DateFormatters、相关测试、workflow与版本化prompt；README/test/flow/flowchart同步。
- 本机仅轻量检查，新SHA的完整构建、XCTest、16图和Mac包需自己的云端artifact，未预填通过。正式签名、公证、App Store工具链资格、真实Mac/IME/VoiceOver及性能仍须专项验收。
- 实际轻量检查退出0：应用/测试Swift parse、project plist、8/8纯Python fixture、workflow YAML与11个run块bash语法/2个Python heredoc及Python源码AST、全部asset JSON、257个XCTest声明和16图矩阵一致性、git diff --check。未本机build/XCTest/simctl/App。
- 实现cc46e099671b9b1735a1f421b1de4ae017e5b38b已推origin/main；run39885633937/attempt1六阶段success，257/257 XCTest、16图、四份xcresult与6项JUnit实际核对。artifact `mdjournal-ci-v0.93-main-cc46e09-run39885633937-attempt1`（ID12472911749，9190055bytes，SHA256 3623b5a6c0a1f1a1ec92f4641b017496ad4b0a4956348409c8e633035ac50712）。2026-10-24当前线程重新gh登录下载至`/private/tmp/mdjournal-c-review-39885633937/`，629个未加密文件、CRC、fresh extract与gh下载逐文件SHA256、manifest/log/四份xcresult/16图均已核对；Mac另作只读解压、双架构/Catalyst平台/图标/build200.1/ad-hoc签名/全文件和权限复核通过，不启动App、不标独立C。逐图发现大字号新建文字截断、深色按钮前景对比和统计文字宽度问题，转v0.94定点收尾，不冒充公开发布完成。

### v0.92 / 恢复可追溯云端基线（云端通过）

日期：2026-10-23。

- 已同步最新main（起点e445568），工作区干净；重新核对实际成功/失败云端日志并使用现有GitHub授权登录，不新建子智能体。
- 最后通过39806459795实际为macos-15-arm64/Xcode16.4/iOS18.5；失败39827664416为Intel/Xcode26.2冷启动迁移超时。恢复已通过工具链，固定runtime，编译前启动选定已有设备，不再盲目加时或选择最新系统。
- 新纯JSON设备选择器不调用simctl，8项fixture锁定runtime、Booted复用、稳定顺序与明确失败。workflow保留全部250项预期XCTest、11图、双平台Debug和universal Mac Release包门槛，记录环境和选定设备。
- 关键文件：`.github/workflows/ci-results.yml`、`script/ci_simulator.py`、`script/tests/test_ci_simulator.py`、版本化prompt及README/test/flow/flowchart。
- 本机仅轻量检查；完整构建/测试/图片/Mac包待新SHA自己的artifact，不预填通过。下一轮UI重构只有验收通过后开始。旧失败历史保留；正式签名、公证、真实Mac输入与性能仍不在本轮通过声明内。
- 实际轻量检查全部退出0：`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s script/tests -v`（8/8）、Ruby YAML解析、11个workflow run块`bash -n`与2个Python heredoc/全部Python源码`ast.parse`、应用与测试Swift `swiftc -parse -parse-as-library`、project `plutil -lint`、`git diff --check`。未本机build/XCTest/simctl/App。
- 提交4bb89aed1e57937b16c81f4d7bee78fb7062b6d9已推到同一origin/main；原URL内嵌旧凭证失败后，以现有gh授权和同仓库HTTPS显式推送，未更改全局凭证或远端目标。run39883823991/attempt1六阶段success，250/250测试、11图、四份xcresult；artifact `mdjournal-ci-v0.92-main-4bb89ae-run39883823991-attempt1`（ID12471084848，5522446bytes，SHA256 4812e8d87098a7c7f1c3dbef13a35da8882be50d03bcbb994a53c518baf27e42）。当前线程下载到`/private/tmp/mdjournal-c-review-39883823991/`并核对600个未加密文件、CRC、fresh extract与gh下载逐文件SHA256、JUnit/manifest/log、11图逐张和Mac包；Mac另以只读解压/签名/双架构/权限脚本复判通过，不启动App、不标独立C。8分20秒完成，解除上一轮同因启动阻塞，允许进入v0.93。

### v0.91 / 高效写作与 Mac 验收包（构建完成，测试阻塞）

日期：2026-10-23。

- 按用户最新要求全程改为当前线程串行，不继续调用子智能体。为减少约十分钟/轮的 runner 排队，将原性能与 Mac 包两个候选目标合并，分别设置验收门槛。
- JournalStore 在加载/创建/更新/删除处维护按ID的非持久化 BodyPresentation；正文相等复用，变更只派生该篇。缓存只含词数、可见性和每项至多160 Character加省略号的摘要/小节预览，不持有全文excerpt、section markdown、原文副本或AST。
- ContentView、列表、编辑器、统计sheet/独立窗口显式消费同一投影；概览/统计仍O(n)聚合元数据，搜索仍匹配正文，不宣称整体O(1)或实测帧率。旧纯API作为结果对照保留。
- 补5项投影Unicode/截断、真实Store构建次数/失效/创建删除/持久化、日历/时区聚合等价测试；245项基线全部保留，预期250项，实际数以新CI为准。辅助字号分类菜单改为垂直信息层级，避免“全部日记”碎行。
- 原生CoreGraphics源码生成iOS/Mac图标；云端新增Release universal构建、ad-hoc无私钥签名与ZIP，验证实际Mach-O架构、Info/图标/优化参数、权限、签名及独立解压逐文件一致性。build number按run number/attempt追溯；未公证、未Developer ID签名，不公开发布。
- 关键文件：BodyPresentation/JournalStore、概览/统计和生产视图接线、相关测试、AppIcon/生成源码、package_macos.sh/verify_macos_package.py、工程及workflow；同步README/test/flow/flowchart。
- 本机仅资源创作、Swift parse、plist/JSON/YAML/脚本语法和diff检查；完整构建、XCTest及包验证交云端。新SHA/run/artifact不预填通过；真实Mac启动、IME、VoiceOver、帧率和正式签名仍未验收。
- 实际轻量检查退出0：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse -parse-as-library`（全部应用Swift）、同环境测试Swift parse、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、workflow Ruby YAML解析、11个run块`bash -n`、3个Python heredoc与包装脚本`ast.parse`、全部asset JSON/PNG尺寸/不透明检查，以及`git diff --check`。图标生成脚本已实际运行并目视检查；未本机build/XCTest/App/模拟器。


- 首轮 v0.91 `c5ff108` / run `39816940970` attempt 1为FAIL：应用两个Debug与universal Release均编译成功，250项执行中2项新增持久化断言误将ISO-8601秒精度解码与内存亚秒Date直接比较；测试会话收尾又遭720秒进程上限，结果元数据不全。Mac包装检查因Xcode默认不输出SWIFT_OPTIMIZATION_LEVEL字段报KeyError。当前线程已下载失败包，实际ZIP的arm64+x86_64、Catalyst平台6、AppIcon.icns、macOS13.0、193.1版本和ad-hoc签名均有读包证据，但不能将失败run放行。
- 追加修复保留250项与11图：持久化断言改核对生产ISO-8601编码后的真实JSON字节；Release显式传入-O并关闭coverage。根据GitHub官方runner-images清单切macos-15-intel及已安装Xcode26.2（避免arm64容量提示与默认16.4漂移），全部构建/模拟器工具统一经xcrun选择；build-for-testing单独有界600秒，再启动设备120秒和test-without-building720秒，避免编译挤占测试与结果包收尾预算。新提交仍需自己的完整云端结果。


- 第二轮修复 `541db73` / run `39823883450` attempt 1为FAIL：iOS/Catalyst与build-for-testing成功，测试未启动，iOS26.2冷启动停在LaunchServices数据迁移并超120秒；Release因-enableCodeCoverage仅支持testing被拒绝。与上一轮的Date断言/缺优化字段不是同因。追加移除Release测试专用flag、改用coverage构建设置，优先复用已Booted的云端iPhone，迁移上限依据日志改240秒，保留720秒执行限时和250用例/11图。若再次同因失败停止重试，不无限循环。


- 最终云端构建源为 `9af6efa0e39cf4b579f8caa1421028d5f782103d`，run `39827664416` attempt `1`，artifact `mdjournal-ci-v0.91-main-9af6efa-run39827664416-attempt1`（ID12448566315，1718287 bytes，SHA-256 b1c7b6e2b06ee2640b67fda2ab2bb03994d69630227c9ff0325f1ffd3d62f9c7）。static/iOS Debug/Catalyst Debug及universal Release实际构建成功；完整CI仍FAIL：冷启动从迁移推进至Waiting on System App后超过240秒，最新250项未执行，11图未导出。与前轮同类启动阻塞连续复现，遵AGENTS停止重跑；不宣布发布级或目标完成。
- Release校验另发现Intel端otool默认仅输出宿主架构，已改`otool -arch all`，避免误将真实universal二进制判为单平台。当前线程使用修复后的脚本只读检查该云端ZIP：x86_64+arm64、两个Catalyst platform6、macOS13.0、1.0/build195.1、图标、ad-hoc签名、独立解压后的全部内容/符号链接/权限一致，结果通过。此报告明确`verificationOrigin=local-read-only-review`，不能冒充CI成功，也不写回原始artifact。
- 内部包已放 `/Users/a114514/Desktop/MDJournal-v0.91-Mac-9af6efa.zip`（1593680 bytes，SHA-256 6119a30a7ea583492bba8eaab52f2fce10db247bec21250bba66fc089895f66f），同目录verification.json明示CI failure、未执行最新测试、未启动App、未公证。下载与本地核对缓存 `/private/tmp/mdjournal-review-39827664416/`；外层33个文件的未加密/CRC/逐文件SHA-256与GitHub digest一致。
- 本轮无本机build/XCTest/模拟器/App运行；只读产物核对使用lipo、otool、codesign verify、ditto及Python。独立Agent C只核过旧起点与失败包，最终工作按用户要求串行完成，不标独立C PASS。修复后的校验脚本和收尾文档未另起CI，原因是连续同因云端启动阻塞停止条件；应用/测试/工程/workflow相对9af6efa不再修改。

### v0.90 / 资料库时间轴与写作画布（云端通过）

日期：2026-10-22。

- 资料库由简短集合摘要与分类菜单开始，以真实 List Section 按当前可见日记的年月分组；纯 `JournalEntryTimelineSnapshot` 只读日期，保持输入/组内顺序与 flatten ID，不重新排序或扫描正文。跨年、时区月界和 Locale 独立处理。
- 记录行改为日期/心情、两行标题与摘要、分类/词数，移除重复小节清单与层层边框；选中保留底色、短强调线、勾选与 selected trait。搜索、分类计数、tag/context/swipe、删除确认、selection repair 与导航边界继续使用原入口。
- 宽屏在 canvas 中展示带外围留白与细线的纸面，单栏仍限正文 760pt；双栏资格仍按原始 detail >=1120pt 且非 Accessibility，净纸面扣 Divider 后等分。窄屏/低高度/辅助字号取消外围占用；头部实测内容高度并按38%预算封顶，收起时可见分类/心情。
- 单条命令带容纳模式、三个常用格式与完整菜单，紧凑时只保留模式/菜单；双栏不再叠加 pane header 和独立工具栏。正文及标题固定结构，WorkspaceState、bridge、IME、选区、Store、JSON、parser 与预览 cache 未改。
- 新增九项分组与行日期语义测试、画布容量测试、生产 UITextView 跨单/双栏身份/UTF-16 选区/焦点回归；保留原标题高度切换测试。固定八篇 fixture 生成11张真实生产视图附件，包含完整主界面、跨年滚动、浅深色、低高度和辅助字号。runner 导出普通 PNG、原生 manifest 与索引，验证名称/尺寸，独立 export outcome 纳入失败条件及五项 JUnit。
- 关键文件：TimelineSnapshot、EntryList/Row、EntryEditor/ChromeLayout、MarkdownToolbar、Theme、DateFormatters、相关测试、工程 Sources、CI 和 v0.90 prompt；README、test、flow、flowchart 同步当前事实及多 Agent 授权。
- 本机执行 diff、应用/测试 Swift parse、project plist、workflow YAML/内嵌脚本语法检查；不进行本机构建或运行。提交 SHA、push 和本轮 run/artifact 在实际交付及 C 验收后记录，不预填通过。
- 遗留：真实 Mac 窗口、IME、VoiceOver、鼠标/触控板、性能和签名发布尚未验收；v0.91 缓存与 v0.92 Release 包只是候选后续目标，本轮不提前实现。
- 首轮实现 SHA `ac317d1cc69fa0ad5c541537a492a312eec259f6` 已push，run `39801156079` attempt `1`、artifact `mdjournal-ci-v0.90-main-ac317d1-run39801156079-attempt1` 已由 C 下载并判 FAIL：static/iOS/Catalyst成功，XCTest 打印 `TEST SUCCEEDED` 后在720秒进程上限触发 SIGALRM、退出142，结果包缺Info.plist/元数据，图片导出失败。没有可核对的逐用例结果，不宣称245项通过。后续最小修复仅将云端选定UDID启动等待限制为120秒并串行完整测试，保留720秒、身份回归及11图要求，等待新SHA自己的结果包。

- 2026-10-23 当前线程串行核对修复提交 `7283b1e4116bd6c776019aa4ff772c97856567b0`，run `39806459795` attempt `1`，artifact `mdjournal-ci-v0.90-main-7283b1e-run39806459795-attempt1`（ID `12439121176`，8335208 bytes，SHA-256 `ff47f396f082f697a5b17018bf8424b64a3674359682037e7eb9afc7bec9048e`）：五阶段success、JUnit 5/0/0/0、245/245 passed；三份xcresult完整，两个build的error/warning/analyzer均0，11图逐张复核。串行用例实际约14秒（render约7.3秒），Test operation约94.8秒；启动/编译等待不算输入性能。缓存 `/private/tmp/mdjournal-c-review-39806459795/`。独立Agent C曾核对起点与失败包，最终新包由当前线程接手，未冒充C通过。

### v0.89 / Mac 桌面窗口与工具栏（云端基线通过）

日期：2026-10-13（接续 2026-09-26 未提交工作）。

- Mac Catalyst 主窗口通过 frame 提供 1360×860pt 内容建议尺寸（不强制窗口尺寸或覆盖系统恢复，不提升部署版本），保留 1120×720pt 最小尺寸。
- Mac 工具栏显示当前筛选结果数量，并提供对应可访问性文案。
- 云端图像复核发现低高度正文空间不足与辅助字号工具栏过密：新增紧凑标题、单行模式/工具菜单和状态栏收起；字体配置显式跟随 SwiftUI Dynamic Type，保持正文 bridge 同步与 JSON 不变。新增 2 项测试，预期 234 项。
- 新增窗口默认尺寸纯值契约，更新 README、测试规范、流程图/流程说明与版本化 prompt。
- 首轮 commit defacdf7b739a690b348417c297c021340d16489 / run 38343197500 attempt 1：iOS、静态检查和 233 项测试通过，Catalyst 因 SceneBuilder availability 分支不支持而失败。artifact `mdjournal-ci-v0.89-main-defacdf-run38343197500-attempt1` 已下载，549 ZIP entries、digest/CRC/逐文件哈希通过。修复改用根视图 ideal frame，不升系统版本；失败不作为通过依据。
- 本机预期只做 Swift parse 与 diff 检查，完整 iOS/Catalyst build、XCTest 和 artifact 核对交 GitHub Actions；真实 Mac 窗口、VoiceOver、输入设备与性能仍待人工验收。
- 2026-10-22 独立 Agent C 补核对最终起点 SHA `c354f9c05924c2778e1023254740b9709a9ae012`、run `38344640193`、attempt `1`，artifact `mdjournal-ci-v0.89-main-c354f9c-run38344640193-attempt1`：四阶段 success、234 项 XCTest，六张附件及完整性 PASS。该结果不作为 v0.90 新 SHA 的证据。

## v0.88 / 写作工作台与统一界面（云端基线通过，视觉问题由 v0.89 修复）

日期：2026-09-26。

- 2026-10-13 当前线程下载核对 commit `4f6cda3c84ddd3ddd4a7b1d997fd488f3fd7a708`，run `36234465443` attempt `1`，artifact `mdjournal-ci-v0.88-main-4f6cda3-run36234465443-attempt1`（ID 10903617702，1690920 bytes，SHA-256 fec08f8a651ab9222313b26f57fe109c535fb94a12782fb8a26e25da74f7d8a9）。四阶段 success、JUnit 4/0/0/0、xcresult 231/231 passed；545 ZIP entries 未加密，CRC、digest 和逐文件哈希通过。缓存 `/private/tmp/mdjournal-c-review-36234465443/`。已用 xcresulttool 导出六张附件；低高度和辅助字号视觉问题不因测试通过而放行。无独立 Agent C。
- 统一暖白纸面、墨绿强调、浅深色及高对比颜色资源；列表概览、分类入口与行信息重排，选中同时具有勾选与边框。
- 编辑器以标题和正文为中心，元数据/小节目录按需展开；头部独立滚动且最多占实际可用高度 38%，专注写作收起详情，单栏正文上限 760pt。原 WorkspaceState、UITextView bridge、选区、IME、保存与 Markdown 语义保留。
- 预览改为连续阅读纸面；统计总览完整宽度、分区自适应网格、Accessibility 单列；工具栏与空态同步重整。
- 关键文件：JournalTheme/Assets、EntryListView、EntryRowView、EntryEditorView/ChromeLayout、MarkdownPreviewView、MarkdownToolbar、StatisticsDashboardView/DashboardLayout、EmptyStateView、JournalInterfaceTests、Xcode project 和 CI VERSION。
- 新增 4 项 XCTest（其中 1 项产出六张云端界面渲染附件），保留 227 项起点。预期 231 项，以最新 CI 实际结果为准。
- 本机 app/test Swift parse、project plist 和 diff 检查退出 0；commit 前还核对 YAML/JSON。未运行本机 build/XCTest/模拟器/App/性能脚本，重验证交云端。界面渲染附件不等价于 Mac 实际窗口、VoiceOver/IME 或性能实测。
- 起点核对：763abe32eca3bafd52adaa34b33fe0b2d61a961a，run 34175692697 attempt 1，artifact mdjournal-ci-v0.87-main-763abe3-run34175692697-attempt1，ID 10037310563，496131 bytes；四阶段 success、JUnit 4/0/0/0、227 passed；525 ZIP entries 无加密，CRC、文件清单及逐文件 SHA-256 一致，digest d588643f5c39b52e31ba413a59a51cb7caa304680a1fe0a89d17619dfb8b8889。下载路径 /private/tmp/mdjournal-c-review-34175692697/。
- 本轮用户明确禁用子智能体：方案、实现、结果包核对串行完成；不宣称独立 Agent C 验收。未预填本轮 SHA/run/artifact。通过后推进 v0.89 派生计算与视觉复核。

### v0.87 / 写作布局与预览缓存（实现待云端验证）

日期：2026-09-08

核心变更：

- 编辑器保留 `820pt` 头部档位；实际 detail `>=1120pt` 且非 Accessibility 才允许双栏，扣除 Divider 后近似等分，窗口/sidebar 尺寸不变。
- `EntryEditorWorkspaceState` 统一生产布局、Picker、菜单/工具栏命令和标题；跨阈值按焦点与预览可见性归一 mode，保留专注写作的隐藏偏好及 UTF-16 选区。可见正文保持固定结构位置，专注宽度只改 frame，不建隐藏编辑器，不改 bridge。
- 预览接受有效请求后解析一次并构建按原文去重的 inline cache，单一 render snapshot 原子发布 document/cache；body 与 lazy 子闭包只读匹配快照。plain 不调用 renderer，失败缓存原文，新文档整体替换缓存，隐藏/重新激活仍沿既有 latest-wins 生命周期。
- 新增 9 项布局/状态与 6 项缓存测试；保留既有 212 项，预期共 227 项，执行数及结果待云端确认。CI 仅改 `VERSION: v0.87`，四阶段及 artifact 契约原样保留。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`、`MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`、`MDJournalTests/MarkdownPreviewTests.swift`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`update_log.md`
- `.github/workflows/ci-results.yml`、Agent A 的 `md/prompt/v0（Mac体验）/v0.87（写作布局与预览缓存）.md`

验证与交付状态：

- Agent B 在 main 以单次 `http.curloptResolve=github.com:443:20.27.177.113` 参数 fetch/pull，起点为上述 v0.86 最终 SHA；未修改 Git、DNS 或认证配置。
- `git diff --check`、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`、`xcrun swiftc -parse MDJournalTests/MarkdownSnippetTests.swift MDJournalTests/MarkdownPreviewTests.swift`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、workflow Ruby YAML 解析均退出 0。Ruby 输出既有 PATH 中 `/opt/homebrew/bin` 可写权限警告，不影响 YAML 解析，未改环境。
- 布局独立 reviewer 与主控缓存 diff 审查未发现阻断；Swift parse 不进行类型检查，不能替代云端构建和 XCTest。
- 本条为提交前实现记录；集成 SHA、push、新 run/attempt/artifact 由交付回报及 Agent C 后续记录，不预填未来证据。Agent C 尚未下载或核对本轮结果包，当前不标记通过。

遗留事项：

- 遵人工限制未运行本机 build、XCTest、xcodebuild、simctl、App、UI 自动化或性能脚本；真实 UITextView 身份/first responder、IME、低高度/Dynamic Type 排版、VoiceOver、帧率及内存分配仍未验收。缓存构建保留 MainActor CPU 与当前文档内存成本，计数测试不代表性能测量。
- Store、JSON、parser、bridge、window/sidebar、deployment target 和版本化 prompt 均无本代理修改。

### v0.86 / Markdown 正文 bridge 同步快速路径（历史实现验证记录）

日期：2026-08-24

核心变更：

- `MarkdownBodyTextView.Coordinator` 仅在正文实际发布时建立绑定正文与 UTF-16 选区的一次性 token；选区变化不建立正文 token，正文不同即使 `NSRange` 相同仍走外部同步，marked text 继续延迟覆盖。
- `MarkdownTextInputConfigurationTests` 相对 v0.85 新增 7 项同步状态纯值与 Coordinator 接线测试；不改变 Store、JSON、Markdown continuation/indentation、preview 或 UI 布局。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownTextInputConfigurationTests.swift`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`update_log.md`

验证与交付状态：

- 实现验证 HEAD `8f2b3b8c2bfe3ca1168c2c728e0868e7ba9fd745` 对应 `MD Journal CI Results` run `32650916069`、attempt `1`，artifact `mdjournal-ci-v0.86-main-8f2b3b8-run32650916069-attempt1`，ID `9496324008`，size `466015` bytes，digest `sha256:b4f645513aa682a6ba5ac6b80f87e9c9c1f88619aa0ac2fa6740439049302c41`，下载目录 `/private/tmp/mdjournal-c-review-32650916069/`。
- Agent C 已核对 manifest 和结果：static checks、generic iOS build、Mac Catalyst build、XCTest 四阶段均为 `success`；JUnit 为 `4 tests / 0 failures / 0 errors / 0 skipped`，XCTest 为 `212/212 passed`，7 项新增测试均实际执行并通过；495/495 ZIP entries 全部未加密，CRC、fresh extract、文件清单和逐文件 SHA-256 均通过，xcresult 非空且 `Info.plist` lint OK。
- 上述 artifact 是实现验证 HEAD/docs-close source baseline；本轮 docs-only 提交只同步已核对事实，不复用该 artifact 作为新 HEAD 证据。提交后 Agent C 必须针对新的 `origin/main` HEAD 独立下载和核对结果包，本文不预填未来 run、attempt 或 artifact。

遗留事项：

- 本轮未运行本机 build、XCTest、`xcodebuild`、Simulator、Mac Catalyst App、UI 自动化、截图或 Instruments；真实 Mac Catalyst 输入延迟、IME、VoiceOver、帧率和内存分配仍需人工或专门工具验收。

## 关键决策

- 使用 SwiftUI 原生实现，不默认引入第三方框架。
- 使用 `NavigationSplitView` 作为主导航结构。
- `JournalStore` 作为唯一日记集合修改和保存入口。
- Markdown 预览采用轻量自研解析器，不承诺完整 CommonMark 支持。
- 日记正文推荐使用 `###` 三级标题组织小节，并以此驱动预览分组和统计。
- iPhone 支持竖屏、横屏左、横屏右；编辑器双栏资格为实际 detail `>=1120pt` 且非 Accessibility，`820pt` 保留为头部档位与统计宽屏边界。
- Mac 版本当前采用 Mac Catalyst 路径，不新增独立 native macOS target。
- 后续迭代采用“人工 -> Agent A -> Agent B main 直推 -> GitHub Actions 结果包 -> Agent C 下载复判 -> 人工复核”的文档化流程。
- 未来可使用 `agentx`、`x:` 或 `X:` 召唤 Agent X 主控循环；Agent X 只调度 A/B/C 多轮迭代，不替代 Agent A 提示词、Agent B 实现 push 或 Agent C artifact 验收。
- `main` 是默认唯一上传、提交、推送和云端验证分支；本阶段不使用候选分支或 PR 流程。
- Agent C 不通过时退回 Agent B 在 `main` 上追加修复 commit，不默认回滚；最终通过必须核对最新 `origin/main` 对应的未加密 CI 结果包。

## 历史记录

### v0.85 / 列表卡片 Accessibility Dynamic Type 布局（实现与 docs-close 均通过）

日期：2026-08-23

核心变更：

- 新增 `EntryRowLayoutContract`，普通 `.large` / `.xxxLarge` 保留 metadata/footer 横排、标题和小节标题单行及水平小节条。
- `.accessibility1` 至 `.accessibility5` 将 metadata/footer 垂直堆叠、标题取消单行限制，小节改为有限宽度垂直栈并允许标题至少两行；保留空状态、前三个小节和 `+N` 顺序，避免水平 `ScrollView` 无限提议使换行失效。
- 新增 `JournalEntryListSnapshotTests.testEntryRowLayoutContractSeparatesRegularAndAccessibilityLayouts`；只修改 EntryRow、相关纯契约测试、文档、v0.85 prompt 和 CI 版本元数据，不改变 Store、JSON、列表 snapshot、正文 metrics、Markdown、focus、window 或 Xcode target。

关键文件：

- `MDJournal/Views/EntryRowView.swift`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`update_log.md`
- `md/prompt/v0（界面优化）/v0.85（列表卡片辅助字号布局）.md`

验证与交付状态：

- Agent B 实现阶段仅执行 `git diff --check`、`git diff --cached --check`、应用/测试 Swift parse、workflow YAML 解析和版本/边界搜索；未运行本机 build、XCTest、`xcodebuild`、Simulator/CoreSimulator、Mac Catalyst App、UI 自动化、截图或 Instruments。
- 实现修复 HEAD 为 `dead07c3b2551b91a3ac335672b1315ca590997f`，branch 为 `main`。阶段一对应 `MD Journal CI Results` run `32645093679`、attempt `1`，artifact `mdjournal-ci-v0.85-main-dead07c-run32645093679-attempt1`，artifact ID `9494746382`，size `456026` bytes，digest `sha256:4e6cf7475691fb0590a545ebc176cd8af8f6da4b3cb259c2eaf287a1f74d2c2c`，下载目录 `/private/tmp/mdjournal-c-review-32645093679/`。
- 阶段一 static checks、generic iOS build、Mac Catalyst build 和 XCTest 四阶段均为 `success`；JUnit 为 `tests=4 / failures=0 / errors=0 / skipped=0`，XCTest 为 `205/205 passed`，新增布局测试实际执行并通过。Artifact 共 481 项，全部未加密，CRC、fresh extract 和逐文件 SHA-256 均通过。
- 早期实现 HEAD `e9674cd5c1fd4f82bd7fc93f488315f1bdbc5d01` 的 run `32644620613`、attempt `1` 明确失败，唯一原因是 `JournalEntryListSnapshotTests.swift` 缺少 `import SwiftUI`，导致 `DynamicTypeSize` 无法解析；该失败结果不计为 v0.85 通过。修复只增加测试文件的 `import SwiftUI`，未修改生产布局实现。
- 本轮 docs-close 只更新 README、测试规范、核心流程、流程图和本更新日志；最终 docs-close HEAD 为 `ae8e85073a13b7a50be003d7dc54d3a52173faf1`，对应 run `32646077288`、attempt `1`、artifact `mdjournal-ci-v0.85-main-ae8e850-run32646077288-attempt1`（ID `9494991741`、size `457085` bytes、digest `sha256:3aede2a533be7d38db1ff6ba4f97693a2c51671ad26f4899cf5b77019b2803ce`）；Agent C 已下载并核对，四阶段均为 `success`，XCTest `205/205 passed`，481/481 ZIP entries 未加密且 CRC、fresh extract、逐文件 SHA-256 通过。阶段一 artifact 不能替代 docs-close artifact。

遗留事项：

- 纯契约、Swift parse 和云端 build/XCTest 不证明真实列表卡片 frame、行高、Dynamic Type 像素排版、VoiceOver、Mac Catalyst 鼠标/触控板或中文输入交互，仍需人工验收。

### v0.84 / 摘要共享正文扫描（实现与最终 docs-close 已完成）

日期：2026-08-23

核心变更：

- `JournalEntryBodySummary` 通过带 excerpt 的 `JournalBodyDerivation` 单次 Character/Index 扫描，同时派生 `JournalEntryBodyMetrics` 和完整正文摘要；不再先构造 `JournalEntryBodyMetrics(body:)`，再独立扫描完整正文 `MarkdownSummaryText.plainText`。
- 新增 `MarkdownSummaryAccumulator` 作为文件内共享实现：完整正文路径保持 literal LF、轻量 Markdown marker、空行合并、Unicode/组合字符和 emoji 的既有摘要口径；`JournalSection.excerpt` 继续独立使用 `removesListMarkers: true` 的路径。
- `JournalEntryTests` 新增纯值 characterization，覆盖空白、Markdown marker、列表/引用/任务、`###`/空标题/EOF、LF/CRLF/Foundation newline、Unicode/emoji/组合字符、fenced code、长正文，并逐项核对 summary metrics 与独立 metrics、section excerpt 一致。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.84（摘要共享正文扫描）.md`

验证与交付状态：

- Agent B 已按本轮限制执行同步、源码/测试/文档边界检查和允许的轻量检查；未运行本机 build、XCTest、`xcodebuild`、Simulator/CoreSimulator、Mac Catalyst App、UI 自动化、截图、Instruments 或性能脚本。
- 实现 HEAD `38885bb078f945ebeac65a5d9c17902ec088c678` 已 push 到 `origin/main`；对应 run `32641923529`、attempt `1` 的 artifact `mdjournal-ci-v0.84-main-38885bb-run32641923529-attempt1`（ID `9493893598`、size `454188` bytes、digest `sha256:84c00a40530ccaecbe0131a62ff1623ff1ce7a91e9fb77089ed2d664a134a132`）已由 Agent C 从 `/private/tmp/mdjournal-c-review-32641923529/` 下载并 PASS。Manifest、四阶段 outcome、JUnit `4/0/0/0`、两份 build summary、测试 summary `204 passed / 0 failed / 0 skipped`、新增 characterization、479 项未加密 ZIP、CRC、fresh extract、下载清单和逐文件 SHA-256 均核对通过。
- 最终 docs HEAD `8d12e641b0c188bbd839ae7902b06979897fa311` 对应 run `32642592068`、attempt `1` 的 artifact `mdjournal-ci-v0.84-main-8d12e64-run32642592068-attempt1`（ID `9494058101`、size `453752` bytes、digest `sha256:c2bd17d5cbce074f24ff745020aeb59703ed5d64cf35e642d303a308dd3617c`）已由 Agent C 从 `/private/tmp/mdjournal-c-review-32642592068/` 下载并 PASS。Manifest/JUnit/log/三份 xcresult、`204 passed / 0 failed / 0 skipped`、479 项未加密 ZIP、CRC、fresh extract、下载目录清单和逐文件 SHA-256 均核对通过；最终 docs HEAD 的云端复核已完成。

遗留事项：

- 纯值 characterization、Swift parse 和云端 build 不证明真实 Mac Catalyst 长文输入的帧率、内存分配、IME、VoiceOver 或像素排版；这些仍需人工或专门工具验收。

### v0.83 / 编辑器 placeholder 复用 body metrics

日期：2026-08-23

核心变更：

- `JournalEntryBodyMetrics` 在既有 `JournalBodyDerivation.scan` 单次 Character/Index 循环中增加非持久化 `hasVisibleContent`，精确保持 `body.contains { !$0.isWhitespace }` 的 placeholder 语义。
- `EntryEditorView.body` 将同一次评估得到的 metrics 显式传入 compact/wide 编辑区域，placeholder 只消费 `hasVisibleContent`，移除独立正文全文扫描；词数、小节、摘要、Markdown、焦点、窗口、Store 和 JSON 行为不变。
- `JournalEntryTests` 新增纯值 characterization，覆盖空白、Unicode 空白、换行、标点、emoji、组合字符、Markdown marker、普通正文和长正文。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `.github/workflows/ci-results.yml`、`md/prompt/v0（性能优化）/v0.83（编辑器占位共享metrics）.md`

验证与交付状态：

- Agent B 仅执行本轮允许的 `git diff --check`、`git diff --cached --check`、必要的 `plutil -lint`、Swift parse、workflow YAML 解析和版本/符号搜索；实现 HEAD 为 `d923cd3720da5c8739bcf216a404379c752618b7`，已推送到 `origin/main`。
- 本轮不运行本机 build、XCTest、`xcodebuild`、Simulator/CoreSimulator、Mac Catalyst App、UI 自动化、截图、真实键盘/IME/VoiceOver、Instruments 或性能脚本。
- 实现 HEAD 第一阶段云端验收：`MD Journal CI Results` run `32638983543`、attempt `1`、branch `main` 成功；artifact `mdjournal-ci-v0.83-main-d923cd3-run32638983543-attempt1`，ID `9493173578`，size `453266` bytes，GitHub/local SHA-256 均为 `sha256:abfca59c408c01d0e9fbf59fb64f62d6c84d3dbff86b048254a82d4f94812fd5`，下载目录为 `/private/tmp/mdjournal-c-review-32638983543/`。
- 第一阶段 manifest 的 `version`、完整 `commitSha`、`branch`、`runId`、`runAttempt`、workflow、scheme、destination、结果路径和四阶段 outcome 完全匹配；static checks、generic iOS build、Mac Catalyst build、XCTest 均为 `success`。JUnit 为 `tests=4 / failures=0 / errors=0 / skipped=0`；`xctest.log` 和测试 xcresult 均为 `203 passed / 0 failed / 0 skipped`，`JournalEntryTests.testBodyMetricsReportsVisibleContentUsingCharacterWhitespaceSemantics` 实际执行并通过；两份 build 日志分别包含 `BUILD SUCCEEDED`，测试日志包含 `TEST SUCCEEDED`，三份 xcresult 的 `Info.plist` 均通过 `plutil -lint`，generic iOS/Mac Catalyst xcresult build summary 均为 `succeeded`。
- 第一阶段 artifact 共 477 项，全部未加密；`unzip -tq` CRC 通过，fresh extract 为 477 个文件，下载目录清单与 fresh extract 一致，477 项逐文件 SHA-256 无差异。docs-only 收敛提交及其最终 HEAD 云端 artifact 尚待第二阶段独立复核，不能复用本阶段 artifact。

遗留事项：

- `hasVisibleContent` 与旧 Character 空白闭包的纯值等价性已由新增测试和云端 XCTest 核对；真实 Mac Catalyst 长文输入分配、帧率、IME、VoiceOver 和 placeholder 像素排版仍需人工/专门工具验收。云端日志还记录了 AppIntents metadata warning 和一次 Simulator app launch warning，但不影响 `TEST SUCCEEDED`。

### v0.82 / ContentView 列表快照复用

日期：2026-08-23

核心变更：

- `ContentView.body` 通过局部 `JournalEntryListSnapshot` 让 `EntryListView`、`selectedEntryBinding(using:)` 和 `journalEntryNavigationActions(using:)` 在同一次评估中共享 `filteredEntries`，消除原先列表、detail guard 与两个导航方向的重复列表遍历。
- 创建、删除和 selection repair 事件继续通过 `makeListSnapshot()` 按需取得最新状态；Binding getter/setter 不捕获过期快照，不改变 Store、JSON、搜索、分类计数、selection、导航、Markdown、焦点或窗口语义。
- `JournalEntryNavigationTests` 新增搜索与分类组合的纯 characterization，锁定同一可见顺序下的 selection 保留/失效修复以及较新/较早目标，隐藏日记不进入导航。

关键文件：

- `MDJournal/ContentView.swift`
- `MDJournalTests/JournalEntryNavigationTests.swift`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `.github/workflows/ci-results.yml`、`md/prompt/v0（性能优化）/v0.82（ContentView列表快照复用）.md`

验证与交付状态：

- Agent B 已执行并通过 `git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、应用与测试 Swift `-parse`、workflow YAML 解析和 `VERSION: v0.82`/快照初始化次数检查；禁止本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本、UI 自动化、截图、Instruments 和性能脚本。
- 实现 HEAD `5f83de061ff4d573ff1b1bb9d3b6fcd8995be22a` 在 `main` 已推送；对应 `MD Journal CI Results` run `32636121799`、attempt `1` 成功。未加密 artifact ID `9492454468`，名称 `mdjournal-ci-v0.82-main-5f83de0-run32636121799-attempt1`，size `449249` bytes，GitHub digest 与本地 SHA-256 均为 `sha256:50375dd8a5a1463cfb3e0a2251b8382a6a6de7f94bf10ce7d2738c849d625bf3`。
- Agent C 已从 `/private/tmp/mdjournal-c-review-32636121799/` 下载并核对该最新 `origin/main` artifact：manifest 的 `version`、`branch`、完整 `commitSha`、`runId`、`runAttempt`、workflow、scheme、destination 和结果路径完全匹配；static checks、generic iOS build、Mac Catalyst build、XCTest 均为 `success`，JUnit 为 `tests=4 / failures=0 / errors=0 / skipped=0`。`xcodebuild.log`、`maccatalyst-build.log` 和 `xctest.log` 分别有 `BUILD SUCCEEDED`、`BUILD SUCCEEDED`、`TEST SUCCEEDED`；三份 xcresult 均存在且 `Info.plist` 可解析，测试 xcresult 为 `202 passed / 0 failed / 0 skipped`。
- `xctest.log` 中新增 `testFilteredSnapshotDrivesSelectionRepairAndNavigationFromOneVisibleOrder` 实际执行并通过，另有 filtered navigation characterization；XCTest 总数为 `202 passed / 0 failed / 0 skipped`。ZIP 共 475 项且全部未加密，`unzip -t` CRC、fresh extract 文件清单、下载目录与 fresh extract 文件清单及 475 项逐文件 SHA-256 均通过。
- 本轮完整 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本、UI 自动化、截图和 Instruments 均未在本机运行；docs-only 收敛提交会触发新的 run，不能复用上述实现 artifact 作为最终 docs HEAD 的云端证据。

遗留事项：

- 局部复用只覆盖单次 SwiftUI `body` 评估，不承诺跨评估缓存、固定帧率或真实长正文搜索延迟；真实 Mac Catalyst UI、VoiceOver、输入设备与 Instruments 分配仍需人工/专门性能验收。

### v0.81 / 预览焦点生命周期

日期：2026-08-23

核心变更：

- compact/窄屏进入预览时由 `EntryEditorFocusPolicy` 映射为 `resign`，现有 `⌘⌥P` 从预览返回编辑时映射为 `focus` 并复用 `focusBody()`，Picker 直接选回编辑映射为 `preserve`。
- `MarkdownBodyTextView` 继续只消费正文、选区和焦点 binding；异步 first responder 请求增加最新 binding 与请求代数门控，避免过期 become 请求越过预览清焦点状态，不改变 IME、marked text、选区、正文写回、Tab/回车和缩进语义。
- 宽屏 `isPreviewColumnVisible`、`focusWriting()`、菜单快捷键定义、`MarkdownPreviewUpdateModel`、Store、JSON、Markdown parser/preview、窗口/sidebar 和 deployment target 均未改变。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `.github/workflows/ci-results.yml`、`md/prompt/v0（Mac体验）/v0.81（预览焦点生命周期）.md`

验证与交付状态：

- 本轮本机仅执行 `git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、应用与相关测试 Swift `-parse`、workflow YAML 解析和版本/符号搜索；Ruby YAML 解析伴随既有 PATH warning，但输出 `yaml ok`。未运行本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本、UI 自动化、截图或 Instruments。
- 实现 HEAD `af6dfccddb266fa2966508b16fdd4df18eaadb9d` 对应 GitHub Actions run `32632436582`、attempt `1` 已由 Agent C PASS。未加密 artifact 为 `mdjournal-ci-v0.81-main-af6dfcc-run32632436582-attempt1`，ID `9491532543`，size `452553` bytes，digest `sha256:037099d690ea27cbccd19f21c8b38a7f97ff1601eae3534a5ef3c763fb5e78bd`。
- Agent C 核对 manifest 身份与 outcomes 均匹配；JUnit 为 `tests=4, failures=0, errors=0, skipped=0`，三份 xcresult 均存在且可读取，XCTest 为 `201 passed / 0 failed / 0 skipped`。ZIP 共 473 项且未加密，CRC、fresh extract 文件清单和逐文件 SHA-256 均通过；runner 的远端 Simulator `FBSOpenApplicationServiceErrorDomain` 启动 warning 不影响 `TEST SUCCEEDED`。

遗留事项：

- 纯 policy 测试和 bridge 静态检查不证明真实 Mac Catalyst first responder 时序、Picker 交互、键盘焦点环、VoiceOver、Dynamic Type、中文 IME marked text、输入设备交互或长文帧率；完整 iOS/Mac Catalyst build、XCTest 和结果包完整性以最新 v0.81 GitHub Actions artifact 为准。

### v0.80 / 列表概览双指标共享扫描

日期：2026-08-23

核心变更：

- 新增非持久化 `JournalEntryOverviewMetrics`，在模型层一次 Character/Unicode scalar 线性扫描中同时派生旧口径 `wordCount` 和 `hasLevelThreeSection`。
- `JournalListOverviewSnapshot` 每篇正文只消费一次 overview metrics，复用同一词数更新总计、本周词数和分类词数，并用同一小节存在性更新覆盖率；不构造完整 sections、markdown、excerpt 或 summary。
- 保留 `JournalEntryBodyMetrics.wordCount(in:)`、`JournalSection.containsLevelThreeSection(in:)` 和 `JournalSection.extract(from:)` 的签名与结果语义，覆盖 newline、ASCII marker、空标题、EOF、连续 marker、fenced code 和 Unicode 字符边界。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/JournalListOverviewSnapshot.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.80（列表概览双指标共享扫描）.md`

验证与交付状态：

- 本轮本机仅执行 `git diff --check`、`git diff --cached --check`、Swift parse、`plutil -lint`、workflow YAML 解析和版本/符号搜索；未运行本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本或 Instruments。
- 实现 commit `38c04d4f7d5ab6a19cd54e90b36cb8ef9102c80c` 已推送到 `origin/main`；对应 GitHub Actions `MD Journal CI Results` run `32630508182`、attempt `1` 成功。
- 对应未加密 artifact ID `9490952804`，名称 `mdjournal-ci-v0.80-main-38c04d4-run32630508182-attempt1`，size `443686` bytes，GitHub digest 与本地 SHA-256 均为 `sha256:7d7b2615a5c0b2f9fb7c9511d2dac6f93a1fad3d449e23f30e3950035f8fb626`。
- Agent C 已下载并核对 `/private/tmp/mdjournal-c-review-32630508182/`：manifest 的 version、branch、commitSha、runId、runAttempt、workflow 和结果路径完全匹配；static checks、generic iOS build、Mac Catalyst build、XCTest 均 success；JUnit 为 `4 tests / 0 failures / 0 errors / 0 skipped`，XCTest 为 `199 passed / 0 failed / 0 skipped`，新增 overview characterization 实际执行并通过。三份 xcresult 均存在且 Info.plist 可解析；ZIP 共 469 项、未加密，CRC、fresh extract 文件清单和 469 项逐文件 SHA-256 均 PASS。

遗留事项：

- 云端 build、XCTest 和结果包完整性已通过；真实长文分配、帧率、Mac UI、VoiceOver 和输入交互仍需人工验收。

### v0.79 / Mac Catalyst 窗口与侧栏尺寸

日期：2026-08-23

核心变更：

- `MacWindowLayoutContract` 集中定义 Catalyst 主窗口 `1120×720pt` 最小内容尺寸和 sidebar `260/300/360pt` 最小/理想/最大宽度。
- `MDJournalApp` 只在 `targetEnvironment(macCatalyst)` 路径给主 `ContentView` 附加最小窗口 frame；`ContentView` 只在 Catalyst sidebar 附加 `navigationSplitViewColumnWidth(min:ideal:max:)`，iOS/iPadOS 不增加这些约束。
- `MarkdownSnippetTests` 新增纯值尺寸契约，锁定常量、正有限值、sidebar 顺序和理想 `300pt + EntryEditorLayoutContract.wideLayoutMinimumWidth` 的宽屏关系；不冒充真实窗口拖拽、恢复尺寸或像素交互。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/ContentView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.79（Mac窗口与侧栏尺寸）.md`

验证与交付状态：

- Agent B 仅执行本轮允许的 `git diff --check`、`git diff --cached --check`、`plutil -lint`、应用与 `MarkdownSnippetTests` Swift parse、版本/符号搜索；本机未运行 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本、UI 自动化、截图或 Instruments。
- 实现 commit `0509ad4d24b775d930e566ec696b41bf2339f2bc` 已推送到 `origin/main`；对应 GitHub Actions `MD Journal CI Results` run `32628877854`、attempt `1` 成功。
- 对应未加密 artifact ID `9490536945`，名称 `mdjournal-ci-v0.79-main-0509ad4-run32628877854-attempt1`，size `442139` bytes，GitHub digest 与本地 SHA-256 均为 `sha256:0a2802216736540ea44e4e48f24993fb73a77190ba5686d8ecd00b04875beaf1`。Agent C 已下载并核对 `/private/tmp/mdjournal-c-review-32628877854/`：manifest/outcomes、JUnit、iOS/Mac Catalyst/XCTest 日志和三份 xcresult 均匹配并通过，XCTest 为 `198 passed / 0 failed / 0 skipped`，尺寸契约测试实际执行；ZIP 共 467 项、未加密，CRC、fresh extract 和 467 项逐文件 SHA-256 均 PASS。

遗留事项：

- 云端结果包需确认 Catalyst 13 API 编译、尺寸契约测试执行和 artifact 完整性；真实 Mac 主窗口最小尺寸、sidebar 拖拽、窗口恢复、焦点、Dynamic Type、VoiceOver 和长文帧率仍需人工验收。

### v0.78 / 正文 metrics 单次扫描

日期：2026-08-23

核心变更：

- `JournalEntryBodyMetrics` 通过模型层 `JournalBodyDerivation` 共享单调 Character/Index 扫描，在一次正文遍历中同时派生 `wordCount` 和 `sections`；编辑器头部、统计和其他 metrics 调用方不再先独立扫词数再完整扫描小节。
- `JournalSection.extract(from:)` 和 `JournalEntryBodyMetrics.wordCount(in:)` 继续保留兼容 API，并按需复用同一内部扫描器；保留 LF、CR、CRLF、VT、FF、NEL、LS、PS、ASCII 空格/tab marker、空标题、trim、EOF、section order/id/markdown/excerpt、fenced code ordinary marker 和旧词数口径。
- `JournalEntryTests` 新增 shared metrics characterization，精确断言 wordCount、section count、title、markdown、excerpt、order 和 id；不加入耗时或分配阈值。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.78（正文metrics单次扫描）.md`

验证与交付状态：

- 本机轻量检查已完成：`git diff --check`、应用和改动测试 Swift `-parse`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、workflow YAML 解析和 `VERSION: v0.78` 搜索均通过；Ruby YAML 解析伴随本机 PATH 权限 warning，不影响 `yaml ok`。未运行本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本或 Instruments。
- 实现 HEAD `987505cba6aa523e1b6321d29ac2f8c889a291bb` 已在 `main` 推送；对应 run `32626526380`、attempt `1` 成功。未加密 artifact ID `9489907904`，名称 `mdjournal-ci-v0.78-main-987505c-run32626526380-attempt1`，size `444220` bytes，GitHub/local SHA-256 均为 `sha256:5fbff4a599519f375788498fe1406bbde6b4388a21e542709f1331409065157c`。
- manifest 身份完全匹配；static checks、generic iOS build、Mac Catalyst build、XCTest 均 success；JUnit 为 `4 tests / 0 failures / 0 errors / 0 skipped`；XCTest 为 `197 passed / 0 failed / 0 skipped`，新增 `testBodyMetricsPreservesWordAndSectionResultsInSharedScan` 已执行并通过。Agent C 已下载并核对 `/private/tmp/mdjournal-c-review-32626526380/`；三份 xcresult 结构完整，ZIP 共 465 entries、未加密，CRC、fresh extract 文件清单和 465 项逐文件 SHA-256 均 PASS。后续 docs-only 提交只收敛这些验收记录，不改变实现和测试内容；最终 HEAD 仍以其对应 CI artifact 为准。

遗留事项：

- Swift parse 与纯值 characterization 不证明真实 Mac 长文输入的分配、帧率、VoiceOver 或设备交互；完整 iOS/Mac Catalyst build 和 XCTest 只以最新未加密 CI artifact 为准。

### v0.77 / 正文小节流式派生

日期：2026-08-09

核心变更：

- `JournalSection.extract(from:)` 改为单调 `String.Index`/`Substring` 逐行扫描，不再先用 `components(separatedBy: .newlines)` 物化整篇行数组；仅在标题命中和 section flush 时构造必要的 `String`。
- 保留 Foundation `.newlines` 的 LF、CR、CRLF、VT、FF、NEL、LS、PS 分隔语义，CRLF 只作为一个换行；继续保留 ASCII 空格/tab marker、空标题 trim、section flush/order/id/markdown/excerpt、EOF/尾随换行和 fenced code 中合法 marker 语义。未改 `containsLevelThreeSection`、Store、JSON、Markdown parser/preview 和 UI。
- `JournalEntryTests` 新增精确 extraction characterization，断言 count、title、markdown、excerpt、order 和 id，不含耗时或分配阈值。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.77（正文小节流式派生）.md`

验证与交付状态：

- 本轮按人工要求只运行 `git diff --check`、`git diff --cached --check`、Swift parse、workflow YAML、版本搜索和必要 plist 轻量检查；未运行本机 build、XCTest、xcodebuild、Simulator/CoreSimulator、Mac Catalyst app、脚本或 Instruments。
- 实现 commit `e128d52c499a591d2205fd464d80ba80a9dd2c66` 已在 `main` 推送到 `origin/main`；对应 `MD Journal CI Results` run `31300191066`、attempt `1` 成功，branch 为 `main`。
- 对应未加密 artifact ID `9034343049`，名称 `mdjournal-ci-v0.77-main-e128d52-run31300191066-attempt1`，size `443241` bytes，GitHub digest 与本地 SHA-256 均为 `sha256:6b44de8ff5b650763f33747924edb38c2e90a3ce367c731099b96f456817e6f0`。
- manifest 的 version、branch、commitSha、runId、runAttempt 完全匹配；static checks、generic iOS build、Mac Catalyst build 和 XCTest 均为 `success`。JUnit 为 `4 tests / 0 failures / 0 errors / 0 skipped`；XCTest 为 `196 passed / 0 failed / 0 skipped`，新增 extraction characterization 已执行并通过。
- Agent C 已下载并核对 artifact：ZIP 共 463 entries，全部未加密，CRC、fresh extract 文件清单和 463 项逐文件 SHA-256 均 PASS；三份 xcresult、failure summary、static/build/Mac Catalyst/XCTest 日志均已核对，Agent C 结论为 PASS。

遗留事项：

- 云端 generic iOS/Mac Catalyst build 和 XCTest 已通过，但 Swift parse、本地 characterization 和云端单元测试不能证明长文真实分配、帧率、VoiceOver 或真实 iOS/Mac 设备交互；本机 build、XCTest、Simulator/CoreSimulator 和 app 均未运行。CI 日志中的 AppIntents metadata warning 与一次 Simulator app launch warning 未影响 XCTest result `Passed`，但仍属于环境级遗留风险。

### v0.76 / 列表筛选选择一致性

日期：2026-08-09

核心变更：

- `ContentView` 集中持有搜索文本、分类筛选和 `JournalEntryListSnapshot`；`EntryListView` 消费父级 snapshot 与 binding，不再维护分离的筛选状态或另算列表 selection 来源。
- 新增 internal `JournalEntrySelectionPolicy`，生产 repair、detail guard、创建和删除后的修复共同使用“可见保留、隐藏切当前可见首项、空结果为 nil”规则；Mac Catalyst 较新/较早导航只遍历当前 `filteredEntries`，不跳转隐藏日记。
- 保留分类计数基于完整 entries、搜索 trim、真实空集合与筛选空结果区分，以及既有 `JournalStore`、JSON、Markdown、保存 debounce/flush、正文 binding 和删除确认语义。
- 新增 6 项纯测试：5 项 selection policy 测试覆盖可见保留、隐藏切首项、空结果 nil、筛选删除和新建匹配/隐藏，1 项 filtered navigation 测试覆盖可见顺序、隐藏目标和首尾不循环。

关键文件：

- `MDJournal/ContentView.swift`
- `MDJournal/Views/EntryListView.swift`
- `MDJournal/Utilities/JournalEntryListSnapshot.swift`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `MDJournalTests/JournalEntryNavigationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.76（列表筛选选择一致性）.md`

验证结果：

- 本地轻量检查通过：`git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`、`xcrun swiftc -parse MDJournalTests/JournalEntryListSnapshotTests.swift`、`xcrun swiftc -parse MDJournalTests/JournalEntryNavigationTests.swift`、workflow YAML 解析和 `VERSION: v0.76` 搜索均返回 0；Ruby YAML 解析伴随本机 `/opt/homebrew/bin` world-writable PATH warning，但仍输出 `yaml ok`。按人工要求不运行本地 build、XCTest、`xcodebuild`、Simulator/CoreSimulator、Mac Catalyst app、脚本、UI 自动化或截图。
- implementation HEAD `d3b11c3b63ea4af8d94dfbe1bc4d660766c06627` 对应 GitHub Actions run `31296673536` attempt `1`；未加密 artifact ID `9033210493`，名称 `mdjournal-ci-v0.76-main-d3b11c3-run31296673536-attempt1`，size `437199`，digest `sha256:86755783b134e7b1ee6ad1c2db1b7d20f1b99476ba7b87e7f445ba60c49b425f`。
- Agent C 已下载并核对 implementation artifact，结论 PASS：`195 passed / 0 failed / 0 skipped`，6 项新增测试各执行一次；`MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均 succeeded，errors/warnings/analyzer warnings 均为 `0`。ZIP 共 461 entries、未加密、CRC PASS，fresh extract list 与 ZIP 完全一致；下载工作目录额外存在一个本地 xcresulttool 生成的 `database.sqlite3`，已确认不属于 artifact。
- 最终文档 HEAD `822843b3af15dc180cb940587c10f372369eb69e`、branch `main` 对应 run `31297334280` attempt `1`；未加密 artifact ID `9033466495`，名称 `mdjournal-ci-v0.76-main-822843b-run31297334280-attempt1`，size `439409`，digest `sha256:7974609e893693967c7e47d848f58be1e132c729bd083fe90bedaa00a54e2fb1`。Agent C 已下载并核对 `/private/tmp/mdjournal-c-review-31297334280/`，结论 PASS：manifest/JUnit/outcomes 通过，`195 passed / 0 failed / 0 skipped`，6 项新增测试各执行一次，三份 xcresult succeeded 且 errors/warnings/analyzer warnings 为 0；ZIP 共 461 entries、未加密、CRC PASS，fresh extract 文件清单差异为 0。下载工作目录额外的本地 xcresulttool `database.sqlite3` 不属于 artifact。

遗留事项：

- 纯 policy 测试、Swift parse 和后续云端 build 不能证明真实筛选输入时序、NavigationSplitView selection/detail 瞬态、菜单 disabled 视觉、焦点、VoiceOver、Dynamic Type 或鼠标/触控板/键盘交互，仍需人工验收。
- v0.76 implementation artifact 保留为历史实现验证；最终文档 HEAD 已由上述最新 `origin/main` 未加密 artifact PASS，普通 build/XCTest/app 未在本机运行，完整验证仍以该云端结果包为准。

### v0.75 / Markdown 预览 latest-wins 防抖

日期：2026-08-09

核心变更：

- `MarkdownPreviewUpdateModel` 持有已解析的 `MarkdownParseResult`，`MarkdownPreviewView.body` 只消费状态结果，不再在每次 SwiftUI body 重算时直接调用 `MarkdownBlockParser.parseDocument`。
- 首次激活立即解析；正文连续变化使用固定 `150ms` trailing debounce，等待期间保留上一份预览，generation、entry ID、正文快照和 active 状态共同保证 latest-wins。
- 切换日记、隐藏预览或离开视图时取消并使旧 request 失效；accent、容器宽度和 Dynamic Type 只重新布局已有结果。正文 binding、`JournalStore` revision、保存 debounce、JSON schema 和 Markdown 解析语义未改变。
- 新增 4 项 `MarkdownPreviewTests`，使用手动 scheduler 覆盖首次立即发布、trailing 合并、迟到 request、entry/deactivate 失效和相同正文去重，并锁定 150ms 延迟。

关键文件：

- `MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownPreviewTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.75（Markdown预览latest-wins防抖）.md`

验证结果：

- 本地轻量检查通过：`git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`、`xcrun swiftc -parse MDJournalTests/MarkdownPreviewTests.swift`、workflow YAML 解析和 `VERSION: v0.75` 搜索均返回 0。Ruby YAML 解析输出本机 `/opt/homebrew/bin` world-writable PATH warning，但仍输出 `yaml ok`。
- 两名只读 reviewer 和既有 code review 均未发现 Swift 隔离、iOS 16 / Mac Catalyst 13 API、Store/正文/JSON 越界或 latest-wins 逻辑阻断；测试 mock 允许主动触发取消回调以确定性覆盖迟到结果。
- 本地完整 build、XCTest、模拟器和 app 均未运行，遵循人工要求；完整编译、concurrency warning 和测试执行只交给 GitHub Actions。
- 实现 commit `8b6fcc7d7b6dd519a6816d522827776a0ec9cb89` 已在 `main` 推送到 `origin/main`。对应 GitHub Actions run `31293183509`、attempt `1` 成功；artifact ID `9032161859`，名称 `mdjournal-ci-v0.75-main-8b6fcc7-run31293183509-attempt1`，digest `sha256:02a3104fc5d1fa364b7fa6c55303c70ecf93b90ae334cc48714ce7e27c8f749c`。
- Agent C 已下载并复判 `/private/tmp/mdjournal-c-review-31293183509/` 的未加密 artifact：manifest 的 `version=v0.75`、`branch=main`、完整 `commitSha`、`runId` 和 `runAttempt` 完全匹配；static checks、generic iOS build、Mac Catalyst build 和 XCTest 四阶段均为 `success`。JUnit 固定四阶段为 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；XCTest 为 `189 passed / 0 failed / 0 skipped`，4 项 `MarkdownPreviewTests` 各执行一次并通过。
- `MDJournal.xcresult` 和 `MDJournalMacCatalyst.xcresult` 均为 `succeeded`，errors/warnings/analyzer warnings 全为 `0`；`MDJournalTests.xcresult` 为 Passed，189 passed、0 failures。artifact 为 `428170` bytes，449 个文件，未加密；GitHub digest 与本地 SHA-256 一致，ZIP CRC 和逐文件 SHA-256 完整性检查通过。首次实现 artifact 已由 Agent C PASS，但文档收敛 commit 的最新 run/artifact 仍待补录。
- 文档收敛 commit `ab53ff61c2a29664df5e06d7da19edf0ed74deba` 已在 `main` 推送到 `origin/main`。对应 GitHub Actions run `31293672546`、attempt `1` 成功；artifact ID `9032289770`，名称 `mdjournal-ci-v0.75-main-ab53ff6-run31293672546-attempt1`，digest `sha256:a0c842cfcef591111db130f30755428132087f94b3af65245bb7cbf23c6a070c`。
- Agent C 已下载并复判 `/private/tmp/mdjournal-c-review-31293672546/` 的最新文档 HEAD 未加密 artifact：manifest 的 `version=v0.75`、`branch=main`、完整 `commitSha`、`runId` 和 `runAttempt` 完全匹配；JUnit 为 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；XCTest 为 `189 passed / 0 failed / 0 skipped`，4 项 `MarkdownPreviewTests` 各执行一次并通过。
- 该文档 HEAD artifact 的三份 xcresult 均为 `succeeded`，errors/warnings/analyzer warnings 全为 `0`；ZIP 为 `427163` bytes、449 个文件，未加密；GitHub digest 与本地 SHA-256 一致，ZIP CRC、解压和逐文件 SHA-256 完整性检查通过。Agent C PASS。
- 验收记录提交 `0215feacd27fa01a7369b684b647d62ab3f25efd` 触发的最终 HEAD run 为 `31294463918`、attempt `1`；artifact ID `9032564526`，名称 `mdjournal-ci-v0.75-main-0215fea-run31294463918-attempt1`，digest `sha256:45d6f4c37a20ff6ccb3de2951a7515098ad7310ea294dc2a00d0e7fbc3fcc53b`。Agent C 对该最新 `origin/main` artifact 最终 PASS。
- v0.75 最终 HEAD `f8a2d934e670a8a969958a2806f04af4bb24451a` 对应 run `31295125221`、attempt `1`；artifact ID `9032726874`，名称 `mdjournal-ci-v0.75-main-f8a2d93-run31295125221-attempt1`，size `425855`，digest `sha256:f40aa954660e4a86b19bfcc51ec140d9c200ece425c56e04c89705a782792efe`。
- Agent C 已下载并核对 v0.75 最终 HEAD artifact，结论 PASS：`189 passed / 0 failed / 0 skipped`，ZIP 共 449 entries、未加密，CRC 与 manifest match。

遗留事项：

- 单次 Markdown parse 仍在 MainActor 执行；本轮通过 trailing debounce 降低连续输入的触发频率，没有把解析跨 actor 搬运或改变 parser 语义。真实 Mac 长文输入延迟、帧率、Instruments 分配、SwiftUI 生命周期竞态、VoiceOver、Dynamic Type 像素排版和输入设备交互仍需云端结果包之外的人工验收。
- v0.75 最终 HEAD 已由上述最新未加密 artifact PASS；`189 passed / 0 failed / 0 skipped`，4 项预览策略测试各执行一次且通过，JUnit 的四阶段摘要不能替代 XCTest 用例总数。

### v0.74 / 编辑器头部辅助字号布局

日期：2026-07-28

核心变更：

- 新增 internal `EntryEditorLayoutContract`，把 `820pt` 编辑/预览工作区边界与头部紧凑策略拆开；宽屏 Accessibility 仍保留双栏，但元数据、summary 与统计 pill 改为堆叠并取消 `270pt` 统计固宽。
- Accessibility 标题取消两行上限，统计 pill 取消单行截断；小节标题/excerpt 放宽行数，excerpt 提升为 `.caption`，卡片以 `@ScaledMetric` 从 `156pt` 基准宽度缩放并删除 `132pt` 固定内宽。
- `MarkdownSnippetTests` 新增三项纯 contract 测试，覆盖 `819/820pt × .large/.accessibility1/.accessibility5` 六格矩阵、标题/小节行数与正有限尺寸；workflow 结果包版本更新为 `v0.74`。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.74（编辑器头部辅助字号布局）.md`

验证结果：

- Agent B 本地轻量检查通过：`git diff --check`、`git diff --cached --check`、project plist lint、应用与改动测试 Swift parse、workflow YAML 解析和 `VERSION: v0.74` 搜索均返回 0；定向范围检查确认 workflow 仅修改版本，Store、model、ContentView、列表、统计和 Xcode project 无 diff。Ruby 输出本机 `/opt/homebrew/bin` world-writable PATH warning，但 YAML 仍输出 `yaml ok`。
- 初始实现 commit `fae69eadffbc34203be1cd989f7925480d55ec91` 已 push 到 `origin/main`。对应 GitHub Actions run `30324143195`、attempt `1` 结论为 failure；artifact ID `8675035412`，名称 `mdjournal-ci-v0.74-main-fae69ea-run30324143195-attempt1`，digest `sha256:c59c3ce9df34c5b9d88ccd77fb4c5757e94919cc15877d1a93d8604212ffac13`。失败原因是 `EntryEditorView` 的 `header`、`metadata`、`statPills` 在局部声明 `AnyLayout` 后缺少显式 `return`，云端 iOS、Mac Catalyst 和 XCTest 均因 opaque return type 无法推断而编译失败；该失败 run 未用于通过结论。
- 最小修复 commit `04070fd72fc4fe989606fd328c98f9a421310884` 为上述三个 helper 补齐显式 `return`，已 push 到 `origin/main`。对应 `MD Journal CI Results` run `30324504741`、attempt `1` 结论为 success；artifact ID `8675244278`，名称 `mdjournal-ci-v0.74-main-04070fd-run30324504741-attempt1`，digest `sha256:9522dbc38fe66f28865bb51adf2838d6f106c2f60722069df98365e39a8efc9f`。
- Agent C 下载并复判修复 commit 的未加密 artifact：manifest 的 `version=v0.74`、`branch=main`、完整 commit SHA、run id、attempt、workflow、scheme、destinations、日志路径和四阶段 outcome 均匹配；static checks、generic iOS build、Mac Catalyst build 与 XCTest 全部 success。XCTest 为 `185 passed / 0 failed / 0 skipped`，三项新增 `EntryEditorLayoutContract` 测试各执行一次并通过；`MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均为 `succeeded`，且各为 0 errors、0 warnings、0 analyzer warnings。
- 通过 artifact ZIP 为 421,110 bytes，共 441 个条目且全部未加密；GitHub digest 与本地重算 SHA-256 一致，`unzip -t`、CRC 和 441 项逐文件比较全部通过。验收时下载目录为 `2.8M`，解压目录为 `2.4M`。Agent C 对修复 commit 的结论为 PASS。
- 文档收敛 commit `773df31deceda6f4f747c383dcc7da672a1a6ba1` 已 push 到 `origin/main`，对应最终文档 run `30325292473`、attempt `1` 结论为 success；artifact ID `8675550117`，名称 `mdjournal-ci-v0.74-main-773df31-run30325292473-attempt1`，digest `sha256:3c5ad131f3bbdbff3a7fee4d9244092c2f638146921b739d219a763c746b2e01`。manifest 身份完全匹配，四阶段均 success，三份 xcresult 均为 `succeeded` 且各为 0 errors、0 warnings、0 analyzer warnings。
- 该最终 artifact 的 JUnit 是 workflow 固定输出的四阶段摘要（`tests=4`、`failures=0`、`errors=0`、`skipped=0`）；185 项测试总数以 XCTest log / `MDJournalTests.xcresult` 等价权威摘要为准，为 `185 passed / 0 failed / 0 skipped`，三项新增布局契约测试各执行一次并通过。ZIP 为 420,100 bytes，共 441 个条目且全部未加密；GitHub digest 与本地重算 SHA-256 一致，`unzip -t`、CRC 和 441 项逐文件比较全部通过，下载目录为 `3.3M`、解压目录为 `2.9M`。Agent C 已下载并核对该最终文档 HEAD artifact。
- 按人工要求不运行本地 build、XCTest、模拟器或 app；完整编译与测试只采用 GitHub Actions 回传结果包。

遗留事项：

- 纯 contract 测试和云端 build 不能证明真实 Mac/iPhone 的 Dynamic Type 像素排版、VoiceOver、focus ring、键盘、鼠标或触控板交互；普通窄屏更高的头部、AX5 极长标题与可缩放横向卡片仍需人工验收。

### v0.73 / 持久化移出主线程

日期：2026-07-26

核心变更：

- 新增 internal `JournalPersistenceSnapshot` / `JournalPersistenceResult` / `JournalPersistenceWriting` 与 `JSONJournalPersistenceWriter` actor；actor 独占原有 ISO8601、pretty printed、sorted keys 和 atomic JSON 写入，并以 highest accepted / durable revision 保证旧请求拒绝、成功幂等和失败同 revision 可重试。
- `JournalStore` 保持 MainActor 内存边界，每次有效 mutation 递增 revision；update 使用可注入 scheduler debounce，等待阶段只捕获 pending ID，触发时才生成 entries 快照，避免连续输入因旧 debounce 快照触发整组数组 COW。create/delete 与首次 starter 绕过延迟提交不可变快照。
- async flush 会取消 pending、等待 writer，并追赶等待期间出现的最新 revision；没有 mutation 的 revision 0 flush 直接返回，读取损坏时不会用空数组覆盖原文件。写入结果按 revision 和 durable revision 仲裁，同 revision 成功后的迟到失败不会污染 UI；读取错误和 revision 绑定的写入错误分开管理。
- `JournalEntry` 及 Category/Mood 显式 `Sendable`；新 writer 文件只登记 app target。Store 测试由 5 项扩展为 19 项，仓库预期从 168 增至 182 项；gate teardown 幂等恢复未完成 continuation，并补齐无 mutation flush、在途旧写入后 delete、同 revision 迟到失败与 Store deinit 契约。

关键文件：

- `MDJournal/Stores/JournalPersistenceWriter.swift`
- `MDJournal/Stores/JournalStore.swift`
- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/ContentView.swift`
- `MDJournalTests/JournalStoreTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`
- `md/prompt/v0（性能优化）/v0.73（持久化移出主线程）.md`

验证结果：

- Agent B 本地轻量检查通过：`git diff --check`、production 与 Store 测试 Swift parse、`plutil -lint`、workflow YAML / v0.73、工程登记计数、19/182 测试方法计数及禁用 API / encode-write / actor await 搜索。禁用 API 搜索仅命中本轮范围外既有 `MarkdownBodyTextView` 两处 GCD；v0.73 改动无命中。按人工要求不运行本地 build、XCTest、模拟器或 app，完整编译、并发 warning 与 XCTest 交给 GitHub Actions。
- 初始实现 commit `8219c148c9162885b62b5c089743a476e205601e` 后，经两名独立 reviewer 发现并修复损坏文件无 mutation flush 覆写、同 revision 迟到失败、debounce 旧快照 COW 和 gate 测试清理/覆盖缺口；修复 commit `15170bc19659b8f956cb4696a8c897246b7d0b03` 已在 `main` 直推 `origin/main`。
- GitHub Actions `MD Journal CI Results` run `30321485151`、attempt `1` 成功。Agent C 已下载并核对 artifact ID `8674287395`、名称 `mdjournal-ci-v0.73-main-15170bc-run30321485151-attempt1`：manifest 的 `version=v0.73`、`branch=main`、`commitSha`、`runId`、`runAttempt` 与目标一致，static / iOS build / Mac Catalyst build / XCTest 四阶段均为 `success`。
- XCTest 为 `182 passed / 0 failed / 0 skipped`，19 项 `JournalStoreTests` 均唯一执行并通过；三份 xcresult 均为 `succeeded`，且各自为 0 errors、0 warnings、0 analyzer warnings，未发现 Swift concurrency、Sendable、actor isolation、data race 或 continuation warning。
- artifact ZIP 共 435 个条目且全部未加密，GitHub digest 与重算 SHA-256 均为 `8282eb86fbad435494ab9207dc0a3a185ebdd1f4ce0a24873aff01c8ad5f3754`，CRC 和逐文件完整性检查通过。该验收记录提交后还需对文档 commit 自己的最新 run/artifact 复核最终 HEAD。

遗留事项：

- 全量快照 encode/write 仍为 `O(T)`，并持有 `[JournalEntry]` copy-on-write 值；本轮不是增量数据库迁移。
- create/delete 返回时只保证内存即时变化并已安排 actor 请求，磁盘可能尚未开始或仍在写；awaited flush 只提供进程存活期间的明确完成结果。
- scene phase Task 没有系统后台执行 lease，快速挂起、崩溃、断电或强杀仍可能丢失尚未 durable 的最新 revision；确定性 XCTest 不等价于 Instruments 或真实大数据、后台和 Mac 长时间写作验收。

### v0.72 / 删除日记确认保护

日期：2026-07-26

核心变更：

- 新增 internal `JournalDeletionConfirmationState`，待确认期间稳定持有完整 `JournalEntry`；请求可替换旧目标，dismiss 幂等清空，确认目标在返回前先清空且只能消费一次。
- 列表滑动删除与 Mac Catalyst 右键删除统一调用 `requestDeletion(of:)`，共享一个系统 `confirmationDialog`；标题准确使用目标 `displayTitle`，destructive “删除”按钮确认后才调用既有 `onDelete`，cancel 和 presentation 外部关闭只清理状态。
- 保持 `ContentView.deleteEntry(_:) -> JournalStore.delete(_:) -> repairSelection`、立即保存、JSON 格式、搜索筛选、列表 selection 和删除后选择行为不变。
- `JournalEntryListSnapshotTests` 新增 4 项纯状态转换测试；GitHub Actions 结果包版本更新为 `v0.72`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryListView.swift`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.72（删除日记确认保护）.md`
- `update_log.md`

验证结果：

- Agent B 本地轻量检查通过：`git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、应用与改动测试 Swift parse、workflow YAML 解析和 `VERSION: v0.72` 断言；YAML 解析伴随本机 `/opt/homebrew/bin` world-writable PATH warning，不影响 `yaml ok` 结果。
- 实现 commit `8a227d58ed6690edc2b6c7eb1f5dfd3975e0a5b7` 已在 `main` 直推 `origin/main`；GitHub Actions `MD Journal CI Results` run `30195376367`、attempt `1` 成功。
- Agent C 已下载并核对未加密 artifact `mdjournal-ci-v0.72-main-8a227d5-run30195376367-attempt1`（artifact ID `8630031906`）：manifest 的 `version=v0.72`、`branch=main`、`commitSha`、`runId`、`runAttempt` 与目标一致，static / iOS build / Mac Catalyst build / XCTest 四类 outcome 均为 `success`。
- XCTest 为 `168 passed / 0 failed / 0 skipped`，四项新增删除确认状态测试均实际执行；三份 xcresult 均为 `succeeded`，且为 0 errors、0 warnings、0 analyzer warnings。云端 ZIP 的 407 个条目全部未加密，GitHub digest、重算 SHA-256、CRC 和逐文件完整性检查通过。
- 按人工要求不运行本地 build、XCTest、模拟器或 app；完整编译与测试只采用 GitHub Actions 回传结果包。

遗留事项：

- 纯状态测试不能证明系统对话框的真实视觉、焦点、Esc、点击外部、右键菜单事件或滑动手势；iOS 与 Mac Catalyst 的交互和辅助功能仍需人工 UI 验收。
- 本轮不提供废纸篓、撤销或软删除；用户确认后仍沿既有链路立即永久删除并保存。

### v0.71 / 统计趋势辅助字号

日期：2026-07-26

核心变更：

- 新增 internal `SevenDayBarChartLayoutContract`，集中管理 92pt 柱图区、14pt 词数最小高度、134pt 图表最小高度、56pt Accessibility 列宽和 Dynamic Type 滚动策略。
- 最近 7 天趋势在普通字号下继续使用七列等分布局；只有 Accessibility Dynamic Type 使用稳定列宽的水平滚动，避免窄 iPhone 和窄 Mac Catalyst 窗口继续压缩各列。
- 词数标签和图表根容器从固定高度改为最小高度，允许语义文字自然增高；柱图区固定高度、柱高比例、零值规则、日期顺序、颜色、圆角和间距保持不变。
- 新增两项纯布局契约测试；`JournalStatistics` 算法、Store、model、ContentView、本地 JSON 和 Xcode 工程均未改变。
- GitHub Actions 结果包版本更新为 `v0.71`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/StatisticsDashboardView.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.71（统计趋势辅助字号）.md`
- `update_log.md`

验证结果：

- Agent B 本地轻量检查已通过：`git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、应用与统计测试 Swift parse、workflow YAML 解析和 `VERSION: v0.71` 断言；YAML 解析伴随本机 `/opt/homebrew/bin` world-writable PATH warning，不影响 `yaml ok` 结果。
- 实现 commit `f66ba009140559c783329175b593a5891e8f6ce3` 已在 `main` 直推 `origin/main`；GitHub Actions `MD Journal CI Results` run `30194301840`、attempt `1` 成功。
- Agent C 已下载并核对未加密 artifact `mdjournal-ci-v0.71-main-f66ba00-run30194301840-attempt1`（artifact ID `8629662729`）：manifest 的 `version=v0.71`、`branch=main`、`commitSha`、`runId`、`runAttempt` 与目标一致，static / iOS build / Mac Catalyst build / XCTest 四类 outcome 均为 `success`。
- XCTest 为 `164 passed / 0 failed / 0 skipped`，两项新增统计趋势布局契约测试均实际执行；三份 xcresult 均为 `succeeded`，且为 0 errors、0 warnings、0 analyzer warnings。云端 ZIP 的 399 个条目全部未加密，GitHub digest、重算 SHA-256、CRC 和逐文件完整性检查通过。
- 按人工要求不运行本地 build、XCTest、模拟器或 app；完整编译与测试只采用 GitHub Actions 回传结果包。

遗留事项：

- 纯契约测试只证明尺寸常量和字号策略，不证明真实 Dynamic Type 视觉、文字无裁切、滚动手感或普通字号像素级一致性。
- 56pt 稳定列宽在极端词数位数、不同语言和最大 Accessibility 字号下仍需真机检查；Mac Catalyst 鼠标、触控板、键盘与 VoiceOver 的横向滚动交互也需人工验收。
- 本轮不改变写入性能路径，既有统计预计算、按需排序、Store 节流与 JSON 保存仅作为不得回归边界。

### v0.70 / 日记日期辅助功能

日期：2026-07-26

核心变更：

- 新增 internal `EntryEditorAccessibilityContract.journalDateLabel`，将编辑器头部日期控件的字段名称固定为“日记日期”。
- 系统 `DatePicker` 直接消费该契约，并保留 `.labelsHidden()`、compact 样式、`$entry.createdAt` binding 和仅日期组件；未增加可见 label 或自定义辅助功能值。
- 新增精确文案与去空白非空纯契约测试；日期变更后的 Store update、按需排序、合并保存和本地 JSON 链路保持不变。
- GitHub Actions 结果包版本更新为 `v0.70`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.70（日记日期辅助功能）.md`
- `update_log.md`

验证结果：

- Agent B 本地轻量检查已通过：`git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、应用与改动测试文件 Swift parse、workflow YAML 解析和 `VERSION: v0.70` 断言。
- 实现 commit `b848f2bb1678065fc1f5a89da6a58eab365c838a` 已在 `main` 直推 `origin/main`。
- GitHub Actions `MD Journal CI Results` run `30193059412`、attempt `1` 成功；未加密 artifact 为 `mdjournal-ci-v0.70-main-b848f2b-run30193059412-attempt1`，artifact ID `8629302428`。
- Agent C 已下载并核对结果包：manifest 的 `version=v0.70`、`branch=main`、`commitSha`、`runId`、`runAttempt` 与目标一致，static / iOS build / Mac Catalyst build / XCTest 四类 outcome 均为 `success`。
- XCTest 为 `162 passed / 0 failed / 0 skipped`，新增 `testEntryEditorDatePickerAccessibilityLabelContract` 在日志与 xcresult 中均实际通过；三份 xcresult 均为 0 errors、0 warnings、0 analyzer warnings。云端 ZIP 的 395 个条目全部未加密，digest、CRC 和逐文件完整性检查通过。
- 按人工要求不运行本地 build、XCTest、模拟器或 app；完整编译与测试只采用 GitHub Actions 回传结果包。

遗留事项：

- 纯契约测试只证明被视图直接消费的 label 文案，不证明 `.labelsHidden()` 后的真实 accessibility tree、VoiceOver 日期值与朗读顺序、Mac Catalyst focus ring 或 compact picker 交互。
- iPhone/iPad 窄屏、横屏、Dynamic Type 和 Mac Catalyst 头部布局仍需人工交互验收；本轮不改变写入性能路径。

### v0.69 / 分类筛选辅助功能

日期：2026-07-26

核心变更：

- 分类筛选 chip 使用视图实际消费的 `44pt` 最小交互高度契约，并保留语义字体与垂直 padding，允许 Dynamic Type 自然增高。
- Button label 在最终最小高度后设置矩形命中形状；始终保留可缩放的 checkmark 槽位，以透明度切换可见性，避免选中切换造成布局跳动。
- checkmark 从辅助功能树隐藏；Button 使用明确的“标题，数量 篇”文案，并只在选中时添加 `.isSelected` trait。
- 新增最小高度与可访问文案纯契约测试；筛选算法、分类计数、横向滚动、视觉主题、Store、JSON 和 Xcode 工程均未改变。
- GitHub Actions 结果包版本更新为 `v0.69`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryListView.swift`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.69（分类筛选辅助功能）.md`
- `update_log.md`

验证结果：

- 实现 commit `c3ca997b2b7cdf4c27dd66c87863d9f172acd5b4` 已在 `main` 直推 `origin/main`。
- 本地轻量检查通过：`git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、app/test Swift `xcrun swiftc -parse`、workflow YAML 解析和 `VERSION: v0.69` 核对。
- GitHub Actions `MD Journal CI Results` run `30191709502`、attempt `1` 成功；未加密 artifact 为 `mdjournal-ci-v0.69-main-c3ca997-run30191709502-attempt1`。
- Agent C 已下载并核对结果包：manifest 的 `version=v0.69`、`branch=main`、`commitSha`、`runId`、`runAttempt` 与目标完全一致，static / iOS build / Mac Catalyst build / XCTest 四类 outcome 均为 `success`。
- XCTest 为 `161 passed / 0 failed / 0 skipped`，两项新增分类筛选 contract 测试均实际执行；三份 xcresult 均为 0 errors、0 warnings、0 analyzer warnings，结果包 393 个条目均未加密且完整性检查通过。
- 按人工要求不运行本地 build、XCTest、模拟器或 app；完整编译与测试只采用 GitHub Actions 回传结果包。

遗留事项：

- 契约测试只证明视图消费的最小高度常量和可访问文案，不证明真实 frame、hit testing、Dynamic Type 渲染、VoiceOver 朗读、Mac Catalyst focus ring 或切换视觉；这些仍需人工 iOS / Mac Catalyst 交互验收。
- 稳定勾选槽会使 chip 略宽，极端 Dynamic Type 下横向滚动长度会增加，这是保持清晰文案、触控面积和布局稳定性的预期取舍。

### v0.68 / Mac 键盘切换日记

日期：2026-07-26

核心变更：

- 新增纯 `JournalEntryNavigation` 规则，严格按 `JournalStore.entries` 当前新到旧顺序解析较新或较早目标 ID；首尾不循环，空列表、单篇、`nil` 与失效 selection 均返回 `nil`。
- `ContentView` 通过单一 focused scene actions value 暴露两个可选导航闭包；有目标的动作只更新 `selectedEntryID`，无目标的方向保持 `nil`，不调用 Store、保存或编辑器焦点 API。
- Mac Catalyst “日记”菜单新增“较新日记”与“较早日记”，分别使用 `⌘⌥↑` / `⌘⌥↓`，并按对应动作是否存在独立禁用。
- 新增纯导航矩阵、边界、输入顺序和命令元数据测试，统一检查导航、写作、Markdown 与保留 `⌘N` 的快捷键唯一性。
- GitHub Actions 结果包版本更新为 `v0.68`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/JournalEntryNavigation.swift`
- `MDJournalTests/JournalEntryNavigationTests.swift`
- `MDJournal/MDJournalApp.swift`
- `MDJournal/ContentView.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（Mac体验）/v0.68（键盘切换日记）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、XCTest、模拟器或 app；`git diff --check`、Xcode project `plutil -lint`、应用 Swift parse、workflow YAML parse、`VERSION: v0.68` 断言和工程登记检查均通过。YAML 解析伴随本机 `/opt/homebrew/bin` world-writable PATH warning，不影响 `yaml ok` 结果；staged diff 检查在暂存后执行。
- 实现 commit `26f5e671e17d33d498ff47745dc51147b4a73a67` 已 push 到 `origin/main`。初始 GitHub Actions run `30190429963`、attempt `1` 的未加密 artifact 为 `mdjournal-ci-v0.68-main-26f5e67-run30190429963-attempt1`；四阶段和 159 项 XCTest 虽全部通过，但 `MDJournalTests.xcresult` 出现 2 条 `KeyEquivalent` 的 iOS 17 可用性警告，Agent C 判定不通过。
- 修复 commit `269d019ba2a7ddf8b9b18c6229849eb21bff1c51` 仅将两条快捷键测试改为比较 `character`，已 push 到 `origin/main`。最终 GitHub Actions run `30190792407`、attempt `1` 的未加密 artifact 为 `mdjournal-ci-v0.68-main-269d019-run30190792407-attempt1`；四阶段全部成功，JUnit 为 4/0/0/0，XCTest 159/159 通过，六项导航测试均实际执行，三个 xcresult 均可读取且 errors、warnings 和 analyzer warnings 均为 0，Agent C 复判通过。

遗留事项：

- 纯规则测试验证方向、边界和快捷键元数据，Swift parse 与云端 Mac Catalyst build 只间接验证 commands / focused value 接线；真实菜单 disabled 视觉、正文 first responder 持续性和键盘事件分发仍需人工 Mac Catalyst 交互复核。
- 本轮只改变 selection 导航，不基于搜索或分类筛选，不触发额外保存，也不修改 Store、编辑器正文、JSON 或排序语义。

### v0.67 / 正文输入直接写回

日期：2026-07-26

核心变更：

- `MarkdownBodyTextView.Coordinator` 将普通输入、成功 Markdown 回车续写和成功行缩进统一改为直接单次发布正文 binding，不再在 setter 前读取旧正文并执行全文相等比较。
- `updateUIView` 继续只在无 marked text 且外部正文不同时更新 `UITextView`；IME 守卫、UTF-16 选区、选区/焦点按需写回、输入 traits、字体与纯规则语义均未改变。
- `MarkdownTextInputConfigurationTests` 增加三个引用型 Binding probe 测试，分别断言普通输入、回车续写和缩进每次执行 `0` 次正文 getter、`1` 次正文 setter，并核对正文与选区结果。
- GitHub Actions 结果包版本更新为 `v0.67`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownTextInputConfigurationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.67（正文输入直接写回）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、XCTest、模拟器或 app；`git diff --check`、Xcode project `plutil -lint`、应用 Swift parse、改动测试文件 Swift parse、workflow YAML parse 和 `VERSION: v0.67` 断言均通过。YAML 解析伴随本机 `/opt/homebrew/bin` world-writable PATH warning，不影响 `yaml ok` 结果；staged diff 检查在暂存后执行。
- 实现 commit `2ca38f5caf50c74f37d195a8b63260b82946b2d3` 已 push 到 `origin/main`；对应 GitHub Actions run `30188662641`、attempt `1` 和未加密 artifact `mdjournal-ci-v0.67-main-2ca38f5-run30188662641-attempt1`。该轮共执行 153 项 XCTest，其中三项新增正文写回计数测试因把 Coordinator 和 `UITextView` 准备阶段的初始化 getter 计入被测动作而误判失败，云端验收不通过。
- 测试修复 commit `6107669b2b3799b7acda46d5c6701f4ab2694ec8` 仅将三项测试改为在动作前记录 getter/setter 基线，并继续断言动作增量为 `0 getter / 1 setter`；生产代码未改动。该 commit 已 fast-forward push 到 `origin/main`。
- 最终 GitHub Actions run `30189105798`、attempt `1` 通过；Agent C 下载并核对未加密 artifact `mdjournal-ci-v0.67-main-6107669-run30189105798-attempt1`，确认 manifest 身份与版本匹配，静态检查、generic iOS build、Mac Catalyst build 和 XCTest 四阶段均为 `success`。
- JUnit 阶段摘要为 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；XCTest 为 153/153 通过、失败 0、跳过 0，三项新增正文写回计数测试均实际执行并通过。`MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均可读取，状态为 `succeeded`，错误、警告和分析警告均为 0。

遗留事项：

- 三项确定性测试只证明 Coordinator 在三个入口不读取正文 binding 且只写一次，不量化真实设备的耗时或内存分配，也不代表上游 `Binding<JournalEntry>` setter 内部零查找。
- 本轮未做真实键盘、中文输入法、first responder、光标视觉或 Mac Catalyst UI 交互验证；marked-text 守卫和现有状态边界保持不变，仍需后续人工交互复核。

### v0.66 / 列表概览小节检测快路径

日期：2026-07-26

核心变更：

- `JournalSection` 新增 `containsLevelThreeSection(in:)`，使用 Unicode scalar 和单调递增的 `String.Index` 扫描正文；每个行首只跳过 ASCII 空格/tab，以 `CharacterSet.newlines` 覆盖现有换行边界，并在首个精确 `### ` 前缀处提前返回。
- `JournalListOverviewSnapshot` 分别调用 `JournalEntryBodyMetrics.wordCount(in:)` 和新谓词，不再读取 `entry.bodyMetrics`，避免列表概览为每篇正文构造完整小节数组。
- `JournalEntryTests` 增加明确期望与 `JournalSection.extract(from:)` 等价的边界矩阵；`JournalListOverviewSnapshotTests` 增加合法和非法标题混合聚合测试。
- `JournalSection.extract(from:)`、`JournalStatistics`、UI、Store、Xcode 工程和 JSON 持久化格式均未修改。
- GitHub Actions 结果包版本更新为 `v0.66`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/JournalListOverviewSnapshot.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `MDJournalTests/JournalListOverviewSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.66（列表概览小节检测快路径）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、XCTest、模拟器或 app；`git diff --check`、Xcode project `plutil -lint`、Swift parse、workflow YAML parse 和 `VERSION: v0.66` 断言均通过。YAML 解析伴随本机 `/opt/homebrew/bin` 权限 warning，不影响解析结果。
- 实现 commit：`e754714efccde0184e8903270cb4a2c98acb1ce1`（`v0.66 优化列表概览小节检测`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `30187354229`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.66-main-e754714-run30187354229-attempt1`，下载到 `/private/tmp/mdjournal-c-review-30187354229/` 复判。
- Agent C 复判结果：manifest 的 `version=v0.66`、`branch=main`、`commitSha=e754714efccde0184e8903270cb4a2c98acb1ce1`、`runId=30187354229`、`runAttempt=1` 完全匹配；静态检查、iOS build、Mac Catalyst build 和 XCTest outcome 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；XCTest xcresult 显示 150 项测试全部通过，且本轮新增的两个边界测试均实际执行。iOS 和 Mac Catalyst 日志包含 `** BUILD SUCCEEDED **`，XCTest 日志包含 `** TEST SUCCEEDED **`，三个 `.xcresult` 的 `Info.plist` 与结果摘要均可读取。

遗留事项：

- 本轮通过实现结构证明概览不再构造行数组或完整小节模型，不使用易抖动的耗时/分配阈值；实际输入期间的分配变化可在后续人工 Instruments 采样中量化。
- 新谓词与完整提取的已知边界语义已由 GitHub Actions XCTest 及 Agent C 最新 artifact 复判确认；边界矩阵不是穷举或随机差分测试。
- 本轮只优化列表概览的小节存在性判断，不改变统计看板和真正需要小节内容的编辑器、列表行、摘要或预览路径。

### v0.65 / Markdown 工具栏 44pt 交互区

日期：2026-07-26

核心变更：

- `MarkdownToolbar` 将每个 Markdown 图标按钮的 label 从 `34×34pt` 提升到 `44×44pt`，并在 frame 后紧接矩形 `contentShape`，让完整按钮标签参与命中测试。
- 保持 `16pt semibold` 图标、`8pt` 间距、水平滚动、纯按钮样式、accent 背景、片段顺序、`onInsert`、hover help 和辅助功能标签不变。
- GitHub Actions 结果包版本更新为 `v0.65`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownToolbar.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.65（Markdown工具栏44pt交互区）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、XCTest、模拟器或 app；本地 `git diff --check`、Swift parse、workflow YAML parse、`VERSION: v0.65` 断言和 Xcode project `plutil -lint` 均通过。
- 实现 commit：`eed32383ed8b004b9e9a424ee2254ad5b6474adb`（`v0.65 提升 Markdown 工具栏交互区`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `30185985808`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.65-main-eed3238-run30185985808-attempt1`，下载到 `/private/tmp/mdjournal-c-review-30185985808/` 复判。
- Agent C 复判结果：manifest 的 `version=v0.65`、`branch=main`、`commitSha=eed32383ed8b004b9e9a424ee2254ad5b6474adb`、`runId=30185985808`、`runAttempt=1` 完全匹配；静态检查、iOS build、Mac Catalyst build 和 XCTest outcome 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；iOS 和 Mac Catalyst 日志包含 `** BUILD SUCCEEDED **`，XCTest 日志包含 `** TEST SUCCEEDED **`，三个 `.xcresult` 的 `Info.plist` 均可解析。

遗留事项：

- `44×44pt` 会增加工具栏高度，并减少窄屏同一时刻可见的按钮数量；现有水平滚动继续承载全部按钮。
- Swift parse 与后续云端 build 不能直接证明实际点击命中区或视觉效果；当前没有 UI test target，仍需后续人工在 Mac Catalyst、iPhone 窄屏和辅助功能检查中确认命中、滚动与 hover 表现。
- 本轮只调整 Markdown 工具栏交互区，不改变片段元数据、插入规则、编辑器状态流、JSON 持久化或整体视觉主题。
- 下一轮优先优化列表概览的小节检测路径，避免正文编辑触发列表刷新时为每篇日记构造完整小节数组。

### v0.64 / 列表筛选空状态修正

日期：2026-07-26

核心变更：

- `JournalEntryListSnapshot` 新增 `isCollectionEmpty`，用总日记数区分真实空日记库和筛选空结果。
- `EntryListView` 在真实空库时继续显示“还没有日记”和“写一篇”；仓库非空但搜索或分类无结果时显示“没有符合条件的日记”。
- 筛选空结果新增“清除筛选”入口，同时重置搜索文本和选中分类，恢复完整列表。
- `JournalEntryListSnapshotTests` 增加空集合与分类筛选无结果的状态断言。
- GitHub Actions 结果包版本更新为 `v0.64`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/JournalEntryListSnapshot.swift`
- `MDJournal/Views/EntryListView.swift`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（界面优化）/v0.64（列表筛选空状态修正）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 两个只读子 agent 分别审计 Mac 写作工具栏和列表/统计 UI：列表 agent 发现分类筛选为 0 时误显示真实空库状态，本轮已修复；Mac agent 发现 Markdown 工具栏按钮为 34×34pt，留作 v0.65。
- staged diff reviewer 要求覆盖原始“空搜索 + 计数为 0 分类”路径，本轮已补充对应测试；清除按钮同时重置两个私有 SwiftUI `@State` 的交互尚无 UI test 自动化覆盖，云端 iOS / Mac Catalyst build 只验证编译，后续需补 UI test 或人工交互验收。
- 本地轻量检查：`git diff --check` 返回 0；workflow YAML 解析输出 `yaml ok`（伴随本机 PATH 权限 warning，不影响解析）；`VERSION: v0.64` 断言通过；`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 返回 0。
- 实现 commit：`801ea9038a79588477644240f848f562ad6a3187`（`v0.64 修正列表筛选空状态`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `30185009247`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.64-main-801ea90-run30185009247-attempt1`，下载到 `/private/tmp/mdjournal-c-review-30185009247/` 复判。
- Agent C 复判结果：manifest 的 `version=v0.64`、`branch=main`、`commitSha=801ea9038a79588477644240f848f562ad6a3187`、`runId=30185009247`、`runAttempt=1` 完全匹配；静态检查、iOS build、Mac Catalyst build 和 XCTest outcome 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；iOS 和 Mac Catalyst 日志包含 `** BUILD SUCCEEDED **`，XCTest 日志包含 `** TEST SUCCEEDED **`，三个 `.xcresult` 的 `Info.plist` 均可解析。

遗留事项：

- 本轮只修正列表空状态与恢复入口，不改变搜索匹配、分类计数、列表排序、新建、删除、JSON 持久化或编辑器行为。
- 下一轮 v0.65 优先把 Markdown 工具栏按钮点击区从 34×34pt 提升到 44×44pt。

### v0.63 / CI XCTest 超时与模拟器选择

日期：2026-07-12

核心变更：

- CI job 增加 `timeout-minutes: 25`，避免 workflow 无限挂起。
- XCTest 使用 `perl alarm 720` 与 `-destination-timeout 60`，限制模拟器 boot/test 阻塞时间。
- 模拟器 destination 解析优先 `iPhone 16`，否则选择较新 iOS runtime 的可用 iPhone。
- 结果包 `VERSION` 更新为 `v0.63`。
- 同步 README、测试规范、核心流程和本轮 Agent A 提示词。

关键文件：

- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/prompt/v0（协作云端化）/v0.63（CI XCTest超时与模拟器选择）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app。
- 实现 commit：`f893c7f69a9913f4bca7175926a1ebe2b9f2c31b`（`v0.63 约束 CI XCTest 超时`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `29170697274`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.63-main-f893c7f-run29170697274-attempt1`，下载到 `/private/tmp/mdjournal-c-review-29170697274/` 复判。
- Agent C 复判结果：manifest 中 `version=v0.63`、`branch=main`、`commitSha=f893c7f69a9913f4bca7175926a1ebe2b9f2c31b`、`runId=29170697274`、`runAttempt=1` 完全匹配；静态检查、iOS build、Mac Catalyst build 和 XCTest outcome 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；iOS 与 Mac Catalyst 日志均包含 `** BUILD SUCCEEDED **`，XCTest 日志包含 `** TEST SUCCEEDED **`，三个 `.xcresult` 的 `Info.plist` 均可解析。
- v0.63 最新 `main` 包含 v0.62 Mac 写作工具栏辅助功能标签改动，因此本次 artifact 同时完成 v0.62 的后续云端重验证。

遗留事项：

- 本轮只修复云端 XCTest 挂起风险，不改业务逻辑。
- 下一轮继续 Mac / UI polish。

### v0.62 / Mac 写作工具栏辅助功能标签

日期：2026-07-12

核心变更：

- Mac Catalyst 写作工具栏为聚焦正文、专注写作、减少缩进、增加缩进显式设置与 `EditorWritingCommand.title` 一致的 `accessibilityLabel`。
- “插入”菜单 help 与辅助功能标签统一复用 `EditorWritingCommand.insertMarkdownAccessibilityLabel`（`插入 Markdown`）。
- 预览切换按钮继续使用状态化 `previewToggleTitle` 辅助功能标签，不回退。
- `MarkdownSnippetTests` 增加写作工具栏 accessibility 文案断言。
- GitHub Actions 结果包版本更新为 `v0.62`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.62（Mac写作工具栏辅助功能标签）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check`、workflow YAML parse、`VERSION: v0.62` 断言、`xcrun swiftc -parse` 通过。
- 实现 commit：`0adc473862bc01d75b8dc89cf62528175681d0b1`（`v0.62 补齐 Mac 写作工具栏辅助功能标签`），已 push 到 `origin/main`。
- GitHub Actions run `29165393920` attempt `1` 在 XCTest 挂起后被取消；attempt `2` 同样在 XCTest 长时间 in_progress 后被取消，未能产出可验收 artifact。
- 因此 v0.62 业务改动已上 main，但云端完整 artifact 验收未完成；由 v0.63 修复 CI 超时与模拟器选择后重新验证。

遗留事项：

- 本轮只补齐 Mac Catalyst 写作工具栏辅助功能标签，不改变布局、快捷键、菜单语义、Markdown 规则、JSON 持久化或统计口径。
- 用户总目标仍是“全面优化界面、UI”；通过后 Agent X 应继续下一轮 Mac / UI polish 小目标。

### v0.61 / Markdown 解析逐行迭代

日期：2026-07-11

核心变更：

- `MarkdownBlockParser.parse(_:)` 从 `components(separatedBy: .newlines)` 改为私有逐行迭代 helper，避免长文预览解析前先构造整篇行数组。
- 逐行 helper 使用 newline 字符范围推进，并显式把 CRLF 作为同一个分隔边界处理，保持当前 CR-only / CRLF 解析语义。
- parser 在需要写入段落或代码缓冲时才将当前 `Substring` 转为 `String`，其他 marker 识别继续复用原正文切片。
- `MarkdownBlockParserTests` 增加普通文本尾随 LF / CR / CRLF、未闭合代码块尾随换行和 CRLF fenced code 空行保留覆盖。
- GitHub Actions 结果包版本更新为 `v0.61`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.61（Markdown解析逐行迭代）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok`；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.61` 存在；`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 返回 0 且无输出。
- 子 agent 只读复核：确认 `components(separatedBy: .newlines)` 是 `MarkdownBlockParser` 剩余明确分配点，本轮适合做等价替换；建议锁定 CR-only、CRLF、尾随换行、代码块空行、`###` 分组和列表语义。本轮已按建议实现和补充测试。
- 实现 commit：`d056656c1c8fffa0cab261139173d6282147aa30`（`v0.61 优化 Markdown 解析分行`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `29138242142`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.61-main-d056656-run29138242142-attempt1`，下载到 `/private/tmp/mdjournal-c-review-29138242142/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.61`、`branch=main`、`commitSha=d056656c1c8fffa0cab261139173d6282147aa30`、`runId=29138242142`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 `MarkdownBlockParser` 分行输入策略，不改变 Markdown 支持范围、代码块 join 使用 `\n` 的当前行为、`###` 小节识别、Markdown 预览渲染、JSON 持久化、统计口径、Xcode target 或 Mac Catalyst 构建方式。
- 用户总目标已扩展到“全面优化界面、UI”；本轮完成后 Agent X 下一轮应优先选择 Mac / UI polish 小目标，而不是继续只做底层性能优化。

### v0.60 / Markdown 解析循环轻量化

日期：2026-07-07

核心变更：

- `MarkdownBlockParser.parse(_:)` 调整每行解析顺序，代码块内优先处理围栏状态，避免执行普通空白分隔判断。
- 非代码块空白行先直接 flush，避免再执行行首裁剪和 marker 识别。
- 段落、无序列表、有序列表、待办、代码和小节分组的临时缓冲在 flush 后保留容量，减少长文多块解析时的数组容量 churn。
- `MarkdownBlockParserTests` 增加代码块内空行保留、代码块内 Markdown-like 行不参与小节/列表解析、CR-only 和 CRLF 当前分行行为覆盖。
- GitHub Actions 结果包版本更新为 `v0.60`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.60（Markdown解析循环轻量化）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok`；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.60` 存在；`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 返回 0 且无输出；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读选题复核：确认 `parseDocument(_:)` 没有双重解析，`components(separatedBy: .newlines)` 是剩余较大分配点但本轮不宜直接替换，建议先做循环重排、`removeAll(keepingCapacity: true)` 和 CR/CRLF characterization；本轮已采纳。子 agent staged diff 复核未发现问题。
- 实现 commit：`f3d2ba112840cb36f9859f7978bab1edd51bd165`（`v0.60 优化 Markdown 解析循环`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28854267956`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.60-main-f3d2ba1-run28854267956-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28854267956/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.60`、`branch=main`、`commitSha=f3d2ba112840cb36f9859f7978bab1edd51bd165`、`runId=28854267956`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 `MarkdownBlockParser` 循环顺序和临时缓冲复用，不替换 `.newlines` 分行策略，不改变 CR/CRLF、代码块、列表、`###` 小节、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.59 / Mac 预览切换状态提示

日期：2026-07-07

核心变更：

- `EditorWritingCommand` 新增预览切换标题 helper 和可传入状态标题的 help text helper。
- `EntryEditorView` 的 Mac Catalyst 预览切换 toolbar 按钮使用当前状态标题生成 hover help，并显式设置同名辅助功能标签。
- `MarkdownSnippetTests` 覆盖宽屏/窄屏预览切换标题，以及“隐藏预览”“显示预览”“回到编辑”组合 `⌘⌥P` 的提示文案。
- GitHub Actions 结果包版本更新为 `v0.59`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.59（Mac预览切换状态提示）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok`；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.59` 存在；`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 返回 0 且无输出；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读选题复核：确认 Mac Catalyst 预览切换 toolbar `.help` 仍是静态“显示/隐藏预览（⌘⌥P）”，建议将状态化标题和 help text 抽成纯 helper 并在 `MarkdownSnippetTests` 覆盖；本轮已采纳。子 agent staged diff 复核未发现问题。
- 实现 commit：`2973b04226f3902c2229be68801655fcb2891d45`（`v0.59 优化 Mac 预览切换提示`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28849835949`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.59-main-2973b04-run28849835949-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28849835949/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.59`、`branch=main`、`commitSha=2973b04226f3902c2229be68801655fcb2891d45`、`runId=28849835949`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Mac Catalyst 写作工具栏预览切换按钮的提示和辅助功能标签，不改变菜单通用标题、快捷键、布局、Markdown 规则、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.58 / Mac 专注写作正文输入区宽度优化

日期：2026-07-07

核心变更：

- `EntryEditorView` 在宽屏且右侧预览栏隐藏时，将正文输入区居中并限制最大宽度。
- 保持预览栏可见时的原左右双栏布局，保留窄屏 segmented 编辑/预览行为。
- 保持 Mac Catalyst 写作工具栏、菜单命令、focused scene value、Markdown 片段和缩进入口不变。
- GitHub Actions 结果包版本更新为 `v0.58`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.58（Mac专注写作正文宽度优化）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.58` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核因服务临时不可用中断；本轮未采用其输出，改由主线程完成 diff 复核和云端 artifact 验收。
- 初次实现 commit：`b40cacb918886875faab78326bfdc2c4b4881b27`（`v0.58 优化 Mac 专注写作宽度`），已 push 到 `origin/main`；GitHub Actions run `28848405536`，attempt `1` 失败。Agent C 下载 artifact `mdjournal-ci-v0.58-main-b40cacb-run28848405536-attempt1` 后确认 manifest 中 `buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `failure`，日志显示 `EntryEditorView.swift` 的 SwiftUI result builder 中条件布局后直接接 `.background` 导致构建失败。
- 修复 commit：`9a036fd189fe84dd8466093c9084e99fc5030342`（`v0.58 修复专注写作布局构建`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28848617546`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.58-main-9a036fd-run28848617546-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28848617546/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.58`、`branch=main`、`commitSha=9a036fd189fe84dd8466093c9084e99fc5030342`、`runId=28848617546`、`runAttempt=1` 与本轮修复 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Mac Catalyst 宽屏隐藏预览时的正文输入区宽度，不改变双栏预览、窄屏模式、Markdown 规则、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.57 / Markdown 行缩进正文单次构造

日期：2026-07-07

核心变更：

- `MarkdownLineIndentation` 新增基于原正文索引切片的单次构造 helper，用升序 operation 追加未变片段和 replacement。
- 多行 Tab / Shift-Tab 不再对同一个 `String` 执行多次反向 `replaceSubrange`，减少长多行选区改写时的中间字符串变更成本。
- 保持既有 UTF-16 `selectedRange` 调整逻辑、缩进单位、反缩进规则、尾随空行和 emoji 边界语义。
- `MarkdownLineIndentationTests` 增加 CRLF 选区结束边界和混合多行反缩进单次构造覆盖。
- GitHub Actions 结果包版本更新为 `v0.57`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournalTests/MarkdownLineIndentationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.57（Markdown行缩进单次构造正文）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.57` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：确认单次构造应使用原始 `body` 的升序 operation range，不能混用变更后字符串索引；建议补充 CRLF 和混合反缩进选区测试。本轮按该建议实现并补充对应覆盖。
- 子 agent staged diff 复核：未发现 `String.Index` 复用、`selectedRange` UTF-16 调整、CRLF 选区结束、尾随空行或新增测试期望问题。
- 实现 commit：`db368da0b96bdf33167b822d16534c18d38ccaca`（`v0.57 优化行缩进正文构造`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28846354022`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.57-main-db368da-run28846354022-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28846354022/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.57`、`branch=main`、`commitSha=db368da0b96bdf33167b822d16534c18d38ccaca`、`runId=28846354022`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Markdown 行缩进的正文构造方式，不改变缩进单位、选区更新规则、CR/CRLF 分行语义、Markdown 片段插入、回车续写、预览解析、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.56 / Markdown 行缩进扫描范围收窄

日期：2026-07-07

核心变更：

- `MarkdownLineIndentation` 的行首扫描 helper 新增 effective end UTF-16 offset 上界，只扫描到选区有效结束行。
- 保留 v0.55 的行首 `String.Index` 与 UTF-16 offset 复用设计，继续避免 per-operation 从正文开头重复计算 location。
- 保持既有语义：Tab 插入两个空格；Shift-Tab 删除一个 tab、两个行首空格或一个行首空格；非空选区仍用 `location + length - 1` 判断有效结束；尾随空行和 UTF-16/emoji 光标边界按原规则更新。
- `MarkdownLineIndentationTests` 增加长后续正文靠前光标缩进和尾随空行光标缩进覆盖。
- GitHub Actions 结果包版本更新为 `v0.56`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournalTests/MarkdownLineIndentationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.56（Markdown行缩进扫描范围收窄）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.56` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：确认推荐形态是给行首扫描增加 effective end UTF-16 offset 上界；强调必须保留 `location + length - 1`、尾随空行、UTF-16/emoji 和 CRLF 既有语义。本轮按该建议实现，并补充长后续正文和尾随空行测试。
- 实现 commit：`9391b1c1dbe8feeb711ce79b091c268fbd9ac5dd`（`v0.56 收窄行缩进扫描范围`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28844831867`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.56-main-9391b1c-run28844831867-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28844831867/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.56`、`branch=main`、`commitSha=9391b1c1dbe8feeb711ce79b091c268fbd9ac5dd`、`runId=28844831867`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只收窄 Markdown 行缩进的行首扫描范围，不改变缩进单位、选区更新规则、CR/CRLF 分行语义、Markdown 片段插入、回车续写、预览解析、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.55 / Markdown 行缩进偏移计算优化

日期：2026-07-07

核心变更：

- `MarkdownLineIndentation` 新增行首位置信息结构，在单次扫描中收集每一行的 `String.Index` 和 UTF-16 offset。
- 选区首尾行定位和缩进/反缩进 operation location 复用同一份行首表，避免长多行选区中为每个行首重复从正文开头计算 `NSRange`。
- 保持既有语义：Tab 插入两个空格；Shift-Tab 删除一个 tab、两个行首空格或一个行首空格；选区结束在下一行行首时不处理下一行；UTF-16/emoji 光标和选区边界按原规则更新。
- `MarkdownLineIndentationTests` 增加长多行选区缩进和跨 emoji 行反缩进覆盖。
- GitHub Actions 结果包版本更新为 `v0.55`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournalTests/MarkdownLineIndentationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.55（Markdown行缩进偏移计算优化）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.55` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：确认本轮消除了每个 operation 从正文开头重复计算 UTF-16 location 的热点；建议并已采纳去掉选中行数组复制和两次 operation 排序，并补充非零起点跨 emoji 行选区测试；确认未改变 Tab / Shift-Tab、选区结束边界和 UTF-16 语义。
- 实现 commit：`70de69fad8f86d1d2ed73a80d3062c275e2172cf`（`v0.55 优化行缩进偏移计算`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28843027716`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.55-main-70de69f-run28843027716-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28843027716/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.55`、`branch=main`、`commitSha=70de69fad8f86d1d2ed73a80d3062c275e2172cf`、`runId=28843027716`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Markdown 行缩进的行首 UTF-16 offset 计算，不改变缩进单位、选区更新规则、CR/CRLF 分行语义、Markdown 片段插入、回车续写、预览解析、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.54 / Markdown 工具栏快捷键提示

日期：2026-07-07

核心变更：

- `MarkdownSnippetCommandShortcut` 新增 `displayText`，用于统一展示片段菜单快捷键。
- `MarkdownSnippet` 新增 `helpText`，格式为 `标题（快捷键）`。
- `MarkdownToolbar` 的 hover help 改为使用 `snippet.helpText`，让 Mac Catalyst 下正文 Markdown 图标工具栏提示显示对应 `⌘⌥` 快捷键。
- `MarkdownSnippetTests` 覆盖片段 help text 包含标题和快捷键显示文案，并补充代表性快捷键显示断言。
- GitHub Actions 结果包版本更新为 `v0.54`，同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownSnippet.swift`
- `MDJournal/Utilities/MarkdownSnippetCommandShortcut.swift`
- `MDJournal/Views/MarkdownToolbar.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.54（Markdown工具栏快捷键提示）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.54` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：确认 `MarkdownSnippet.helpText` 与 `MarkdownSnippetCommandShortcut.displayText` 没有循环或访问级别风险；`MarkdownToolbar` 保留 `accessibilityLabel(snippet.title)` 只改 hover help；测试与文档同步未见问题。
- 实现 commit：`063e6e1e97086e6335d893b7463df84c7ce1c2ad`（`v0.54 补齐 Markdown 工具栏提示`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28841844278`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.54-main-063e6e1-run28841844278-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28841844278/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.54`、`branch=main`、`commitSha=063e6e1e97086e6335d893b7463df84c7ce1c2ad`、`runId=28841844278`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只补齐 Markdown 工具栏 hover 提示，不改变 Markdown 片段快捷键映射、菜单命令、插入结果、正文编辑、JSON 持久化、统计口径或 Mac Catalyst 构建方式。

### v0.53 / CI 结果包 JUnit 错误字段与验收记录修正

日期：2026-07-07

核心变更：

- `MD Journal CI Results` workflow 的结果包版本更新为 `v0.53`。
- CI 生成的 `junit.xml` 在 `testsuite` 上显式写入 `errors="0"`，减少 Agent C 机器复判时对缺失字段的默认推断。
- `md/test/test.md` 将 manifest 和 artifact 示例从旧固定版本改为泛化占位，并要求 Agent C 核对 `failures`、`errors` 和 `skipped`。
- 修正 v0.52 记录，区分实现 commit artifact 和最终记录 commit artifact，避免“最新 origin/main”表述在后续记录提交后产生歧义。
- 同步 README、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `.github/workflows/ci-results.yml`
- `md/test/test.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（协作云端化）/v0.53（CI结果包JUnit错误字段与验收记录修正）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.53` 和 `errors="0"` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：发现并修正 v0.52 记录中对旧 JUnit `errors` 字段的表述问题；复核确认 workflow、测试规范、README、flow、flowchart 和 v0.53 提示词未见其他问题。
- 实现 commit：`4bf0e76c8ee088485c8d7729b5af6066e24d9c62`（`v0.53 修正 CI 结果包验收字段`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28841072507`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.53-main-4bf0e76-run28841072507-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28841072507/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.53`、`branch=main`、`commitSha=4bf0e76c8ee088485c8d7729b5af6066e24d9c62`、`runId=28841072507`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显式显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 CI 结果包和验收记录表述，不改变 Swift 业务逻辑、Markdown 解析、正文编辑、JSON 持久化、统计口径或 Mac Catalyst UI 行为。

### v0.52 / Markdown 解析行首裁剪非分配

日期：2026-07-07

核心变更：

- `MarkdownBlockParser` 将行首空格/tab 裁剪 helper 从构造新 `String` 改为返回原行 `Substring` 切片。
- heading、引用、无序列表、有序列表和待办 marker 解析 helper 改为直接消费 `Substring`。
- 保持原有语义：只跳过普通空格和 tab，不改变 `.newlines` 分行、CR/CRLF、段落、代码块、列表、分割线或 `###` 小节分组规则。
- GitHub Actions 结果包版本更新为 `v0.52`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.52（Markdown解析行首裁剪非分配）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.52` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读复核：确认 `MarkdownBlockParser` 行首裁剪改为 `Substring` 后，heading、引用、无序列表、有序列表、待办、代码围栏和分割线 marker 识别未发现明显 Swift 编译或语义风险；文档与代码一致。
- 实现 commit：`9df582dceaf02563f214413b3fd6c86a68fc4502`（`v0.52 优化解析行首裁剪`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28840203924`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.52-main-9df582d-run28840203924-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28840203924/` 复判。
- Agent C 对实现 commit 的复判结果：`ci-artifact-manifest.json` 中 `version=v0.52`、`branch=main`、`commitSha=9df582dceaf02563f214413b3fd6c86a68fc4502`、`runId=28840203924`、`runAttempt=1` 与本轮实现 commit 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`，`errors` 按缺失字段默认 0 复判；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。
- 最终记录 commit：`6abbdb8f03630e70277cd7f1f90c1f6e79da1cd0`（`v0.52 记录云端验收结果`），已 push 到 `origin/main`。
- Agent C 对最终记录 commit 的复判结果：GitHub Actions run `28840526850`，attempt `1`，artifact `mdjournal-ci-v0.52-main-6abbdb8-run28840526850-attempt1`；manifest 中 `branch=main`、`commitSha=6abbdb8f03630e70277cd7f1f90c1f6e79da1cd0`、`runId=28840526850`、`runAttempt=1` 与最终 `origin/main` 完全一致，四个 outcome 均为 `success`，JUnit 失败和错误均为 0，三个 `.xcresult/Info.plist` 均可解析。

遗留事项：

- 本轮只优化 Markdown 解析行首 marker 判断的中间分配，不改变整篇分行策略、CR/CRLF 归一化、块级 Markdown 解析结果、Markdown 预览渲染、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.51 / Markdown 解析空行判断非分配

日期：2026-07-07

核心变更：

- `MarkdownBlockParser` 将普通块解析中的空行判断从 `trimmingCharacters(in: .whitespaces).isEmpty` 改为直接扫描 `unicodeScalars` 的 `CharacterSet.whitespaces`。
- 保持原有语义：空字符串、普通空格、tab 和 `.whitespaces` 覆盖的水平空白行仍作为空白分隔；代码块内水平空白行继续作为 code 内容保留。
- `MarkdownBlockParserTests` 扩展覆盖水平空白行分隔段落和 fenced code block 内水平空白行保留。
- GitHub Actions 结果包版本更新为 `v0.51`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.51（Markdown解析空行判断非分配）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.51` 存在；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读调查：确认 `MarkdownBlockParser` 是长正文预览性能优化合适方向，并指出 CR/CRLF 分行语义是后续若重写整套分行策略时的关键风险；本轮未改文件，未运行本机构建或测试。
- 实现 commit：`c91628990da0299bd7bf35b31a38e5e420ea7d27`（`v0.51 优化解析空行判断`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28839245541`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.51-main-c916289-run28839245541-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28839245541/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.51`、`branch=main`、`commitSha=c91628990da0299bd7bf35b31a38e5e420ea7d27`、`runId=28839245541`、`runAttempt=1` 与最新 `origin/main` 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Markdown 解析空行判断的中间分配，不改变分行策略、标题/引用/列表/待办/代码块/分割线解析、`###` 小节分组、Markdown 预览渲染、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.50 / Markdown 选区片段转换单次扫描

日期：2026-07-06

核心变更：

- `MarkdownSnippetInsertion` 将引用、无序列表、待办和有序列表的多行选区转换从 `components(separatedBy: "\n")` + `map` + `joined` 改为按 LF 单次扫描并增量构造 replacement。
- 保持原有语义：只按 LF 分行，CR 保留为行内容参与 `.whitespacesAndNewlines` 空白判断和输出；尾随 LF 不生成额外空项；有序列表只给非空行从 `1. ` 开始连续编号；替换后选区仍覆盖 replacement 全文。
- 追加修复 CRLF 片段扫描边界：逐 unicode scalar 累积当前行，避免按 `Character` 遍历时 CRLF 被合并为单个换行字符而丢失 `\r`。
- `MarkdownSnippetTests` 扩展覆盖 CRLF、CR-only 空白行、尾随换行、emoji/UTF-16 选区长度和有序编号跳过空白行边界。
- GitHub Actions 结果包版本更新为 `v0.50`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownSnippetInsertion.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.50（Markdown选区片段转换单次扫描）.md`
- `update_log.md`

验证结果：

- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.50` 存在。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 未能运行：当前环境没有 `xcrun`，且 `swiftc` 不在 PATH。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 未能运行：当前环境没有 `ruby`。
- 本机 XCTest 未能运行：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` 不存在。
- 初始实现 commit：`d46ce4b7de0cbbb4c76da21dcb1e259635e4ecfb`（`v0.50 优化选区片段转换`），已 push 到 `origin/main`；对应 GitHub Actions run `28813704522`，attempt `1`，结论 `failure`，未作为通过版本验收。
- 追加修复 commit：`0086ab1f5d491a7149aa7d9111b3e39f09569c04`（`Fix CRLF snippet line scanning`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28831907520`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.50-main-0086ab1-run28831907520-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28831907520/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.50`、`branch=main`、`commitSha=0086ab1f5d491a7149aa7d9111b3e39f09569c04`、`runId=28831907520`、`runAttempt=1` 与最新 `origin/main` 完全一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化 Markdown 选区逐行片段转换的中间分配，不改变空选区插入、加粗/斜体/代码包裹、Mac Catalyst 命令路由、Markdown 预览、JSON 持久化、统计口径或回车续写规则。

### v0.49 / Markdown 回车空项退出非分配判断

日期：2026-07-06

核心变更：

- `MarkdownLineContinuation` 将空项退出判断从 `Substring` 转 `String` 后 `trimmingCharacters(in: .whitespaces)` 改为直接扫描 `Substring` 的 `.whitespaces` 水平空白。
- 保持原有语义：空格、tab 和 `CharacterSet.whitespaces` 覆盖的水平空白视为空内容；不扩大到换行，也不改变非空项续写、行中拆分、有序列表编号递增或 fenced code 内默认输入行为。
- `MarkdownLineContinuationTests` 扩展覆盖空格 + tab 空项退出、光标后仅水平空白仍退出，以及光标前或光标后存在正文时继续拆分续写的边界。
- GitHub Actions 结果包版本更新为 `v0.49`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineContinuation.swift`
- `MDJournalTests/MarkdownLineContinuationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.49（Markdown回车空项退出非分配判断）.md`
- `update_log.md`

验证结果：

- 本地轻量检查：`git diff --check` 返回 0 且无输出；`python3` 有限检查确认 `.github/workflows/ci-results.yml` 中 `VERSION: v0.49` 存在。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 未能运行：当前环境没有 `xcrun`。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 未能运行：当前环境没有 `ruby`；`python3` 环境也没有 PyYAML，未做等价 YAML 解析。
- 本机 XCTest 未能运行：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` 不存在。
- 实现 commit：`e45532d95108645558b3a0992a47d02e7ac708b3`（`v0.49 优化回车空项退出判断`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28811743827`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.49-main-e45532d-run28811743827-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28811743827/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.49`、`branch=main`、`commitSha=e45532d95108645558b3a0992a47d02e7ac708b3`、`runId=28811743827`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`；`ci-failure-summary.md` 确认所有配置的 CI 阶段通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 可用 `python3 plistlib` 解析。

遗留事项：

- 本轮只优化回车续写空项退出判断的中间分配，不改变回车续写、空项退出外部结果、fenced code、Tab / Shift-Tab 缩进、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.48 / Markdown 回车续写代码围栏判断单次扫描

日期：2026-07-07

核心变更：

- `MarkdownLineContinuation` 将光标前 fenced code block 状态判断从 `split` + 逐行 `String` + trim 改为单次索引扫描。
- 保持原有语义：只扫描当前行之前内容，行首跳过 `.whitespaces` 后以 ``` 开头才切换 fenced 状态，非行首 ``` 不切换，代码围栏内回车不自动续写列表/引用/有序列表。
- `MarkdownLineContinuationTests` 扩展覆盖闭合围栏后恢复续写、缩进围栏内不续写、非行首围栏文本不切换、奇数围栏数量禁用续写等边界。
- GitHub Actions 结果包版本更新为 `v0.48`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineContinuation.swift`
- `MDJournalTests/MarkdownLineContinuationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.48（Markdown回车续写代码围栏判断单次扫描）.md`
- `update_log.md`

验证结果：

- 实现 commit：`1c8e8d4de9f290afacefed07ec1dd45c2e3fe37c`（`v0.48 优化回车续写围栏判断`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28809539431`，attempt `1`，结论 `success`。
- 本轮恢复工作时最新 `origin/main` 已推进到 `0086ab1f5d491a7149aa7d9111b3e39f09569c04`；按 Agent C 只验收最新 `origin/main` 的规则，未再下载旧 v0.48 artifact 单独冒充最终验收。v0.48 代码已包含在最新 v0.50 主线 artifact `mdjournal-ci-v0.50-main-0086ab1-run28831907520-attempt1` 的累计构建、Mac Catalyst 构建和 XCTest 复判中。

遗留事项：

- 本轮只优化回车续写前的 fenced code 状态判断，不改变列表/待办/引用/有序列表续写、空项退出、UTF-16 光标、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.47 / Markdown 预览纯文本内联快路径

日期：2026-07-07

核心变更：

- `MarkdownPreviewView` 新增纯文本内联快路径：文本片段没有 Markdown 触发字符时直接构造 `AttributedString(text)`。
- 包含加粗、斜体、代码、链接、图片、自动链接、HTML 实体、转义、删除线或表格等可能触发字符时，继续走既有 `AttributedString(markdown:)` 解析和 fallback。
- `MarkdownBlockParserTests` 扩展覆盖普通中英文纯文本跳过 Markdown 解析，以及保守触发字符仍保留 Markdown 解析路径。
- GitHub Actions 结果包版本更新为 `v0.47`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.47（Markdown预览纯文本内联快路径）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读检查：建议围绕 Mac Catalyst 宽屏实时预览中的 `AttributedString(markdown:)` 调用增加纯文本快路径；未改文件，未运行本地构建、XCTest、模拟器、GUI 或 gh auth。
- 实现 commit：`8152cd36bbd4729012e2cf15cab848d1e4140333`（`v0.47 优化预览内联渲染`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28808026780`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.47-main-8152cd3-run28808026780-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28808026780/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.47`、`branch=main`、`commitSha=8152cd36bbd4729012e2cf15cab848d1e4140333`、`runId=28808026780`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化 Markdown 预览内联文本渲染的纯文本分支，不改变块级 Markdown 解析、`###` 小节分组、正文编辑、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.46 / 正文词数统计单次扫描

日期：2026-07-07

核心变更：

- `JournalEntryBodyMetrics` 将正文词数统计从 `split` 计数改为单次字符扫描，避免为词数统计创建 `Substring` 片段集合。
- 保持原有空白分隔语义不变：连续空白、首尾空白、换行和 tab 不产生空词，中文和英文按空白边界计数。
- `JournalEntryTests` 扩展覆盖空正文、全空白、连续空白、换行、tab、中文英文混排和 Markdown 标记文本的词数计数边界。
- GitHub Actions 结果包版本更新为 `v0.46`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.46（正文词数统计单次扫描）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读检查：确认 `JournalEntryBodyMetrics.wordCount(in:)` 用同一空白分隔条件单次扫描，语义等价于原 `split { $0.isWhitespace || $0.isNewline }.count`；其只读运行的 `git diff --check` 和 Swift 样例等价检查通过。
- 实现 commit：`55dc83176f5ab7929ac875b76bd0913debadc967`（`v0.46 优化正文词数统计`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28806539503`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.46-main-55dc831-run28806539503-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28806539503/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.46`、`branch=main`、`commitSha=55dc83176f5ab7929ac875b76bd0913debadc967`、`runId=28806539503`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化非持久化正文词数统计的中间分配，不改变 `###` 小节识别、摘要清理、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.45 / 正文字体配置写入去重

日期：2026-07-06

核心变更：

- `MarkdownBodyTextView` 新增 `configureBodyFontIfNeeded(_:)`，集中配置正文 `UITextView` 的 rounded body 字体。
- `makeUIView` 和 `updateUIView` 共用正文字体配置 helper；`updateUIView` 单次刷新只构造一次目标字体，并且仅在当前字体不匹配时写入。
- `MarkdownTextInputConfigurationTests` 扩展覆盖正文字体会配置为当前 preferred rounded body font，以及当前字体已匹配时不会替换已有 font 对象。
- GitHub Actions 结果包版本更新为 `v0.45`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownTextInputConfigurationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.45（正文字体配置写入去重）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 子 agent 只读检查：确认正文字体配置去重对 Dynamic Type、`UIFont` equality、`UITextView.font` 更新和 Mac Catalyst 没有明显行为风险；其只读运行的 `git diff --check` 和 Swift parse 均通过。
- 实现 commit：`ddc50cc461129f60afc8729682ec63d7266c85e3`（`v0.45 优化正文字体配置写入`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28804748380`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.45-main-ddc50cc-run28804748380-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28804748380/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.45`、`branch=main`、`commitSha=ddc50cc461129f60afc8729682ec63d7266c85e3`、`runId=28804748380`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化正文 `UITextView` 字体配置的重复目标字体构造和无效写入，不改变 Dynamic Type、输入规则、编辑器布局、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.44 / 正文输入 Traits 去重配置

日期：2026-07-06

核心变更：

- `MarkdownBodyTextView.configureMarkdownInputTraits(_:)` 改为按需写入智能引号、智能破折号和智能插入删除配置，只有当前值不是 `.no` 时才重新设置。
- 保持 Markdown 正文输入禁用系统自动替换的语义不变；如果输入 traits 被系统或外部状态重置，重复调用仍会恢复到 `.no`。
- 复用既有 `MarkdownTextInputConfigurationTests` 覆盖初次配置和被重置后的再次配置。
- GitHub Actions 结果包版本更新为 `v0.44`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownTextInputConfigurationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.44（正文输入Traits去重配置）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`f9f96dc7eaf0bac68c0c0a43cd46e86c176323e9`（`v0.44 优化正文输入配置写入`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28803054608`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.44-main-f9f96dc-run28803054608-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28803054608/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.44`、`branch=main`、`commitSha=f9f96dc7eaf0bac68c0c0a43cd46e86c176323e9`、`runId=28803054608`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化正文输入 traits 的重复 UIKit 属性写入，不改变输入规则、编辑器布局、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.43 / 正文桥接状态写回去重

日期：2026-07-06

核心变更：

- `MarkdownBodyTextView.Coordinator` 新增正文、选区和焦点去重写回 helper，只在 binding 值真实变化时同步 SwiftUI 状态。
- Markdown 回车续写、Tab / Shift-Tab 行缩进、普通输入变化、选区变化和焦点变化统一复用去重写回，减少长文写作时的无效 SwiftUI 刷新。
- 保持正文内容、光标/选区、焦点、IME marked text、Markdown 续写、缩进、JSON 持久化和 Mac Catalyst 写作入口语义不变。
- GitHub Actions 结果包版本更新为 `v0.43`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.43（正文桥接状态写回去重）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`08e815e434b308d68983c88049bfc09df09f7223`（`v0.43 优化正文桥接状态写回`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28799728584`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.43-main-08e815e-run28799728584-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28799728584/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.43`、`branch=main`、`commitSha=08e815e434b308d68983c88049bfc09df09f7223`、`runId=28799728584`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化正文 UIKit bridge 的重复状态写回，不改变输入规则、编辑器布局、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.42 / 摘要 Markdown 清理单次扫描

日期：2026-07-06

核心变更：

- `JournalEntryBodySummary` 和 `JournalSection.excerpt` 共用 `MarkdownSummaryText` 单次扫描清理轻量 Markdown 标记，减少摘要派生中的连续全量字符串替换和 `split.map(String).joined` 中间分配。
- 保持正文摘要清理 `#`、`*`、反引号、引用符和空行处理语义不变；小节摘要继续额外清理待办标记和列表连字符。
- `JournalEntryTests` 扩展覆盖正文摘要 Markdown 标记清理、空行处理、小节待办标记和普通项目清理语义。
- GitHub Actions 结果包版本更新为 `v0.42`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.42（摘要Markdown清理单次扫描）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 初始实现 commit：`cacc0f1f613e099b7262a1c04f22dee051bbe790`（`v0.42 优化摘要清理性能`），已 push 到 `origin/main`；GitHub Actions run `28795780828`，attempt `1` 失败。Agent X 下载未加密 artifact `mdjournal-ci-v0.42-main-cacc0f1-run28795780828-attempt1` 到 `/private/tmp/mdjournal-c-review-28795780828/` 复判，manifest 匹配本轮 commit，静态检查、generic iOS build 和 Mac Catalyst build 通过，但 XCTest 中两个新增摘要清理测试失败；失败原因是测试期望压缩了 Markdown 标记清理后留下的空格，扩大了本轮“不改变既有摘要语义”的范围。
- 追加修复 commit：`4b9db89cb04ce59a21aed0d2bf01e20c64a95c17`（`v0.42 修正摘要清理测试期望`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28796511571`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.42-main-4b9db89-run28796511571-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28796511571/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.42`、`branch=main`、`commitSha=4b9db89cb04ce59a21aed0d2bf01e20c64a95c17`、`runId=28796511571`、`runAttempt=1` 与本轮追加修复 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化正文和小节摘要的 Markdown 标记清理成本，不改变正文内容、`###` 小节识别、Markdown 预览、JSON 持久化、统计口径或 Mac Catalyst 菜单行为。

### v0.41 / Mac 写作工具栏快捷键提示

日期：2026-07-06

核心变更：

- `EditorWritingCommandShortcut` 新增桌面可读快捷键展示文案，`EditorWritingCommand` 统一派生写作命令 help 文案。
- Mac Catalyst 写作工具栏的聚焦正文、专注写作、增加缩进、减少缩进和显示/隐藏预览 hover 提示改为显示命令标题和对应 `⌘⌥` 快捷键。
- `MarkdownSnippetTests` 扩展覆盖写作命令 help 文案包含标题和快捷键展示，避免工具栏提示与菜单快捷键脱节。
- GitHub Actions 结果包版本更新为 `v0.41`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.41（Mac写作工具栏快捷键提示）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`4037711607e7fee8d09e87812549dffc26186922`（`v0.41 打磨 Mac 工具栏提示`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28794066380`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.41-main-4037711-run28794066380-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28794066380/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.41`、`branch=main`、`commitSha=4037711607e7fee8d09e87812549dffc26186922`、`runId=28794066380`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只打磨 Mac Catalyst 写作工具栏 hover 提示，不新增命令、不修改快捷键、不改变 Markdown 插入、缩进、预览、JSON 持久化或统计口径。

### v0.40 / 统计排序按需执行

日期：2026-07-06

核心变更：

- `JournalStatistics` 初始化时先线性检查输入是否已经按 `createdAt` 倒序；常见的 `JournalStore.entries` 主路径直接复用输入数组，不再每次统计看板渲染都执行无条件排序。
- 输入乱序时仍回退到原有 `createdAt` 倒序排序，保持统计看板外部行为和 `latestEntryDate` 语义不变。
- `JournalStatisticsTests` 新增乱序输入排序回退用例，覆盖 fallback 行为。
- GitHub Actions 结果包版本更新为 `v0.40`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.40（统计排序按需执行）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`cae7dc9f1dacd4d68c7b2c39dbd1975678b3e5da`（`v0.40 优化统计排序成本`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28792321686`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.40-main-cae7dc9-run28792321686-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28792321686/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.40`、`branch=main`、`commitSha=cae7dc9f1dacd4d68c7b2c39dbd1975678b3e5da`、`runId=28792321686`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化统计看板输入排序成本，不改变 `JournalStore` 排序规则、统计口径、JSON 持久化、Markdown 解析、编辑器、列表或 Mac Catalyst 菜单行为。

### v0.39 / Markdown 预览分组判断复用

日期：2026-07-06

核心变更：

- `MarkdownPreviewView` 在单次 `body` 渲染中将 `document.shouldUseSectionGroups` 缓存为局部 `shouldUseSectionGroups`，同时用于 `LazyVStack` spacing 和普通/小节分组渲染分支。
- 保持空内容提示、`###` 小节分组条件、普通块渲染、小节卡片、列表项和预览间距数值不变。
- GitHub Actions 结果包版本更新为 `v0.39`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownPreviewView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.39（预览分组判断复用）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`9d2fbe92dc28fe0e10c604e9878cdb93817ae41f`（`v0.39 复用预览分组判断`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28789775090`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.39-main-9d2fbe9-run28789775090-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28789775090/` 复判。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.39`、`branch=main`、`commitSha=9d2fbe92dc28fe0e10c604e9878cdb93817ae41f`、`runId=28789775090`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`errors=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只复用 Markdown 预览同一解析结果上的分组布尔判断，不改变 Markdown 解析、`###` 小节识别、列表编号、正文编辑、JSON 持久化或统计口径。

### v0.38 / 编辑器占位非分配判断

日期：2026-07-06

核心变更：

- `EntryEditorView` 的正文 placeholder 判断从 `trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` 改为非分配字符扫描，长文输入重渲染时不再为占位条件创建临时 trimmed 字符串。
- 保持空字符串和全空白/换行正文显示 placeholder、包含任意非空白字符时隐藏 placeholder 的原有语义。
- GitHub Actions 结果包版本更新为 `v0.38`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.38（编辑器占位非分配判断）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 初始实现 commit：`689ee14a2ba6068fe0774fc8968a79b0d48af45d`（`v0.38 优化编辑器占位判断`），已 push 到 `origin/main`；GitHub Actions run `28787687406`，attempt `1` 失败。Agent X 下载未加密 artifact `mdjournal-ci-v0.38-main-689ee14-run28787687406-attempt1` 到 `/private/tmp/mdjournal-c-review-28787687406/` 复判，manifest 匹配本轮 commit，静态检查通过，但 iOS build、Mac Catalyst build 和 XCTest 均因 `EntryEditorView.bodyContainsVisibleContent` 内 `body` 被解析为 SwiftUI `View.body` 而编译失败。
- 追加修复 commit：`be26339e28348c0ac253545c206d76674e6ea6e1`（`v0.38 修复占位判断编译`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28788098149`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.38-main-be26339-run28788098149-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28788098149/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.38`、`branch=main`、`commitSha=be26339e28348c0ac253545c206d76674e6ea6e1`、`runId=28788098149`、`runAttempt=1` 与本轮修复 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化编辑器正文 placeholder 展示条件，不改变正文内容、光标/选区同步、Markdown 输入规则、JSON 持久化、预览或统计口径。

### v0.37 / Markdown 预览索引迭代

日期：2026-07-06

核心变更：

- `MarkdownPreviewView` 的普通块、小节内块、无序列表、有序列表和待办列表 `ForEach` 从 `Array(...enumerated())` 改为基于 `indices` 的索引迭代，减少实时预览重渲染时的临时数组分配。
- 保持 offset 身份语义、空内容提示、`###` 小节分组、有序列表用户输入编号、待办勾选样式和所有预览 UI 行为不变。
- GitHub Actions 结果包版本更新为 `v0.37`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/MarkdownPreviewView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.37（预览索引迭代）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`ca05f4a32eebadd1711c08b87ea61ee390aee773`（`v0.37 优化预览索引迭代`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28783079489`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.37-main-ca05f4a-run28783079489-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28783079489/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.37`、`branch=main`、`commitSha=ca05f4a32eebadd1711c08b87ea61ee390aee773`、`runId=28783079489`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化 Markdown 预览 SwiftUI `ForEach` 数据源，不改变 Markdown 解析、`###` 小节识别、正文编辑、写作命令、JSON 持久化或统计口径。

### v0.36 / 小节概览懒加载

日期：2026-07-06

核心变更：

- `JournalSectionOverview` 的横向 `###` 小节列表从 `HStack` 改为 `LazyHStack`，多小节长文输入时不再 eager 构建全部离屏小节卡片。
- 保持 `ForEach(sections)`、卡片样式、标题、excerpt、宽度和横向滚动行为不变。
- GitHub Actions 结果包版本更新为 `v0.36`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.36（小节概览懒加载）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`275fd74dd0f83f16f716408c90e6fd7f80901df8`（`v0.36 懒加载小节概览`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28780313152`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.36-main-275fd74-run28780313152-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28780313152/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.36`、`branch=main`、`commitSha=275fd74dd0f83f16f716408c90e6fd7f80901df8`、`runId=28780313152`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `EntryEditorView.swift` 已编译；`JournalEntryTests` 中 summary / metrics 和 `###` 小节用例通过，`MarkdownSnippetTests` 也通过，说明本轮没有破坏正文派生和写作入口契约。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只替换编辑器头部小节概览的 SwiftUI 横向容器，不改变正文 metrics、`###` 小节识别、excerpt 清理、Markdown 预览、写作命令、JSON 持久化或统计口径。

### v0.35 / Mac 专注写作命令

日期：2026-07-06

核心变更：

- `EditorWritingCommand` 新增“专注写作”命令，快捷键为 `⌘⌥W`，不映射缩进方向。
- `MDJournalApp` 新增专注写作 focused scene value，并把 Mac Catalyst “写作”菜单路由到当前编辑器。
- `EntryEditorView` 新增专注写作动作和工具栏按钮；触发后切回编辑并聚焦正文，宽屏下同时隐藏右侧预览栏，让长文输入获得更宽空间并减少实时预览栏解析渲染。
- `MarkdownSnippetTests` 扩展覆盖写作命令顺序、快捷键唯一性、`⌘⌥W` 映射和专注写作无缩进方向。
- GitHub Actions 结果包版本更新为 `v0.35`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournal/MDJournalApp.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.35（Mac专注写作命令）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`41b6a3cc5a9f6914adac9fca2b7f3ade0f52a1ce`（`v0.35 增加 Mac 专注写作命令`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28778923235`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.35-main-41b6a3c-run28778923235-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28778923235/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.35`、`branch=main`、`commitSha=41b6a3cc5a9f6914adac9fca2b7f3ade0f52a1ce`、`runId=28778923235`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownSnippetTests` 已编译并执行，`testEditorWritingCommandsHaveVisibleMetadata`、`testEditorWritingCommandShortcutsDoNotCollideWithSnippetShortcuts` 和 `testEditorWritingIndentationCommandsExposeDirections` 用例通过，专注写作命令顺序、快捷键和缩进方向契约已覆盖。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只新增 Mac Catalyst 专注写作入口，不新增独立 native macOS target，不改变 Markdown 解析、写作片段、行缩进、JSON 持久化或统计口径。

### v0.34 / 编辑器头部轻量 metrics

日期：2026-07-06

核心变更：

- `EntryEditorView` 头部从 `entry.bodySummary` 改为 `entry.bodyMetrics`，词数和 `###` 小节概览不再为未展示的正文摘要生成 excerpt。
- `header` 和 `statPills` 改为消费 `JournalEntryBodyMetrics`，`JournalSectionOverview` 继续消费同一组 `sections`，展示行为不变。
- GitHub Actions 结果包版本更新为 `v0.34`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.34（编辑器头部轻量metrics）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`d448b99e090890b2f7ab5ec15930ffc74cedd96c`（`v0.34 优化编辑器头部派生`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28776199892`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.34-main-d448b99-run28776199892-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28776199892/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.34`、`branch=main`、`commitSha=d448b99e090890b2f7ab5ec15930ffc74cedd96c`、`runId=28776199892`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalEntryTests` 已编译并执行，`testBodySummaryMatchesCurrentDerivedTextMetricsAndSections` 和 `testEntryDerivedPropertiesDelegateToBodySummary` 用例通过，summary / metrics 一致性仍成立。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只优化编辑器头部正文派生成本，不改变正文摘要、词数 split、`###` 小节识别、列表卡片摘要、Markdown 预览、持久化或写作菜单行为。

### v0.33 / 统计主导项预计算

日期：2026-07-06

核心变更：

- `JournalStatistics` 将主导分类和主导心情改为初始化阶段预计算的存储属性，避免 `insightText` 和统计看板写作节奏区域读取时重复扫描分类/心情分布数组。
- 主导分类继续保持原有 tie-break：先比较篇数，篇数相同再比较词数，完全平局时保持 `JournalEntry.Category.allCases` 较早项优先。
- 主导心情继续保持原有 tie-break：先比较篇数，篇数相同时保持 `JournalEntry.Mood.allCases` 较早项优先。
- `JournalStatisticsTests` 扩展覆盖空状态主导项为 `nil`、分类词数 tie-break、分类完全平局 allCases 顺序和心情平局 allCases 顺序。
- GitHub Actions 结果包版本更新为 `v0.33`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.33（统计主导项预计算）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 初始实现 commit：`19592ed4493f218685c6d41fed698c1fcb2977e1`（`v0.33 预计算统计主导项`），已 push 到 `origin/main`；GitHub Actions run `28772432279`，attempt `1` 失败。Agent X 下载未加密 artifact `mdjournal-ci-v0.33-main-19592ed-run28772432279-attempt1` 到 `/private/tmp/mdjournal-c-review-28772432279/` 复判，manifest 匹配本轮 commit，iOS build 和 Mac Catalyst build 通过，但 `JournalStatisticsTests.swift` 新增测试数组中的 throwing helper 调用缺少 `try`，导致 XCTest 编译失败。
- 追加修复 commit：`e8b25753c1b032c3157cf25f81ba89395121cbe1`（`v0.33 修复统计测试编译`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28773236403`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.33-main-e8b2575-run28773236403-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28773236403/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.33`、`branch=main`、`commitSha=e8b25753c1b032c3157cf25f81ba89395121cbe1`、`runId=28773236403`、`runAttempt=1` 与本轮修复 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalStatisticsTests` 已编译并执行，`testDominantCategoryUsesWordCountTieBreak`、`testDominantCategoryKeepsAllCasesOrderWhenCountsAndWordsTie`、`testDominantMoodKeepsAllCasesOrderWhenCountsTie`、`testEmptyStatisticsUseZeroValues` 和 `testStatisticsAreDeterministicWithFixedCalendarAndNow` 用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- 日志中仍有 Xcode 16.4 的 AppIntents metadata extraction warning，以及 XCTest 成功后模拟器启动 app 的错误片段；manifest outcome、JUnit、failure summary 和 `** TEST SUCCEEDED **` 均确认它们未导致本轮失败。
- Agent C 独立复判结果：确认当前 `HEAD` 与 `origin/main` 均为 `e8b25753c1b032c3157cf25f81ba89395121cbe1`；artifact `mdjournal-ci-v0.33-main-e8b2575-run28773236403-attempt1` 的 manifest、JUnit、iOS build、Mac Catalyst build、XCTest 日志和三个 `.xcresult/Info.plist` 均核对通过；未执行 `gh auth login`，未改变 GitHub CLI 配置。

遗留事项：

- 本轮只处理统计看板主导分类/心情预计算，不改变统计 UI、分类/心情枚举、JSON 持久化、Markdown 或写作菜单行为。

### v0.32 / Mac 写作缩进菜单工具栏入口

日期：2026-07-06

核心变更：

- `EditorWritingCommand` 新增“增加缩进”和“减少缩进”，并为写作菜单提供 `⌘⌥]` / `⌘⌥[` 快捷键。
- `MarkdownLineIndentation.Direction` 显式声明 `Equatable`，便于写作命令测试直接断言缩进方向映射。
- `MDJournalApp` 新增 focused scene value，把 Mac Catalyst “写作”菜单的缩进命令路由到当前编辑器。
- `EntryEditorView` 在 Mac Catalyst 写作工具栏新增增加缩进和减少缩进按钮，并复用 `MarkdownLineIndentation` 更新当前正文和 UTF-16 选区。
- `MarkdownSnippetTests` 扩展覆盖写作命令顺序、元数据、快捷键冲突和缩进方向映射。
- GitHub Actions 结果包版本更新为 `v0.32`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournal/MDJournalApp.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.32（Mac写作缩进菜单工具栏入口）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`03c1ff62694fb2af5dc381000b9a3c2c809dd36d`（`v0.32 增加 Mac 写作缩进入口`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28770314039`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.32-main-03c1ff6-run28770314039-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28770314039/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.32`、`branch=main`、`commitSha=03c1ff62694fb2af5dc381000b9a3c2c809dd36d`、`runId=28770314039`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownSnippetTests` 已编译并执行，`testEditorWritingCommandsHaveVisibleMetadata`、`testEditorWritingIndentationCommandsExposeDirections` 和 `testEditorWritingCommandShortcutsDoNotCollideWithSnippetShortcuts` 用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- Agent C 独立复判结果：确认 artifact `mdjournal-ci-v0.32-main-03c1ff6-run28770314039-attempt1` 的 manifest、JUnit、iOS build、Mac Catalyst build、XCTest 日志和三个 `.xcresult/Info.plist` 均核对通过；未执行 `gh auth login`，未改变 GitHub CLI 配置。

遗留事项：

- 本轮只新增 Mac Catalyst 可见缩进/反缩进入口，不修改缩进算法、Tab / Shift-Tab 键盘捕获、Markdown 预览、片段插入或持久化行为。

### v0.31 / Markdown 单空格反缩进规则

日期：2026-07-06

核心变更：

- `MarkdownLineIndentation` 的 Shift-Tab 反缩进现在会删除一个 tab 或最多两个行首空格；只有一个行首空格时也能反缩进。
- 多行选区中，一个空格、两个空格和 tab 开头的行会分别按行反缩进，无缩进行保持不变。
- `MarkdownLineIndentationTests` 扩展覆盖单空格反缩进和混合空白多行选区。
- GitHub Actions 结果包版本更新为 `v0.31`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本轮 Agent A 提示词。

关键文件：

- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournalTests/MarkdownLineIndentationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.31（Markdown单空格反缩进规则）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`a00838d0577bce1e88cfd1385d63b1f0c0973027`（`v0.31 支持单空格反缩进`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28768736714`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.31-main-a00838d-run28768736714-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28768736714/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.31`、`branch=main`、`commitSha=a00838d0577bce1e88cfd1385d63b1f0c0973027`、`runId=28768736714`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownLineIndentationTests` 已编译并执行，新增 `testShiftTabOutdentsOneLeadingSpace` 和 `testShiftTabOutdentsSelectedMixedWhitespaceLines` 用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- Agent C 独立复判结果：确认 artifact `mdjournal-ci-v0.31-main-a00838d-run28768736714-attempt1` 的 manifest、JUnit、iOS build、Mac Catalyst build、XCTest 日志和三个 `.xcresult/Info.plist` 均核对通过；未执行 `gh auth login`，未改变 GitHub CLI 配置。

遗留事项：

- 本轮只修正 Shift-Tab 单空格反缩进边界，不新增菜单、工具栏、快捷键或 UI 行为。

### v0.30 / Markdown 选区片段跳过空白行

日期：2026-07-06

核心变更：

- `MarkdownSnippetInsertion` 的引用、无序列表、待办和有序列表选区逐行转换会跳过空白行，减少段落间隔被转换成空 Markdown 标记。
- 有序列表只对非空白行连续编号，空白行保持为空行，尾随换行仍不产生额外项目。
- `MarkdownSnippetTests` 扩展覆盖选区空白行跳过、有序列表连续编号和只含空白行的选区不生成标记。
- GitHub Actions 结果包版本更新为 `v0.30`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图、本轮 Agent A 提示词和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownSnippetInsertion.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.30（Markdown选区片段跳过空白行）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`590b63e65dba7d4b2b3521d62fbedd4680a9ba8d`（`v0.30 跳过选区片段空白行`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28767449900`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.30-main-590b63e-run28767449900-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28767449900/` 复判，目录大小约 `1.4M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.30`、`branch=main`、`commitSha=590b63e65dba7d4b2b3521d62fbedd4680a9ba8d`、`runId=28767449900`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownSnippetTests` 已编译并执行，新增 `testSnippetInsertionSkipsBlankLinesWhenPrefixingSelectedLines`、`testSnippetInsertionSkipsBlankLinesWhenNumberingSelectedLines` 和 `testSnippetInsertionLeavesBlankOnlySelectionsUnmarked` 用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- Agent C 独立复判结果：确认当前 `HEAD` 与 `origin/main` 均为 `590b63e65dba7d4b2b3521d62fbedd4680a9ba8d`；artifact `mdjournal-ci-v0.30-main-590b63e-run28767449900-attempt1` 的 manifest、JUnit、iOS build、Mac Catalyst build、XCTest 日志和三个 `.xcresult/Info.plist` 均核对通过；未执行 `gh auth login`，未改变 GitHub CLI 配置。

遗留事项：

- 本轮只优化选区逐行片段插入的空白行处理，不改变空选区插入、代码块包裹、回车续写、Tab 缩进、Markdown 预览或持久化行为。

### v0.29 / 正文统计轻量 metrics 拆分

日期：2026-07-06

核心变更：

- 新增非持久化 `JournalEntryBodyMetrics`，只派生词数、`###` 小节和小节数。
- `JournalEntryBodySummary` 继续负责正文摘要，并复用 `JournalEntryBodyMetrics` 提供 metrics，避免词数和小节规则重复实现。
- `JournalStatistics` 和 `JournalListOverviewSnapshot` 改用 `entry.bodyMetrics`，统计和列表概览路径不再生成 excerpt。
- `JournalEntryTests` 扩展覆盖 body metrics 与 body summary metrics 的一致性。
- GitHub Actions 结果包版本更新为 `v0.29`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图、本轮 Agent A 提示词和本日志。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournal/Utilities/JournalListOverviewSnapshot.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.29（正文统计轻量metrics拆分）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0；staged 后 `git diff --cached --check` 返回 0 且无输出。
- 实现 commit：`5d36ea3cb24ffc2a7b6e2d4427af967d038813ad`（`v0.29 拆分正文统计轻量指标`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28766381429`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.29-main-5d36ea3-run28766381429-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28766381429/` 复判，目录大小约 `1.3M`。
- Agent X 复判结果：`ci-artifact-manifest.json` 中 `version=v0.29`、`branch=main`、`commitSha=5d36ea3cb24ffc2a7b6e2d4427af967d038813ad`、`runId=28766381429`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalEntryTests`、`JournalStatisticsTests` 和 `JournalListOverviewSnapshotTests` 已编译并执行，body summary / metrics 一致性、统计和列表概览用例通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- 日志中仍有 Xcode 16.4 的 AppIntents metadata extraction warning，以及 XCTest 结束后模拟器启动 app 的错误片段；manifest outcome、JUnit、failure summary 和 `** TEST SUCCEEDED **` 均确认它们未导致本轮失败。
- Agent C 独立复判结果：确认当前 `HEAD` 与 `origin/main` 均为 `5d36ea3cb24ffc2a7b6e2d4427af967d038813ad`；artifact `mdjournal-ci-v0.29-main-5d36ea3-run28766381429-attempt1` 的 manifest、JUnit、iOS build、Mac Catalyst build、XCTest 日志和三个 `.xcresult/Info.plist` 均核对通过；未执行 `gh auth login`，未改变 GitHub CLI 配置。

遗留事项：

- 本轮只拆分统计/概览可用的轻量正文 metrics，不改变摘要文案、词数 split、`###` 小节识别、统计口径或 UI 样式。

### v0.28 / 最近 7 天趋势最大词数预计算

日期：2026-07-05

核心变更：

- `JournalStatistics` 新增最近 7 天趋势最大词数派生值，在统计初始化阶段随 7 天趋势数组一次性计算，并保持空状态分母下限为 `1`。
- `StatisticsDashboardView` 的 7 天趋势柱状图直接消费 `JournalStatistics` 的预计算最大词数，不再在每根柱子计算高度时重复扫描 7 天数组。
- `JournalStatisticsTests` 扩展覆盖空状态最大词数和固定样本最大词数 contract。
- GitHub Actions 结果包版本更新为 `v0.28`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图、本轮 Agent A 提示词和本日志。

关键文件：

- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournal/Views/StatisticsDashboardView.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.28（最近7天趋势最大词数预计算）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0。
- 初始实现 commit：`58c2468e044c7cb90c1d5bad8d1a1476af04b57c`（`v0.28 预计算七天趋势最大词数`），已 push 到 `origin/main`；GitHub Actions run `28741301917`，attempt `1` 失败。Agent X 下载未加密 artifact `mdjournal-ci-v0.28-main-58c2468-run28741301917-attempt1` 到 `/private/tmp/mdjournal-c-review-28741301917/` 复判，manifest 匹配本轮 commit，但 `JournalStatistics.swift` 因 `lastSevenDaysValue` 类型推断不足导致 iOS build、Mac Catalyst build 和 XCTest 均失败。
- 追加修复 commit：`5281ce29e104a9322f8216454d4f9009717ec3d5`（`v0.28 修复七天趋势统计编译`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28741417617`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.28-main-5281ce2-run28741417617-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28741417617/` 复判，目录大小约 `1.3M`。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.28`、`branch=main`、`commitSha=5281ce29e104a9322f8216454d4f9009717ec3d5`、`runId=28741417617`、`runAttempt=1` 与本轮修复 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalStatisticsTests` 已编译并执行，空状态最大词数和固定样本最大词数用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只处理最近 7 天趋势最大词数预计算，不改变趋势图日期窗口、排序、柱高公式或 UI 样式。

### v0.27 / 统计看板分布最大值预计算

日期：2026-07-05

核心变更：

- `JournalStatistics` 新增分类和心情分布最大 entry count 派生值，在统计初始化阶段一次性计算并保持显示分母下限为 `1`。
- `StatisticsDashboardView` 的分类和心情分布条直接消费 `JournalStatistics` 的预计算最大值，不再在每个 `DistributionRow` 渲染时重复扫描分布数组。
- `JournalStatisticsTests` 扩展覆盖空状态最大值和固定样本分类/心情最大值 contract。
- GitHub Actions 结果包版本更新为 `v0.27`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图、本轮 Agent A 提示词和本日志。

关键文件：

- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournal/Views/StatisticsDashboardView.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.27（统计看板分布最大值预计算）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0。
- 实现 commit：`0d667fd7942ea03f2d0ff02291fc59eaa9fae288`（`v0.27 预计算统计分布最大值`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28739204401`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.27-main-0d667fd-run28739204401-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28739204401/` 复判，目录大小约 `1.3M`。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.27`、`branch=main`、`commitSha=0d667fd7942ea03f2d0ff02291fc59eaa9fae288`、`runId=28739204401`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `static-checks.log` 未发现 `warning:` 或 `error:`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalStatisticsTests` 已编译并执行，空状态最大值和固定样本统计用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只处理分类和心情分布最大值预计算，不改变最近 7 天趋势柱状图的最大词数计算。

### v0.26 / Markdown 有序列表插入入口

日期：2026-07-05

核心变更：

- `MarkdownSnippet` 新增“有序列表”片段，默认插入 `1. `，正文工具栏、Mac Catalyst “插入 Markdown”菜单和键盘快捷键自动获得入口。
- `MarkdownSnippetInsertion` 新增有序列表选区规则，选中多行时转换为从 `1. ` 开始递增编号的行，并保留尾随换行处理。
- `MarkdownSnippetCommandShortcut` 为有序列表片段分配 `⌘⌥O`，继续避开 `⌘N` 新建和已有写作/片段命令。
- `MarkdownSnippetTests` 扩展覆盖片段数量、顺序、markdown contract、有序列表多行插入和尾随换行。
- GitHub Actions 结果包版本更新为 `v0.26`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownSnippet.swift`
- `MDJournal/Utilities/MarkdownSnippetInsertion.swift`
- `MDJournal/Utilities/MarkdownSnippetCommandShortcut.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.26（有序列表插入入口）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0。
- 实现 commit：`8eaa75a15ae35f97d21bd7e9295dc9df5e1084b6`（`v0.26 增加有序列表插入入口`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28737678112`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.26-main-8eaa75a-run28737678112-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28737678112/` 复判，目录大小约 `1.3M`。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.26`、`branch=main`、`commitSha=8eaa75a15ae35f97d21bd7e9295dc9df5e1084b6`、`runId=28737678112`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `static-checks.log` 未发现 `warning:`、`error:`、`extraneous duplicate parameter name` 或 `replacementText already has an argument label`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownSnippetTests` 已编译并执行，新增有序列表多行编号和尾随换行用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只补齐 `数字. ` 有序列表片段入口，不支持 `1) ` 变体、嵌套列表或对已有有序列表自动重编号。

### v0.25 / 正文输入静态警告清理

日期：2026-07-05

核心变更：

- `MarkdownBodyTextView.Coordinator` 的 `UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:)` 方法签名移除重复本地参数标签，保留 `replacementText:` 外部标签和 delegate selector。
- 普通 Tab fallback、Markdown 回车续写、IME marked text 跳过、正文 binding 和选区同步逻辑保持不变。
- GitHub Actions 结果包版本更新为 `v0.25`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、本轮 Agent A 提示词和本日志。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/prompt/v0（写作效率）/v0.25（清理正文输入静态警告）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0。
- 实现 commit：`4002197e96fefab35286dfa1bcee984fdde33827`（`v0.25 清理正文输入静态警告`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28736206114`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.25-main-4002197-run28736206114-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28736206114/` 复判，目录大小约 `1.3M`。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.25`、`branch=main`、`commitSha=4002197e96fefab35286dfa1bcee984fdde33827`、`runId=28736206114`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `static-checks.log` 中不再出现 `extraneous duplicate parameter name` 或 `replacementText already has an argument label`，`xcrun swiftc -parse` 阶段无 warning / error 输出。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownTextInputConfigurationTests`、`MarkdownLineContinuationTests` 和 `MarkdownLineIndentationTests` 已编译并执行，输入 traits、回车续写和缩进相关用例通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只清理 `replacementText` 重复参数标签 warning，不重构 `MarkdownBodyTextView` 焦点调度、输入规则或保存链路。

### v0.24 / Markdown 有序列表预览

日期：2026-07-05

核心变更：

- `MarkdownBlockParser` 新增 `.orderedList` 块和 `OrderedListItem`，识别 leading whitespace trim 后的 `数字. ` 有序列表行。
- 有序列表解析会保留用户输入的编号文本和项目正文，避免大编号转换溢出，也让预览按原编号展示。
- `MarkdownPreviewView` 新增有序列表渲染分支，使用编号列和正文列对齐显示，服务 Mac Catalyst 宽屏编辑/预览链路。
- `MarkdownBlockParserTests` 扩展覆盖有序列表识别、混合块 flush、代码块内不解析、非法 `1.` / `1) ` 变体和 `###` 小节分组保留有序列表。
- GitHub Actions 结果包版本更新为 `v0.24`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.24（Markdown有序列表预览）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 本地轻量检查：`git diff --check` 返回 0 且无输出；`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 输出 `yaml ok` 并返回 0。
- 实现 commit：`4fec9b32e37e9ed8aab84bb06bbf3aaa1b53e739`（`v0.24 支持 Markdown 有序列表预览`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28735275349`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.24-main-4fec9b3-run28735275349-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28735275349/` 复判，目录大小约 `1.3M`。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.24`、`branch=main`、`commitSha=4fec9b32e37e9ed8aab84bb06bbf3aaa1b53e739`、`runId=28735275349`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownBlockParserTests` 已编译并执行，新增有序列表混合块 flush、代码块内不解析、非法 `1.` / `1) ` 变体、leading whitespace trim 和空有序项用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只支持 `数字. ` 有序列表预览，不支持 `1) ` 变体、嵌套列表、整段自动重编号、工具栏按钮或菜单项。
- `static-checks.log` 仍记录 `MarkdownBodyTextView.swift` 中既有 `replacementText` 重复参数标签 warning；CI 通过且该 warning 不属于 v0.24 有序列表预览改动范围，后续可单独清理。

### v0.23 / Markdown 有序列表回车续写

日期：2026-07-05

核心变更：

- `MarkdownLineContinuation` 扩展支持 `数字. ` 有序列表行回车续写，非空项会延续同缩进前缀并递增编号。
- 空有序列表项按回车会删除当前有序列表前缀并退出列表，行为与空无序列表、待办和引用退出保持一致。
- 光标在有序列表行中间按回车时会拆分当前行，并让后半段继续处在下一编号有序列表中。
- 新增 `MarkdownLineContinuationTests` 有序列表用例，覆盖编号递增、多位编号、缩进、空项退出、行中拆分、fenced code、非折叠选区、普通输入、溢出编号和 UTF-16/emoji 光标边界。
- GitHub Actions 结果包版本更新为 `v0.23`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownLineContinuation.swift`
- `MDJournalTests/MarkdownLineContinuationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.23（Markdown有序列表回车续写）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行、XCTest、模拟器或 app；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`7a7ac3636f77da73dbf4a247cceb2eb2d1e9157f`（`v0.23 支持 Markdown 有序列表续写`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28734113176`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.23-main-7a7ac36-run28734113176-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28734113176/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.23`、`branch=main`、`commitSha=7a7ac3636f77da73dbf4a247cceb2eb2d1e9157f`、`runId=28734113176`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownLineContinuationTests` 已编译并执行，新增有序列表编号递增、多位编号、缩进、空项退出、行中拆分、fenced code、非折叠选区、普通输入、溢出编号和 UTF-16/emoji 光标边界用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只支持 `数字. ` 有序列表前缀，不支持 `1) ` 变体。
- 本轮不做有序列表预览渲染、整段自动重编号、工具栏按钮或 undo 分组。

### v0.22 / Markdown 引用回车续写

日期：2026-07-05

核心变更：

- `MarkdownLineContinuation` 扩展支持 `> ` 引用行回车续写，非空引用行会延续同缩进引用前缀。
- 空引用行按回车会删除当前 `> ` 前缀并退出引用，行为与空列表项退出当前结构保持一致。
- 光标在引用行中间按回车时会拆分当前行，并让后半段继续处在引用中。
- 新增 `MarkdownLineContinuationTests` 引用用例，覆盖引用续写、空引用退出、缩进引用、行中拆分、fenced code、非折叠选区、普通输入和 UTF-16/emoji 光标边界。
- GitHub Actions 结果包版本更新为 `v0.22`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownLineContinuation.swift`
- `MDJournalTests/MarkdownLineContinuationTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.22（Markdown引用回车续写）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行或测试；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`07143e778a1dceda93f83b73e560940d441d8d94`（`v0.22 支持 Markdown 引用续写`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28731099346`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.22-main-07143e7-run28731099346-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28731099346/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.22`、`branch=main`、`commitSha=07143e778a1dceda93f83b73e560940d441d8d94`、`runId=28731099346`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownLineContinuationTests` 已编译并执行，新增引用续写、空引用退出、缩进引用、行中拆分、fenced code、非折叠选区、普通输入和 UTF-16/emoji 光标边界用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮不支持裸 `>`、有序列表续写或新增 Markdown 预览语法。
- 后续可继续优化统计看板分布比例预计算和正文输入 undo 分组。

### v0.21 / 列表概览轻量统计快照

日期：2026-07-05

核心变更：

- 新增 `JournalListOverviewSnapshot`，只为列表首页概览卡计算总篇数、总词数、最近连续天数和概览洞察。
- `EntryListView` 顶部概览卡改用轻量快照，不再在列表 `body` 中构造完整 `JournalStatistics`。
- `StatisticsDashboardView` 和完整统计看板继续使用 `JournalStatistics`，统计看板语义不变。
- 新增 `JournalListOverviewSnapshotTests`，对照 `JournalStatistics` 覆盖空状态、概览字段一致性、连续记录 insight、低小节覆盖率 insight 和主导分类 tie-break。
- GitHub Actions 结果包版本更新为 `v0.21`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/JournalListOverviewSnapshot.swift`
- `MDJournal/Views/EntryListView.swift`
- `MDJournalTests/JournalListOverviewSnapshotTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.21（列表概览轻量统计快照）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行或测试；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`2d33add2598ee6de283b618b452994c18fc9f240`（`v0.21 优化列表概览统计成本`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28730229841`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.21-main-2d33add-run28730229841-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28730229841/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.21`、`branch=main`、`commitSha=2d33add2598ee6de283b618b452994c18fc9f240`、`runId=28730229841`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `JournalListOverviewSnapshotTests` 已编译并执行。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮不改变完整统计看板、不引入缓存失效机制、不改 `JournalStore` 保存链路。
- 后续可继续优化正文输入 undo 分组和局部文本替换。

### v0.20 / Markdown 行缩进 Tab 输入效率

日期：2026-07-05

核心变更：

- 新增 `MarkdownLineIndentation`，集中处理当前行或多行选区的 Tab 缩进与 Shift-Tab 反缩进。
- `MarkdownBodyTextView` 使用轻量 `UITextView` 子类捕获 Tab / Shift-Tab，并保留 `shouldChangeTextIn` 中普通 Tab 的 fallback；IME marked text 存在时不改写正文。
- 缩进单位为两个空格；反缩进会删除一个 tab 或最多两个行首空格。
- 新增 `MarkdownLineIndentationTests`，覆盖单行、多行、选区结束边界、emoji / UTF-16 光标、混合缩进反缩进和空反缩进。
- GitHub Actions 结果包版本更新为 `v0.20`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownLineIndentation.swift`
- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownLineIndentationTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.20（Markdown行缩进Tab输入效率）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行或测试；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`ba9c35b07ddcbb5f23b8523bac2de40a9f0f84fb`（`v0.20 支持 Markdown 行缩进`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28729565769`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.20-main-ba9c35b-run28729565769-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28729565769/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.20`、`branch=main`、`commitSha=ba9c35b07ddcbb5f23b8523bac2de40a9f0f84fb`、`runId=28729565769`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownLineIndentationTests` 已编译并执行，8 个新增用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮不新增 Markdown 预览语法，不改变 `JournalStore` 保存链路，不新增 native macOS target。
- 更细的 undo 分组仍留待后续优化。

### v0.19 / Markdown 安全输入配置

日期：2026-07-05

核心变更：

- `MarkdownBodyTextView` 新增集中输入配置，禁用 `smartDashesType`、`smartQuotesType` 和 `smartInsertDeleteType`。
- `makeUIView` 和 `updateUIView` 都会应用 Markdown 输入 traits，避免正文输入控件被外部状态重置后恢复系统自动替换。
- 新增 `MarkdownTextInputConfigurationTests`，覆盖配置方法首次应用和重复应用。
- GitHub Actions 结果包版本更新为 `v0.19`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownTextInputConfigurationTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.19（Markdown安全输入配置）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行或测试；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`4235fe16b946280625304dce9cdd92f742944bf2`（`v0.19 配置 Markdown 安全输入`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28728341490`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.19-main-4235fe1-run28728341490-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28728341490/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.19`、`branch=main`、`commitSha=4235fe16b946280625304dce9cdd92f742944bf2`、`runId=28728341490`、`runAttempt=1` 与本轮实现 commit 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownTextInputConfigurationTests` 已编译并执行，2 个新增用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮只禁用三类会改写 Markdown 标记的智能输入替换，不关闭中文 IME、拼写检查、自动大写或 autocorrection。
- 后续仍可继续优化 Tab/Shift-Tab 缩进和更细的 undo 行为。

### v0.18 / Markdown 列表回车续写

日期：2026-07-05

核心变更：

- 新增 `MarkdownLineContinuation`，集中处理 Markdown 列表和待办的回车续写规则。
- `MarkdownBodyTextView` 在 `UITextViewDelegate.shouldChangeTextIn` 中调用纯规则；普通输入、非折叠选区和 IME marked text 继续走系统默认行为。
- 非空列表项按回车会延续同缩进前缀；空列表项或空待办项按回车会退出列表。
- 待办项续写时统一生成未完成项，`- [x] 已完成` 的下一行变为 `- [ ] `。
- 新增 `MarkdownLineContinuationTests` 覆盖列表、待办、完成待办、缩进、空项退出、代码块、非折叠选区和 UTF-16/emoji 边界。
- GitHub Actions 结果包版本更新为 `v0.18`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownLineContinuation.swift`
- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournalTests/MarkdownLineContinuationTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.18（Markdown列表回车续写）.md`
- `update_log.md`

验证结果：

- 本轮按人工要求不运行本机构建、运行或测试；最终验收只以 GitHub Actions 回传结果包为准。
- 实现 commit：`866e691254932b0f45e24df4f5d3dfafe9ecb1a9`（`v0.18 支持 Markdown 列表回车续写`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28726671477`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.18-main-866e691-run28726671477-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28726671477/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.18`、`branch=main`、`commitSha=866e691254932b0f45e24df4f5d3dfafe9ecb1a9`、`runId=28726671477`、`runAttempt=1` 与最新 `origin/main` 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `xctest.log` 确认 `MarkdownLineContinuationTests` 已编译并执行，13 个新增用例均通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。

遗留事项：

- 本轮不实现 Tab/Shift-Tab 缩进，也不调整智能引号、智能破折号等输入 traits。
- 回车续写仅覆盖轻量 Markdown 列表/待办，不扩展 Markdown 预览语法。

### v0.17 / Mac Catalyst 一键构建运行入口

日期：2026-07-05

核心变更：

- 新增 `script/build_and_run.sh`，作为 Mac Catalyst 本地一键构建/运行入口。
- 脚本默认会停止已有 `MDJournal` 进程，构建 `MDJournal` scheme 的 Mac Catalyst Debug app，并用 `/usr/bin/open -n` 启动最新构建产物。
- 脚本固定使用 `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` 和 `/private/tmp/mdjournal-build-and-run`，避免默认 home DerivedData 权限噪声。
- 脚本支持 `run`、`--verify`、`--debug`、`--logs` 和 `--telemetry` 模式；`--verify` 会用 `pgrep -x MDJournal` 确认 app 进程存在。
- 新增 `.codex/environments/environment.toml`，让 Codex 桌面 `Run` action 指向 `./script/build_and_run.sh`。
- GitHub Actions 结果包版本更新为 `v0.17`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `script/build_and_run.sh`
- `.codex/environments/environment.toml`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.17（MacCatalyst一键构建运行入口）.md`
- `update_log.md`

验证结果：

- 实现 commit：`a36c8b196426aa91412555e13f5e81377e04e1ae`（`v0.17 增加 Mac 一键运行入口`），已 push 到 `origin/main`。
- GitHub Actions：`MD Journal CI Results` run `28725868018`，attempt `1`，结论 `success`。
- 未加密 artifact：`mdjournal-ci-v0.17-main-a36c8b1-run28725868018-attempt1`，下载到 `/private/tmp/mdjournal-c-review-28725868018/` 复判。
- Agent C 复判结果：`ci-artifact-manifest.json` 中 `version=v0.17`、`branch=main`、`commitSha=a36c8b196426aa91412555e13f5e81377e04e1ae`、`runId=28725868018`、`runAttempt=1` 与最新 `origin/main` 一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 显示 `tests=4`、`failures=0`、`skipped=0`；`xcodebuild.log` 和 `maccatalyst-build.log` 均包含 `** BUILD SUCCEEDED **`，`xctest.log` 包含 `** TEST SUCCEEDED **`。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult`、`MDJournalTests.xcresult` 均存在，且 `Info.plist` 解析通过。
- 本轮最终验收只采用云端回传结果包；不把本机 GUI 启动作为验收依据。

遗留事项：

- 本轮不新增 native macOS target，Mac 版本仍走 Mac Catalyst。
- `--telemetry` 目前按 bundle id 过滤 unified logging；源码尚未接入专用 `Logger` subsystem，因此日志可能为空。

### v0.16 / JournalStore 更新跳过重复排序

日期：2026-07-05

核心变更：

- `JournalStore.update(_:)` 继续即时替换内存中的日记并安排 debounced save，但仅当 `createdAt` 改变时才重新排序。
- 正文、标题、分类、心情等非日期更新不再触发无效 `entries` 重排，减少长文本输入时的主线程排序成本。
- 日期被编辑后仍保持 `createdAt` 倒序，`createEntry()`、`delete(_:)` 和 `load()` 的排序/保存语义不变。
- `JournalStoreTests` 补充正文更新不重排、日期更新会重排两个回归用例。
- GitHub Actions 结果包版本更新为 `v0.16`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Stores/JournalStore.swift`
- `MDJournalTests/JournalStoreTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.16（JournalStore更新跳过重复排序）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`，输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`，输出 `yaml ok`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：iOS Simulator `build-for-testing`，以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS XCTest 已尝试，未启动；当前 CoreSimulatorService 无效且无匹配 `iPhone 16` simulator，`xcodebuild test` 返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `14a58bbc0b20f20113d9745cacc7b6f43f84e655` 到 `origin/main`；对应 GitHub Actions run id `28715388682`、run attempt `1`、artifact `mdjournal-ci-v0.16-main-14a58bb-run28715388682-attempt1` 已下载到 `/private/tmp/mdjournal-c-review-28715388682/`，目录大小 `868K`。
- Agent C 已核对实现 commit 的 manifest：`version=v0.16`、`branch=main`、`commitSha=14a58bbc0b20f20113d9745cacc7b6f43f84e655`、`runId=28715388682`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 39 个 XCTest 用例通过，其中 `JournalStoreTests.testBodyUpdateKeepsExistingCreatedAtOrder()` 和 `JournalStoreTests.testCreatedAtUpdateReordersEntries()` 已通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在，且各自 `Info.plist` 可正常解析。

遗留事项：

- 本轮不实现“本地正文草稿 + 延迟提交”方案，避免改变 `JournalStore.entries` 即时内存更新时序。
- 尚未做本机模拟器交互验证；当前环境 CoreSimulator 服务不可用，最终以 GitHub Actions 和后续可用设备人工体验为准。

### v0.15 / 光标选区插入 Markdown 片段

日期：2026-07-05

核心变更：

- 新增 `MarkdownSnippetInsertion`，把 Markdown 片段插入、选区包裹、多行前缀和 UTF-16 `NSRange` clamp 规则集中为可测试纯规则。
- 新增 `MarkdownBodyTextView`，用最小 `UITextView` bridge 同步正文、光标/选区和焦点，替换正文区域原有 `TextEditor`。
- `EntryEditorView.insertSnippet(_:)` 改为按当前光标或选区应用片段；正文工具栏、Mac Catalyst “插入 Markdown”菜单、写作工具栏和键盘快捷键继续复用同一路径。
- 加粗、斜体、代码块支持包裹选中文本；引用、列表和待办支持对多行选区逐行加前缀；空选区插入后光标或占位选区落在自然继续编辑的位置。
- `MarkdownSnippetTests` 补充光标中间插入、选区包裹、多行前缀、代码块、emoji UTF-16 选区和非法 range clamp 用例。
- GitHub Actions 结果包版本更新为 `v0.15`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Views/MarkdownBodyTextView.swift`
- `MDJournal/Utilities/MarkdownSnippetInsertion.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.15（光标选区插入Markdown片段）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`，输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`，输出 `yaml ok`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：iOS Simulator `build-for-testing`，以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS XCTest 已尝试，未启动；当前 CoreSimulatorService 无效且无匹配 `iPhone 16` simulator，`xcodebuild test` 返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 首个实现 commit `807e64d831e66ec984a024054dc0eb15657de5ed` 到 `origin/main`；对应 GitHub Actions run id `28712905174`、run attempt `1`、artifact `mdjournal-ci-v0.15-main-807e64d-run28712905174-attempt1` 已下载到 `/private/tmp/mdjournal-c-review-28712905174/`。Agent C 复判确认 manifest 对应 `main` 和该 commit，static/build/Mac Catalyst 阶段通过，但 XCTest 在 `MarkdownSnippetTests.testSnippetInsertionExpandsInvalidUTF16RangeInsideEmoji` 失败，因此退回 Agent B 追加修复。
- 已 push 修复 commit `682fc5c7a9a2951d37a4aafe08ce4ea2e197ada7` 到 `origin/main`；对应 GitHub Actions run id `28713235836`、run attempt `1`、artifact `mdjournal-ci-v0.15-main-682fc5c-run28713235836-attempt1` 已下载到 `/private/tmp/mdjournal-c-review-28713235836/`，目录大小 `848K`。
- Agent C 已核对修复 commit 的 manifest：`version=v0.15`、`branch=main`、`commitSha=682fc5c7a9a2951d37a4aafe08ce4ea2e197ada7`、`runId=28713235836`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 37 个 XCTest 用例通过，其中 `MarkdownSnippetTests.testSnippetInsertionExpandsInvalidUTF16RangeInsideEmoji()` 已通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在，且各自 `Info.plist` 可正常解析。

遗留事项：

- 本轮只实现 Mac Catalyst/iOS 共用的 `UITextView` bridge 与片段插入规则，不新增独立 native macOS target。
- 尚未做本机模拟器交互验证；当前环境 CoreSimulator 服务不可用，最终以 GitHub Actions 和后续可用设备人工体验为准。

### v0.14 / Mac 写作工具栏 polish

日期：2026-07-04

核心变更：

- 新增 `EditorWritingCommand`，集中定义 Mac Catalyst 写作命令、图标和快捷键映射。
- `MDJournalApp` 新增“写作”菜单，提供聚焦正文和显示/隐藏预览命令。
- `EntryEditorView` 在 Mac Catalyst 下新增顶部写作工具栏，提供聚焦正文、插入 Markdown 和显示/隐藏预览入口。
- 宽屏编辑器支持隐藏右侧预览栏，让正文编辑区获得更宽写作空间；iPhone/iPad 窄屏编辑/预览模式保持不变。
- `MarkdownSnippetTests` 补充写作命令元数据、快捷键唯一性和不与 Markdown 片段快捷键冲突的测试。
- GitHub Actions 结果包版本更新为 `v0.14`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Utilities/EditorWritingCommand.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.14（Mac写作工具栏polish）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`，输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`，输出 `yaml ok`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：iOS Simulator `build-for-testing`，`MarkdownSnippetTests.swift` 已重新编译进 `MDJournalTests`，以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS XCTest 已尝试，未启动；`CoreSimulatorService connection became invalid`，且当前无可用 `iPhone 16` simulator，`xcodebuild test` 返回 70。
- 已 push 实现 commit `f84ef49abc5eabd44edf37482764f9354fcab831` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28711523685`，run attempt `1`，artifact `mdjournal-ci-v0.14-main-f84ef49-run28711523685-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28711523685/`，目录大小 `768K`。
- manifest 核对通过：`version=v0.14`、`branch=main`、`commitSha=f84ef49abc5eabd44edf37482764f9354fcab831`、`runId=28711523685`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 `JournalEntryTests`、`JournalStatisticsTests`、`MarkdownBlockParserTests`、`JournalStoreTests`、`MarkdownSnippetTests` 和 `JournalEntryListSnapshotTests` 共 28 个测试用例通过，其中写作命令新增 2 个用例。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在，且各自 `Info.plist` 可正常解析。

遗留事项：

- 本轮只做 Mac Catalyst 写作工具栏和菜单 polish，不实现光标位置插入或选中文本包裹。
- 后续可单独评估 `UITextView` bridge，以支持光标/选区插入 Markdown 片段。

### v0.13 / 列表派生快照

日期：2026-07-04

核心变更：

- 新增 `JournalEntryListSnapshot`，用单次遍历派生列表过滤结果、总数和分类计数。
- `EntryListView` 改为在 `body` 中构造一次列表快照，并复用到过滤列表、section 标题和分类 chip。
- 搜索语义保持不变：trim 后匹配标题、正文、分类和心情；分类筛选仍先限制候选集。
- 分类 chip 数量保持基于全部日记，不受搜索文本影响。
- 新增 `JournalEntryListSnapshotTests` 覆盖空白搜索、大小写搜索、trim 后查询、空标题 fallback、分类筛选、分类计数和 section 标题。
- GitHub Actions 结果包版本更新为 `v0.13`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Views/EntryListView.swift`
- `MDJournal/Utilities/JournalEntryListSnapshot.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournalTests/JournalEntryListSnapshotTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.13（列表派生快照）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`，输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`，输出 `yaml ok`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：iOS Simulator `build-for-testing`，`JournalEntryListSnapshotTests.swift` 已编译进 `MDJournalTests`，以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS XCTest 已尝试，未启动；`CoreSimulatorService connection became invalid`，且当前无可用 `iPhone 16` simulator，`xcodebuild test` 返回 70。
- 已 push 实现 commit `c5ca35cf805e084e7bb3130b84e32e8a6b12ea7e` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28710154708`，run attempt `1`，artifact `mdjournal-ci-v0.13-main-c5ca35c-run28710154708-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28710154708/`，目录大小 `752K`。
- manifest 核对通过：`version=v0.13`、`branch=main`、`commitSha=c5ca35cf805e084e7bb3130b84e32e8a6b12ea7e`、`runId=28710154708`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 `JournalEntryTests`、`JournalStatisticsTests`、`MarkdownBlockParserTests`、`JournalStoreTests`、`MarkdownSnippetTests` 和 `JournalEntryListSnapshotTests` 共 26 个测试用例通过，其中列表快照新增 6 个用例。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在，且各自 `Info.plist` 可正常解析。

遗留事项：

- 本轮只优化列表派生遍历，不新增后台索引或持久化缓存。
- 后续可继续做光标位置插入、Mac 工具栏 polish 或更细的编辑器输入性能优化。

### v0.12 / Markdown 片段菜单命令

日期：2026-07-04

核心变更：

- `MDJournalApp` 新增“插入 Markdown”菜单，复用 `MarkdownSnippet.allCases` 生成片段命令。
- `EntryEditorView` 通过 focused scene value 暴露片段插入动作，菜单和工具栏复用同一追加式插入逻辑。
- 片段插入时会切回编辑模式并聚焦正文，避免窄屏预览模式下触发菜单后正文静默变化。
- 为片段菜单增加 `⌘⌥` 组合快捷键，避开已有 `⌘N` 新建入口和常见系统基础编辑快捷键。
- `MarkdownSnippetTests` 补充片段顺序、全量 markdown contract 和快捷键映射唯一性测试。
- GitHub Actions 结果包版本更新为 `v0.12`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Utilities/MarkdownSnippet.swift`
- `MDJournal/Utilities/MarkdownSnippetCommandShortcut.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（写作效率）/v0.12（Markdown片段菜单命令）.md`
- `update_log.md`

本机验证：

- `git diff --check`：通过。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj`：通过，输出 `MDJournal.xcodeproj/project.pbxproj: OK`。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`：通过，输出 `yaml ok`。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`：通过。
- Mac Catalyst build：通过，命令使用 `-destination 'generic/platform=macOS,variant=Mac Catalyst'` 和 `/private/tmp/mdjournal-derived-data-v012-mac-2`，结果 `** BUILD SUCCEEDED **`。
- 通用 iOS build：通过，命令使用 `-destination 'generic/platform=iOS'` 和 `/private/tmp/mdjournal-derived-data-v012-ios-2`，结果 `** BUILD SUCCEEDED **`。
- 本机 iOS XCTest：已尝试，未启动；`CoreSimulatorService` 连接失效且当前没有匹配 `iPhone 16` simulator。
- 本机 Mac Catalyst XCTest：已尝试，未启动；`MDJournalTests` 不支持 `My Mac` 的 `com.apple.platform.macosx` 测试平台。
- `xcrun simctl list devices available`：当前 `xcode-select` 指向 CommandLineTools 时找不到 `simctl`；显式设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 后仍因 `CoreSimulatorService connection became invalid` 无法列出设备。

云端验证：

- 实现提交：`7c25d5b99bfbeded5c84816adbe6b5494cf28e0a`
- GitHub Actions：`MD Journal CI Results`
- run id：`28709069066`
- run attempt：`1`
- artifact：`mdjournal-ci-v0.12-main-7c25d5b-run28709069066-attempt1`
- 下载缓存：`/private/tmp/mdjournal-c-review-28709069066`
- Agent C 复判：通过。manifest 中 `version=v0.12`、`branch=main`、`commitSha=7c25d5b99bfbeded5c84816adbe6b5494cf28e0a`、`runId=28709069066`、`runAttempt=1` 与最新实现提交一致；`staticChecksOutcome`、`buildOutcome`、`macCatalystBuildOutcome`、`testOutcome` 均为 `success`。
- `junit.xml` 阶段摘要 `failures=0`、`skipped=0`；`xctest.log` 显示 `** TEST SUCCEEDED **`，20 个 XCTest 用例通过。
- `xcodebuild.log` 和 `maccatalyst-build.log` 均以 `** BUILD SUCCEEDED **` 结束。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮仍采用末尾追加式片段插入，不支持光标位置插入或包裹选中文本。
- 后续可继续做列表搜索/分类筛选派生单次化，或在明确选区策略后改进片段插入位置。

### v0.11 / Mac Catalyst 统计独立窗口

日期：2026-07-04

核心变更：

- `JournalStore` 所有权从 `ContentView` 上移到 `MDJournalApp`，主窗口和 Mac Catalyst 统计窗口共享同一个本地日记状态。
- Mac Catalyst 下新增“统计”窗口 scene；列表工具栏和“日记”菜单的“显示统计”入口会打开独立统计窗口。
- iOS/iPadOS 继续使用现有统计 sheet，不改变移动端入口和展示路径。
- `StatisticsDashboardView` 增加 `showsCloseButton` 参数，sheet 保留关闭按钮，独立窗口依赖桌面窗口 chrome。
- GitHub Actions 结果包版本更新为 `v0.11`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/ContentView.swift`
- `MDJournal/Views/StatisticsDashboardView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.11（MacCatalyst统计独立窗口）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机未运行 iOS Simulator XCTest：本轮未改 XCTest 或模型规则，且当前机器 CoreSimulatorService 不可用；最终 XCTest 结果以 GitHub Actions artifact 为准。
- 本机额外尝试过 SwiftUI `Window` 单例统计窗口方案，但 Mac Catalyst Debug build 返回 65，确认当前 Catalyst 目标下不采用该方案；最终实现使用已通过构建的 `WindowGroup("统计", id:)`。
- 已 push 实现 commit `d81d23e1d9ae80f453010d52658b4eb138f1ccfd` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28706172797`，run attempt `1`，artifact `mdjournal-ci-v0.11-main-d81d23e-run28706172797-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28706172797/`，目录大小 `672K`。
- manifest 核对通过：`version=v0.11`、`branch=main`、`commitSha=d81d23e1d9ae80f453010d52658b4eb138f1ccfd`、`runId=28706172797`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 `JournalEntryTests`、`JournalStatisticsTests`、`MarkdownBlockParserTests`、`JournalStoreTests` 和 `MarkdownSnippetTests` 共 18 个测试用例通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在，且各自 `Info.plist` 可正常解析。

遗留事项：

- 本轮只做 Mac Catalyst 统计独立窗口，不新增 native macOS target，不改变 JSON schema、统计口径或 Markdown 解析语义。
- 统计窗口当前采用 Mac Catalyst 可构建的 `WindowGroup` scene；如后续要求严格单例窗口，需要另行评估更高版本 SwiftUI 或 AppKit 窗口控制。
- 后续可继续做 Markdown 片段键盘命令，或把列表搜索/分类筛选派生抽成可测试快照。

### v0.10 / 正文派生与统计单次化

日期：2026-07-04

核心变更：

- 新增非持久化 `JournalEntryBodySummary`，把正文摘要、词数、`###` 小节和小节数聚合为一次内存派生结果。
- `JournalEntry.excerpt`、`wordCount`、`sections`、`sectionCount` 保持旧 API，但委托给 `bodySummary`，不改变 JSON schema。
- `EntryRowView` 和 `EntryEditorView` 在单次渲染中构造一次 `JournalEntryBodySummary`，复用摘要、词数和小节数据。
- `JournalStatistics` 改为每篇日记只构造一次 `JournalEntryBodySummary`，并用单轮聚合生成总量、本周数据、分类分布、心情分布和 7 天趋势。
- `EntryListView` 和 `StatisticsDashboardView` 在 body 内构造一次 `JournalStatistics` 并传给子视图，避免同一渲染周期重复统计。
- 新增单元测试覆盖正文派生兼容、空统计、同一天多篇日记聚合和本周边界排除。
- GitHub Actions 结果包版本更新为 `v0.10`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/JournalStatistics.swift`
- `MDJournal/Views/EntryRowView.swift`
- `MDJournal/Views/EntryEditorView.swift`
- `MDJournal/Views/EntryListView.swift`
- `MDJournal/Views/StatisticsDashboardView.swift`
- `MDJournalTests/JournalEntryTests.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.10（正文派生与统计单次化）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机 `build-for-testing` 尝试已编译到 `** TEST BUILD SUCCEEDED **`，但 xcodebuild 进程返回 133；静默重跑仍因 CoreSimulatorService 连接异常提前失败，未把本机测试编译作为通过依据。
- 本机 iOS Simulator XCTest 未运行成功：当前机器没有可匹配的 `iPhone 16` simulator，CoreSimulatorService 不可用，命令返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `96568553c3af6dbef19135db9b423bd801047456` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28704631669`，run attempt `1`，artifact `mdjournal-ci-v0.10-main-9656855-run28704631669-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28704631669/`。
- 该 run manifest 核对通过：`version=v0.10`、`branch=main`、`commitSha=96568553c3af6dbef19135db9b423bd801047456`、`runId=28704631669`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=failure`。
- 失败原因已确认：`JournalStatisticsTests.testStatisticsAreDeterministicWithFixedCalendarAndNow()` 的洞察文案断言仍期待“日常”，但本轮新增低小节覆盖率样本后正确文案应优先提示 `###` 小节结构。
- 已 push 修复 commit `1c111582b83c2cd6e71a957f80ffab6ae2ccae25` 到 `origin/main`。
- Agent C 已下载并核对修复 commit 对应 GitHub Actions 结果包：run id `28704878607`，run attempt `1`，artifact `mdjournal-ci-v0.10-main-1c11158-run28704878607-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28704878607/`。
- manifest 核对通过：`version=v0.10`、`branch=main`、`commitSha=1c111582b83c2cd6e71a957f80ffab6ae2ccae25`、`runId=28704878607`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认 `JournalEntryTests`、`JournalStatisticsTests`、`MarkdownBlockParserTests`、`JournalStoreTests` 和 `MarkdownSnippetTests` 共 18 个测试用例通过。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只做非持久化派生和统计聚合性能优化，不引入持久化缓存、不改变本地 JSON、不改变 Markdown 和统计语义。
- 后续可继续检查更大的列表数据量下是否需要搜索/筛选派生缓存，前提是有明确失效策略。

### v0.9 / Mac Catalyst 菜单命令入口

日期：2026-07-04

核心变更：

- `MDJournalApp` 新增 scene-level “日记”菜单，提供“新建日记”和“显示统计”命令。
- `ContentView` 通过 focused scene value 暴露创建日记和显示统计动作，菜单与列表工具栏复用同一套入口。
- 统计 sheet 状态从 `EntryListView` 上移到 `ContentView`，为菜单命令和列表按钮提供统一展示路径。
- `⌘N` 快捷键改由菜单命令承载，工具栏新建按钮保留可见入口但不重复注册快捷键。
- GitHub Actions 结果包版本更新为 `v0.9`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/MDJournalApp.swift`
- `MDJournal/ContentView.swift`
- `MDJournal/Views/EntryListView.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.9（MacCatalyst菜单命令入口）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机未运行 iOS Simulator XCTest：本轮未改 XCTest 或模型规则，且当前机器 CoreSimulatorService 不可用；最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `c35eb4c9a3b3311e2d466e36e84ccd15ff6bdfdf` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28703673408`，run attempt `1`，artifact `mdjournal-ci-v0.9-main-c35eb4c-run28703673408-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28703673408/`。
- manifest 核对通过：`version=v0.9`、`branch=main`、`commitSha=c35eb4c9a3b3311e2d466e36e84ccd15ff6bdfdf`、`runId=28703673408`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只新增菜单命令入口，尚未做独立统计窗口、多窗口同步或 native macOS target。
- 后续可继续做正文派生快照与统计计算单次化。

### v0.8 / Markdown 预览解析单次化

日期：2026-07-04

核心变更：

- 新增 `MarkdownParseResult` 和 `MarkdownBlockParser.parseDocument(_:)`，用同一次块级解析结果派生普通块和 `###` 小节分组。
- `MarkdownPreviewView` 改为在单次 body 渲染中只解析一次正文，再复用 `blocks`、`sectionGroups` 和 `shouldUseSectionGroups`。
- 新增 `MarkdownBlockParserTests` 覆盖 `parseDocument(_:)` 的块解析、小节分组和 `shouldUseSectionGroups` 语义。
- GitHub Actions 结果包版本更新为 `v0.8`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步更新 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `MDJournal/Views/MarkdownPreviewView.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.8（Markdown预览解析单次化）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束；首次运行因临时 `.xcresult` 路径已存在未进入编译，换新路径后通过。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS Simulator `build-for-testing`，第二次 `-quiet` 重跑返回 0；首次尝试日志已输出 `** TEST BUILD SUCCEEDED **`，但进程返回 133，未作为通过依据。
- 本机 iOS Simulator XCTest 未运行成功：当前机器 CoreSimulatorService 不可用，且没有可匹配的 `iPhone 16` simulator；命令返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `ecce25cc53042990f88102c39ebbc8ca2afefffd` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28702960797`，run attempt `1`，artifact `mdjournal-ci-v0.8-main-ecce25c-run28702960797-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28702960797/`。
- manifest 核对通过：`version=v0.8`、`branch=main`、`commitSha=ecce25cc53042990f88102c39ebbc8ca2afefffd`、`runId=28702960797`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认新增 `MarkdownBlockParserTests` 通过，包括 `parseDocument(_:)` 复用块解析和代码块内 `###` 不误判为小节。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只优化 Markdown 预览在单次渲染中的重复解析，尚未缓存列表卡片 `JournalEntry.sections` 或统计派生计算。
- 后续可继续做列表小节摘要缓存、统计计算去重和更完整的 Mac 菜单命令。

### v0.7 / 编辑写入节流

日期：2026-07-04

核心变更：

- `JournalStore.update(_:)` 改为内存即时更新、短延迟合并保存，减少正文连续输入时的 JSON 编码和原子写盘次数。
- `JournalStore.createEntry()` 和 `delete(_:)` 仍立即保存，避免创建和删除丢失。
- 新增 `JournalStore.flushPendingSave()`，`ContentView` 在 scene phase 进入 inactive/background 时立即写入待保存变更。
- 新增 `JournalStoreTests`，覆盖创建立即写盘、编辑延迟写盘和 flush 立即写盘。
- GitHub Actions 结果包版本更新为 `v0.7`，保证 manifest 和 artifact 名称对应本轮提交。
- 同步更新 README、测试规范、核心流程、流程图和本日志。

关键文件：

- `MDJournal/Stores/JournalStore.swift`
- `MDJournal/ContentView.swift`
- `MDJournalTests/JournalStoreTests.swift`
- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（性能优化）/v0.7（编辑写入节流）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`。
- 本机已通过：`plutil -lint MDJournal.xcodeproj/project.pbxproj`。
- 本机已通过：`ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 本机已通过：`xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)`。
- 本机已通过：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -list -project MDJournal.xcodeproj`，返回 0；当前机器仍输出 CoreSimulatorService 连接错误。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：generic iOS 目的地 `build-for-testing`，`MDJournalTests` 编译通过并以 `** TEST BUILD SUCCEEDED **` 结束。
- 本机 iOS Simulator XCTest 未运行成功：当前机器 CoreSimulatorService 不可用，且没有可匹配的 `iPhone 16` simulator；命令返回 70。最终 XCTest 结果以 GitHub Actions artifact 为准。
- 已 push 实现 commit `3b73eb3277a8a8a78f69bbe1149f1a68307a5fad` 到 `origin/main`。
- Agent C 已下载并核对实现 commit 对应 GitHub Actions 结果包：run id `28702125850`，run attempt `1`，artifact `mdjournal-ci-v0.7-main-3b73eb3-run28702125850-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28702125850/`。
- manifest 核对通过：`version=v0.7`、`branch=main`、`commitSha=3b73eb3277a8a8a78f69bbe1149f1a68307a5fad`、`runId=28702125850`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`macCatalystBuildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=4`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`maccatalyst-build.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 和 Mac Catalyst build 均以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束。
- `xctest.log` 确认新增 `JournalStoreTests` 3 个用例均通过：创建立即写盘、编辑延迟写盘、flush 立即写盘。
- `MDJournal.xcresult`、`MDJournalMacCatalyst.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本轮只优化写入节流，尚未缓存 Markdown 预览解析或统计派生计算。
- 后续可继续做大正文预览缓存、列表小节摘要缓存和更完整的 Mac 菜单命令。

### v0.6 / 启用 Mac Catalyst 构建

日期：2026-07-04

核心变更：

- 启用 `MDJournal` app target 的 Mac Catalyst 支持，保留 iOS 16.0 和现有 iPhone/iPad 方向设置。
- CI 结果包新增 Mac Catalyst Debug build、`maccatalyst-build.log`、`MDJournalMacCatalyst.xcresult` 和 manifest/JUnit 中的 Catalyst outcome。
- 列表新增 Mac Catalyst 友好的右键删除入口，删除仍通过 `ContentView.deleteEntry(_:)` 和 `JournalStore.delete(_:)`。
- 新建日记按钮新增 `⌘N` 快捷键，提升桌面写作入口效率。
- 新增本轮 Agent A 提示词，并同步 README、测试规范、核心流程和流程图。

关键文件：

- `MDJournal.xcodeproj/project.pbxproj`
- `.github/workflows/ci-results.yml`
- `MDJournal/Views/EntryListView.swift`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（macOS适配）/v0.6（启用MacCatalyst构建）.md`
- `update_log.md`

验证结果：

- 本机已通过：`git diff --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、workflow YAML 解析。
- 本机已通过：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -list -project MDJournal.xcodeproj`。
- 本机已通过：generic iOS Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机已通过：Mac Catalyst Debug build，以 `** BUILD SUCCEEDED **` 结束。
- 本机 `xcodebuild` 仍输出 CoreSimulatorService 连接错误，但 Catalyst build 返回 0，且该错误与本轮 Catalyst 构建结果无关。
- GitHub Actions artifact 验收需在本轮 commit push 到 `origin/main` 后由 Agent C 下载最新结果包复判。

遗留事项：

- 本轮先建立 Mac Catalyst 可构建基线，尚未新增独立 native macOS target。
- 后续应继续优化桌面写作体验，例如更完整的菜单命令、独立统计窗口、编辑保存节流和大正文预览缓存。
- 本轮未做真实 macOS 窗口截图或交互视觉验收。

### v0.5 / 引入 Agent X 循环迭代文档基线

日期：2026-07-04

核心变更：

- 新增 Agent X 召唤、职责、循环判断和停止条件。
- 将现有 Agent A/B/C 云端验证流程扩展为可被 Agent X 多轮调度。
- 更新 flow、flowchart、test、prompt README 和 README 中的协作说明。
- 明确本轮只做文档准备，不启动真实自动循环。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `md/prompt/v0（协作自动化）/v0.5（引入AgentX循环迭代）.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- 已 push `d6e3ade957188e335377bf7d3b41e8ec452a31c5` 到 `origin/main`。
- Agent C 已下载并核对最新 `origin/main` 对应 GitHub Actions 结果包：run id `28681864701`，run attempt `1`，artifact `mdjournal-ci-v0.4-main-d6e3ade-run28681864701-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28681864701/`。
- manifest 核对通过：`branch=main`、`commitSha=d6e3ade957188e335377bf7d3b41e8ec452a31c5`、`runId=28681864701`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=3`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束，10 个测试用例均通过。
- `MDJournal.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 后续人工可用 `agentx:` 提供总目标 X，启动 Agent X 主控循环。
- Agent X 真正执行循环时，仍必须经过 Agent A 提示词、Agent B 实现 push、Agent C 云端 artifact 验收。

### v0.4 / 建立 XCTest 基线

日期：2026-07-03

核心变更：

- 新增 `MDJournalTests` XCTest target，并通过共享 `MDJournal` scheme 纳入测试。
- 新增第一批核心规则单元测试，覆盖 `JournalEntry` 旧 JSON 兼容解码、空标题展示、starter `###` 模板、`JournalSection` 小节抽取、`MarkdownBlockParser` 块解析与 `###` 分组、`JournalStatistics` 固定日期统计口径和 `MarkdownSnippet` 工具栏片段契约。
- 修正 `JournalSection.extract` 与 `MarkdownBlockParser` 对 `### ` 空标题的识别，确保回退为“未命名小节”。
- 更新 `MD Journal CI Results` workflow：保留静态检查和 generic iOS Debug build，新增 simulator XCTest，artifact 增加 `xctest.log` 和 `MDJournalTests.xcresult`，manifest 的 `testOutcome` 改为真实 `success/failure`。
- 同步更新 README、测试规范、核心流程和流程图中的测试基线、CI 结果包内容和远端状态。

关键文件：

- `MDJournal.xcodeproj/project.pbxproj`
- `MDJournal.xcodeproj/xcshareddata/xcschemes/MDJournal.xcscheme`
- `.github/workflows/ci-results.yml`
- `MDJournalTests/JournalEntryTests.swift`
- `MDJournalTests/MarkdownBlockParserTests.swift`
- `MDJournalTests/JournalStatisticsTests.swift`
- `MDJournalTests/MarkdownSnippetTests.swift`
- `MDJournal/Models/JournalEntry.swift`
- `MDJournal/Utilities/MarkdownBlockParser.swift`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `update_log.md`

验证结果：

- Agent B 本地轻量检查通过：`git diff --check`、`git diff --cached --check`、`plutil -lint MDJournal.xcodeproj/project.pbxproj`、Swift parse、workflow YAML 解析、scheme XML 解析和 `xcodebuild -list`。
- Agent B 本机 XCTest 未运行成功：当前机器 CoreSimulatorService 连接失效且没有匹配的 iPhone 16 simulator；`build-for-testing -destination 'generic/platform=iOS Simulator'` 返回 0。
- Agent B 已 push `d55de09a0f02421394f94003e1851f53ec02249a` 到 `origin/main`。
- Agent C 已下载并核对最新 `origin/main` 对应 GitHub Actions 结果包：run id `28671607692`，run attempt `1`，artifact `mdjournal-ci-v0.4-main-d55de09-run28671607692-attempt1`，缓存目录 `/private/tmp/mdjournal-c-review-28671607692/`。
- manifest 核对通过：`branch=main`、`commitSha=d55de09a0f02421394f94003e1851f53ec02249a`、`runId=28671607692`、`runAttempt=1`、`staticChecksOutcome=success`、`buildOutcome=success`、`testOutcome=success`。
- `junit.xml` 核对通过：`tests=3`、`failures=0`、`skipped=0`。
- `static-checks.log`、`xcodebuild.log`、`xctest.log` 和 `ci-failure-summary.md` 核对通过；云端 generic iOS build 以 `** BUILD SUCCEEDED **` 结束，XCTest 以 `** TEST SUCCEEDED **` 结束，10 个测试用例均通过。
- `MDJournal.xcresult` 和 `MDJournalTests.xcresult` 均存在。

遗留事项：

- 本机环境仍未完成真实 iOS Simulator XCTest 和交互视觉验证，原因是当前机器 CoreSimulator 服务不可用；本轮最终重验证以 GitHub Actions artifact 为准。
- 本轮未新增 UI test 或模拟器交互视觉验证。

### v0.3 / 升级 main 直推云端验证流程

日期：2026-07-03

核心变更：

- 将协作制度从“Agent C 本地验收后提交”升级为“Agent B main 直推、GitHub Actions 云端重验证、Agent C 下载未加密结果包复判”。
- 新增 Agent A/B/C 召唤前缀和最终回复身份标识规则。
- 明确 `main` 是默认唯一上传、提交、推送和云端验证分支；本阶段不设计 `smalldata_test`、`develop`、`codeb/...` 或 PR 流程。
- 新增 `.github/workflows/ci-results.yml`，在 `main` push 和手动触发时运行静态检查、generic iOS Debug build，并上传 manifest、failure summary、日志、JUnit 和 `.xcresult`。
- 更新测试规范为“本地轻量检查 + 云端重验证”默认策略，保留人工明确要求时的本机完整 build 命令。
- README 仅新增简短“协作与云端验证”说明，不替代入口规则。

对比判断：

- 可复用 AITRANS 的制度骨架：main 直推、CI 结果包、manifest 可追溯、Agent C 下载复判、失败后追加修复 commit。
- 不照搬 AITRANS 的项目特例：漫画探针、GGUF、模型 Release、`test/1.png`、`smalldata_test`、候选分支和 PR 合并流。
- MD Journal 是 SwiftUI iOS / Xcode 项目，结果包重点是 project lint、Swift parse、generic iOS build 日志、JUnit 摘要和 `.xcresult`。

关键文件：

- `AGENTS.md`
- `.github/workflows/ci-results.yml`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `README.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过。
- 未运行本机完整 Xcode build：本轮是流程和 CI 改造，且新规范默认由云端重验证承担完整 build。
- 未完成真实 `main` push、GitHub Actions run 和 artifact 下载：当前 `git remote -v` 无输出，仓库未配置 `origin` 远端。

遗留事项：

- 人工需要配置 `origin` 远端和 GitHub Actions 权限后，执行首次 `git push origin main`。
- Agent C 需要在可访问仓库的环境中 `gh auth login`，下载 `/private/tmp/mdjournal-c-review-<run_id>/` 缓存并核对结果包。
- 项目仍未建立 XCTest target；CI 结果包中的 XCTest 当前标记为 `skipped`。

### v0.2 / 更新 Agent C 验收提交规则

日期：2026-06-29

核心变更：

- 明确 Agent C 验收不通过时退回 Agent B，并列出问题与修复要求。
- 明确 Agent C 最终通过后按版本号自动 stage 并 git commit。
- 规定提交说明使用“版本号 + 简短工作概括”，用于概括该版本工作内容。
- 同步更新入口规则、核心流程、流程图、README 和更新日志。

关键文件：

- `AGENTS.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `rg -n "[ \t]+$" AGENTS.md update_log.md README.md md` 无输出。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本轮仅修改文档流程，未重跑 Xcode generic iOS build。

遗留事项：

- 本轮仅修改文档流程，不涉及 Swift 源码和 Xcode 工程。

### v0.1 / 建立多 Agent 迭代文档体系

日期：2026-06-28

核心变更：

- 新增标准入口 `AGENT.md`，后续工作区入口调整为 `AGENTS.md`。
- 新增 `update_log.md` 记录版本、决策和遗留问题。
- 新增 `md/prompt/` 提示词目录和本轮 v0.1 提示词。
- 新增 `md/test/test.md` 测试分层与当前基线。
- 新增 `md/flow/flow.md` 项目核心逻辑文档。
- 新增 `md/flow/flowchart.md` Mermaid 可视化流程图。
- README 调整为指向标准文档体系。

关键文件：

- `AGENT.md`
- `update_log.md`
- `md/prompt/README.md`
- `md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `agent.md`

验证结果：

- `test -f AGENT.md && test -f update_log.md && test -f md/prompt/README.md && test -f 'md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md' && test -f md/test/test.md && test -f md/flow/flow.md && test -f md/flow/flowchart.md` 通过。
- `git diff --check` 通过。
- `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本轮只改文档，未重跑 Xcode generic iOS build。

遗留事项：

- 尚未建立 XCTest target。
- 尚未建立 Markdown lint。
- 当前环境 CoreSimulator 不可用，模拟器交互验证待真机或可用模拟器环境补做。
- 当前 macOS 工作区大小写不敏感，历史跟踪路径为小写 `agent.md`；本轮已通过 `git mv -f agent.md AGENT.md` 登记大小写重命名，标准入口为 `AGENT.md`。

## 历史维护记录

### 2026-06-27 / 初版后续 Codex 提示词

- 新增小写 `agent.md`，记录项目总结和后续 Codex 编程规范。
- README 补充横屏、响应式布局、验证命令和维护说明。
- 已验证 `plutil -lint MDJournal.xcodeproj/project.pbxproj` 通过。
- 已验证 `xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)` 通过。
- 本次新规范建立后，小写 `agent.md` 改为兼容入口，标准入口为大写 `AGENT.md`。

### 2026-06-25 前后 / 应用基础实现与响应式优化

- 建立 SwiftUI iOS 日记应用基础功能。
- 实现本地 JSON 保存、列表、编辑器、Markdown 预览、分类、心情、统计看板。
- 增加 iPhone 横屏方向支持。
- 宽屏编辑器改为编辑/预览左右分栏。
- 宽屏统计看板改为两列布局。
- 列表概览指标和小节摘要适配横屏与窄屏。
- 历史 Xcode generic iOS Debug 构建曾通过；当前记录以最新测试规范为准。

### v0.89 接续审查补充
固定标题 TextField 结构位置，避免键盘压缩高度时替换输入控件；云端新增 720→320→720pt UIHosting 身份检查，预期总计 234 项。未把 UIKit 控件身份检查描述为真实 IME 或 first responder 验收。

- 窗口兼容修复 commit `a3004123c70ad0c9b520c359ae62f7e964f11c92` 已核对：run `38343902815` attempt `1`，artifact `mdjournal-ci-v0.89-main-a300412-run38343902815-attempt1`（ID 11788670938，1650170 bytes，SHA-256 a6b35ddbad9c17c679f8ac4e7b659ccb47d3452786e0cc232ecfc052d068a932）；四阶段 success，JUnit 4/0/0/0，233 项通过，549 ZIP entries 未加密、CRC/digest/逐文件哈希通过。标题身份补充提交须独立验收。
