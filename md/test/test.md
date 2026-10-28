# 测试规范

## v0.95 当前范围与状态

用户已明确选择按模块并行实施，覆盖此前 A→B→C 串行轮转。原 257 项 XCTest、8 项纯 Python 设备 fixture 和 16 张界面图片全部保留；新增手机生产导航/焦点、有界正文派生、备份/读取保护/认证、StoreKit 与分页导出测试，以及 9 张新图。最终 XCTest 数以源码声明和最新 xcresult 的同 SHA 实际执行数一致为准，不以 JUnit 的阶段数替代。

本轮完整构建与测试默认在云端。本机只跑下述轻量检查，禁止自动调用本机 build、XCTest、xcodebuild、simctl、App 或 Instruments。未来如人工另行明确要求本机 iOS 编译/运行，必须只用 FAC4325D 前缀那台既有完整 UDID，禁止创建或选择其他设备；云端不限。

旧 v0.94/14854d3 基线 run40054782075/attempt1 的 257 项、16 图与未加密 artifact 已下载核对，仅作本轮起点。任何新结果不得复用旧包或本地输出。

## 轻量检查

在 main、本轮已知文件范围内执行：

```sh
git status --short --branch
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
plutil -lint MDJournal/Info.plist
plutil -lint MDJournal/PrivacyInfo.xcprivacy
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournalTests)
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s script/tests -v
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
bash -n script/archive_ios_release.sh
bash -n script/package_macos.sh
```

工作流还需逐 run 块 `bash -n`、所有内嵌 Python 与脚本 `ast.parse`；所有颜色/图标 JSON、StoreKit 配置 JSON 与资源注册检查。Swift parse 仅验证语法，不是类型检查。纯 Python 当前 31 项：8 项固定 runtime/已有设备选择、7 项 iOS archive 拒绝条件，以及 16 项商店素材路径/来源/PNG/透明度/完整性 fixture，不启动系统服务。

## 云端功能 job

`.github/workflows/ci-results.yml` 的 `ci-results` 固定 macos-15/Xcode26.2/iOS26.2：

1. 静态检查与纯 Python fixtures。
2. 读取可用设备 JSON，只在固定 runtime 中选一台已有 iPhone，Booted 优先，再 iPhone16；缺 runtime 或设备明确失败，不创建克隆、不回退别的系统。runtime 与设备查询各限 60 秒，整个准备步骤限 4 分钟；复用该报告的 initialState，不重复查询 booted 列表。提前启动并记录 UDID/runtime/初始状态，准备失败不继续构建/测试，但保留失败包。
3. 专用 MDJournalCI scheme 引用 MDJournalCI.xctestplan，显式设置仅测试使用的 StoreKit 配置，普通 MDJournal scheme 和设备归档不带本地商店。先独立 build-for-testing 上限 600 秒；同一 UDID bootstatus 上限 240 秒；独立 StoreKit 预检上限 180 秒、导航与焦点预检上限 240 秒，商店核 3/3、导航/输入核 4/4，均无跳过，前者失败仍执行后者取证，任一失败即不执行完整回归且终门失败；全部预检通过后串行 test-without-building 上限 720 秒，不借机删测试、跳过或缩减门槛。启用 XCTest 进程外逐用例 watchdog，默认/最大 180 秒，五项生产导航/焦点/组合输入 host 用例明确 60 秒，避免主线程循环阻止用例内等待超时后又耗尽整轮预算；超时仍计失败。
4. 导出 xcresult 附件，校验原 16 图及新增 9 图的名称、PNG、精确尺寸、manifest 和 index。独立打包 3 张商店尺寸素材，检查完整 PNG chunks/CRC、无 alpha/tRNS、精确尺寸、附件来源与 SHA256。两套矩阵均须完整，缺图使该阶段失败；仍为同 311 项用例，不把附图算成新增测试。
5. 测试与图片成功后再运行 generic iOS Debug、Mac Catalyst Debug 和 universal Mac Catalyst Release 构建、图标/架构/签名/ZIP/文件内容与权限校验。Mac 为 ad-hoc 内部包，不代表公证或公开发布。

测试或图片失败时跳过重复平台构建，以更快获得失败包；终门仍要求全部六阶段 success，skip 不能放行。JUnit 表达六个工作流阶段，真正 XCTest 数来自 `xctest.log` 和 `MDJournalTests.xcresult`。测试汇总需核对全部测试实际执行、失败/跳过为零、新增交易和 host 回归的具体名称。成功结果包含四份主 xcresult 及两份预检 xcresult；失败包保留实际已执行并生成的 bundle、阶段日志、failure summary、设备选择与未加密 artifact。测试期间每 25 秒对存活宿主采样 2 秒并按阶段保存，避免 watchdog 杀掉进程后丢失栈；采样调用有 10 秒外部上限；StoreKit 预检另采样 storekitd 和 ASOctaneSupportXPCService。build-for-testing 后保存实际 .xctestrun，以便核对生效计划和环境。测试命令失败后，在清理宿主前对仍存活的 MDJournal 进程采样 3 秒，并尝试导出 xcresult diagnostics；各自有 15/30 秒外部上限，诊断缺失不会抹掉原失败状态。

若测试执行已生成可读 xcresult，即使 xcodebuild 返回失败，也先保存 `xctest-summary.json` 再使阶段失败，便于准确区分失败用例数与断言记录数；源声明数、实际执行数和零跳过终门保持。模拟器准备或测试进程中断导致 xcresult 不完整时，日志中的实际错误仍使阶段失败。

## 关键回归及证据边界

- 模型/Markdown：保留分类和心情兼容解码、ISO-8601、Foundation 换行、### 小节、fenced code 旧规则、词数、解析、inline cache、防抖、UTF-16、片段/回车/缩进和输入 traits 全部基线。
- 手机：真实 ContentView compact host 临时借用既有前台 key window，更换根控制器并在结束时完整恢复，避免同一 scene 同时发布两套场景命令对象。List 按公开 shouldSelect、selectItem、didSelect、primaryAction 顺序激活 NavigationLink，查看系统导航栈与真实标题/正文，系统 pop 后同篇重开；初次 push 前确认真实两行，截图及重开后离场前须等转场结束且详情全宽就位。新建先核两行变一空态行、阻断筛选和空导航，再用真实高分辨率画面与第一方 Vision 中文 OCR 确认空态标题；公开 accessibility/automation 子树保留诊断，不能把宿主未物化的 SwiftUI 虚拟元素当作产品缺失。额外保存 regression-compact-filtered-empty 附件，不抵扣 25 图矩阵。随后调用生产新建动作，核对清筛选、新 ID、标题/正文与 JSON 持久化。宽窄切换只改变包含式 hosting 画布及 traits，系统窗口保持 scene 原生几何；iOS16.4 起只对该合成画布清除 safeAreaRegions，保留 split、同篇、回 compact、筛选及删除断言，不强制同步布局。它是 UIKit host/delegate 与合成宽度证据，不声称物理触屏、真实 iPad 旋转或交互返回手势实测。
- 焦点：通过 DEBUG probe 设置生产标题 FocusState 并同时确认绑定和真实输入 first responder，再使用与按钮相同的生产完成/预览/写作 action，断言实际 responder、标题焦点、正文内容与选区；保留标题高度变化及正文单/双栏身份测试。现有焦点用例直接调用生产 sceneActions，继续断言真实 first responder；补同一固定句柄切换当前 entry/宽窄布局、旧篇不变、清目标后全部句柄无操作、弱引用不保活 router。旧辅助方法仅证明目标模型边界；新增可变绑定宿主还直接执行切篇与真实 UI 离场，继续检查旧命令无操作。不是中文输入法完整实测。
- 组合输入跨篇：生产正文 bridge 仅按 entry UUID 重建，同篇宽窄/单双栏保留身份；卸载先失效 coordinator、清 delegate/缩进闭包再结束 responder，拒迟到文本/选区/焦点。真实 key-window host 用原生 setMarkedText，先证同篇组合保留，再切篇核独立 input/coordinator、旧 delegate 为空、新篇内容不变、迟到回调不改两篇、切回仍保留原内容。另先证明 bridge 能真实取得与释放焦点，再同步排队 focus 并卸载，检查排队取消与零新 setter；不是物理键盘或完整中文 IME 验收。
- 有界派生：逐字段与旧 JournalEntryBodySummary 截断路径对照，覆盖 CR/LF/CRLF/Unicode newline、任务标记任意位置、空白、组合字符/emoji/区域指示符、fenced code、长内容和确定性混合输入。旧纯入口保留；新路径不物化全文摘要或小节 Markdown。
- 性能附件：`performance-bounded-body-derivation` 记录同一约 160k 字符/40 小节 Debug 正文，旧/新各 3 次 ContinuousClock 毫秒和中位数，先断言完整投影等价；不设不稳定耗时阈值，不把它当 UI 帧率、真实输入延迟或分配测量。
- 安全：真实临时 JSON 读取失败后 create/update/delete/import/flush 均不改原字节，关 alert 不能解锁；首次加载只有明确 NSFileReadNoSuchFileError 才建示例库；真实 POSIX 不可访问目录不建库、不调用 writer，保护重读遇到原文件移走也不建替代。原始恢复导出不受 25 MiB 导入上限限制，逐字节核对超限坏文件。重读成功和合法空库可写，重复 ID、无效导入、stale 预览及冲突均无静默覆盖。原 revision/debounce/actor 保存回归保留。
- 应用锁：可注入系统认证协议测试启用/关闭/失败/后台/迟到结果/请求重叠；生产 Gate 先呈现真实 sheet，再锁定并检查 UIWindow 顶层 shield。同一窗口 scene 的失活必须同步遮挡、后台立即锁定，激活仍需认证；无关 scene 通知不能影响本窗口。截图捕获整个 window。假认证用于确定性边界，不声称真实 Face ID/设备密码已验收。
- 场景命令：内容与编辑都使用原生 FocusedObject，不再发布函数型 focused values。生产焦点用例使用真实可变绑定，保留原焦点和选区断言，增加切篇后的 router 身份、旧命令只修改新篇以及真实离场后旧句柄无操作。新增内容 router 回归检查动态筛选/导航边界、新建清筛选、空路径不意外推详情、离场与释放。
- 后台保存：注入有限后台执行时间服务，检查同步申请、同 Store 在途去重、完成与系统到期竞争的幂等释放、申请失败仍 flush。测试不等待真实系统后台时限，不承诺强制终止或任意大 JSON 下必然落盘。新增命令与后台两项，先使声明数从 306 增至 308；程序化输入桥回归再增 1 项，取消/验签拆为独立测试再增 1 项，原到此共 310 项；marked-text 跨篇回归再增 1 项，当前共 311 项，云端必须全数执行且无跳过。
- 订阅：纯权益测试拒绝未知商品、未验证、到期、撤销、升级，处理有限宽限期。StoreKitTest 从测试 bundle 的 `.storekit` 配置创建真实本地会话，执行生产 purchase/restore/refund/待批准/冷启/到期/取消及自动 transaction listener。取消要求真实注入读回、无错误文案和购买状态复位。签名失败先要求实际成功购买取得 Pro 和期限，再注入 invalidSignature 并用 forceRenewalOfSubscription 生成新周期，仅在 nil/旧 ID 时有界等传播，严格核对 Transaction.latest 与 currentEntitlements 返回同一新 ID 的实际 `.unverified`、正确 SKU、`.xcode` 和精确验证错误，最后由生产 refresh 拒绝权益；不构造验证结果、不用普通购买错误代替，该用例不覆盖 Product.purchase 的未验证文案分支。冷启动批准必须先有界等到 Pro 及非空期限，再执行到期，防止原本未授权时空过；退款同样等待真实状态传播。session、SDK await 与清理即时记录阶段，30秒轮询不是非协作 SDK 的硬中断，进程外 watchdog 仍计超时失败。不能以这些结果声称 Sandbox、真实付款或 App Store 商品已配置。
- 无权益目录回归：新增一项从真实 SKTestSession 加载两项 Product 的集成测试，注入空当前权益 reader，断言不查询仅来自目录的组且没有 Pro/到期日。该 reader 只控制“没有已验证当前交易”的边界，不冒充真实交易覆盖；原生产 reader 的购买、恢复、退款、批准、验签和无目录冷启宽限期测试全部保留。总数由301增至302。Apple currentEntitlements 明确包含 subscribed/inGracePeriod 自动续期交易，status(for:) 对从未订阅组返回空数组；见官方 [当前权益](https://developer.apple.com/documentation/storekit/transaction/currententitlements) 和 [组状态](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/status(for:))。
- 到期挂起回归：再增一项注入时钟与受控 continuation 的确定性测试，总303项。先合法授权，在实际截止时刻开始刷新并暂停当前权益响应，断言首次 await 期间已撤权，再恢复当前权益并暂停组响应、重复检查；恢复有限已验证宽限期后可重新授权，有效宽限期刷新期间保持权限，等待中跨过截止则出口校验立即拒绝，返回后也不提交过期结果。没有墙钟 sleep，所有 continuation 显式恢复并等待任务结束。此为生产 Store/统一权限检查的可控边界测试，不声称重现真实网络挂起或已执行文件导出 UI 动作。
- 宿主前置条件：仅 DEBUG 且存在 XCTest 配置或运行时 XCTestCase 的宿主，默认窗口使用 Color.clear，不调用生产根内容闭包，避免恢复闭包持有的原 App 焦点/隐私树继续参与同 scene 更新。首个 NavLink 用例显式安装真实 JournalPrivacyGate → ContentView，锁来自独立 UserDefaults suite 并关闭，订阅不自动启动；从被测 UIWindowScene.activationState 初始化，并按同一 scene 的 didActivate/willDeactivate/didEnterBackground/willEnterForeground 通知传入 Gate 的 scenePhase；不依赖独立 UIHostingController 的默认环境、不固定 active。有界等待真实 scenePhase.active、前台 window scene、生产锁策略无需覆盖及实际 UIView 无窗口盾。SwiftUI 虚拟 AX 未物化不算安全证据；覆盖条件由真实 phase 与生产策略确认。普通 DEBUG 启动与 Release 保持完整根视图。所有原导航、焦点、安全和截图断言保留；该隔离是否消除挂起须由新云端结果判断。
- 交易前置条件：同一 DEBUG XCTest 宿主关闭 App 全局 Store 的自动启动与回前台订阅刷新，避免真实 Sandbox 查询先于 SKTestSession 配置。测试显式构造的 Store 仍正常调用生产代码，自动监听用例继续使用 startsAutomatically=true。普通 DEBUG 启动与 Release 不走隔离；不把空宿主当作已证明的 StoreKit 停滞根因。
- 本地商店预检：在任何商品查询和 UI 前由真实 SKTestSession 清空交易，直接枚举 Transaction.currentEntitlements 并要求空快照结束；随后走生产商品/购买路径，断言 verified 交易的 environment == .xcode 和有效 Pro。独立运行一次后仍属于完整 311 项的一部分，不替换原真实交易回归。
- 导出：日期/时区/分类过滤、分块 UTF-8 与静态 Markdown 精确等价（含跨块 Unicode/CRLF）、取消任务抛 CancellationError、空选择拒绝、CoreText 多篇长文分页与最后一页末尾正文保留；导出 actor 不改 Store，生成前后需有效 Pro，失效取消输出。旧免费功能不付费墙。

## 25 张图片矩阵

保留原 16 图：完整 regular ContentView 1360×860 和 1120×720、双栏 1440×900、手机编辑 390×720 浅/深色与辅助字号、844×320 低高度、320×900 资料库浅/深色/历史滚动/辅助字号、1100×900 与手机 390×900 统计、390×720 预览与空态。

新增均 390×844：compact 完整资料库、真实打开后的 detail；设置浅色与 accessibility3；隐私页；真实 presented sheet 之上的深色锁；StoreKit 真实商品的 Pro 方案页、verified 有效 Pro 导出页；无商品 accessibility3。方案图在加载完成后、购买前截取，最后一张滚动到 fallback，以便检查实际不可购及恢复入口。图片仅证明对应云端 iOS 渲染，不代表真机、Mac 窗口或 VoiceOver。

## 3 张商店尺寸素材

既有导航用例完成全部原断言后，恢复当前 iPhone scene 原生 393×852pt 窗口，核实屏幕 3x、转场和全宽稳定，直接渲染详情与 pop 后的资料库为 1179×2556。既有界面渲染用例另以 1366×1024pt 完整生产 ContentView regular 画布直接生成 2x 的 2732×2048 素材。原 25 图名称、像素和断言不变，额外图片不替代任何一张回归图。

`script/package_store_screenshots.py` 从真实 xcresult 附件清单提取 `appstore-*`，复制原字节至 `app-store-screenshots/`，不改变像素。index 记录同 branch/SHA/run/attempt、测试来源、尺寸、SHA256、演示内容及未上传状态。iPhone 是原生云端窗口渲染，iPad 是完整生产视图画布，不能用后者声称 iPad 设备运行或旋转已验收。下载后须逐图检查，尺寸合格不代替视觉审核。官方可接受尺寸及上传边界见 [发布配置](../../docs/app-store-release.md)。

## 独立现代 SDK 发布 job

`ios-release` 与功能 job 并行，在同一 SHA 使用 macos-15/Xcode26.2/iPhoneOS26.2 执行：

```sh
bash script/archive_ios_release.sh "$GITHUB_WORKSPACE/ios-release-results"
```

只对 `generic/platform=iOS` 构建 Release archive，SWIFT_OPTIMIZATION_LEVEL=-O、run number/attempt build number、CODE_SIGNING_ALLOWED=NO，不启动或选择模拟器。脚本验证实际 Mach-O arm64、iOS device 平台、SDK >=26、Info 中的 Xcode/SDK、iOS16 deployment target、图标/Assets、PrivacyInfo UserDefaults CA92.1、不跟踪/收集、Face ID 用途及系统豁免加密声明、私有目录未开放文件共享，以及最终 App 中的两项公开 HTTPS 链接和两项不同商品 ID；记录每个 archive 文件 SHA256 与 ZIP SHA256。

结果为 `MDJournal-iOS-unsigned.xcarchive.zip`、release xcresult、日志、manifest、JUnit 和 failure summary。Manifest 明确 unsigned、未执行上传，不能把结构验证当作签名或商店审核。正式发布还需要真实开发者团队和 Distribution/provisioning；详见 docs/app-store-release.md。

## 最新结果包核对

确认当前 main 和同仓库 origin/main，`git fetch origin` 后锁定最新完整 SHA。使用已有有效 gh 授权安全登录，不打印 token；下载缓存 `/private/tmp/mdjournal-c-review-<run_id>/` 或按 job 区分子目录。

必须核对两个 artifact 的 branch/commitSha/runId/runAttempt/workflow/version、GitHub digest 与大小、本地 ZIP SHA256、未加密 flag、CRC、独立解压与逐文件哈希。功能包核六阶段 JUnit、四份主 xcresult 及两份预检 xcresult 和具体新增测试、25 图逐张；release 包核实际 archive SDK/平台/架构/资源和内部清单，重新只读执行 verifier 不启动 App。提取性能 JSON 并按实际值记录，不预填更快。

失败回到负责模块追加最小修复并推 main，不回滚用户数据。同因 CI 连续失败、连续三轮同阻塞、连续两轮无有效 diff、未知冲突或账号权限需求按入口规则停止/求取必要人工信息，不无限重跑。完整结果写入 update_log.md；任何后续新 SHA 都需要自己的云端结果。

工具链变更后的 run40169268199 已下载核对：StoreKit 预检 1/1 通过、现代设备 archive 通过，但导航仍触发 Observation tracking feedback loop，完整回归未执行。新采样仍捕获 insertMarkdownSnippetAction setter，证实仅固定函数闭包没有解决问题。本轮统一改原生稳定 FocusedObject，并保留同一 Xcode26.2/iOS26.2 既有设备、全部断言与门槛；不得把旧包或预检当作新完整结果。iOS16 最低部署配置保持，最低系统真机运行仍需专项证据。


run40621962623 的两个未加密 artifact 已主线程按同 SHA/run/attempt、API digest/大小、CRC、独立 gh 下载逐文件 SHA256 核对；实际预检 1/1 与 2/2、完整 306/308、25 图及 3 素材，不能放行。输入桥新增真实 host 用例检查初始 NSNotFound 只在 UIKit 中规范化、外部正文与选区同步不触发任何 Binding setter、同一 UITextView 保持，以及用户选区精确回写一次。原切篇用例先等待新篇 UTF-16 末尾，再与纯插入算法的完整正文及选区精确比较。取消和签名错误场景在各自清理后的新 SKTestSession/Store/Product 上执行，保留原全部交易断言，不靠重试吞错。当前新 SHA 仍须全数 311 项和所有构建/图片门槛通过。


### 当前针对性预检与 Binding 边界

run40624082017 已核对为303/309且无跳过，程序化状态与导航反馈警告均为0。焦点诊断直接显示旧篇已被修改、新篇未改变，不能再以延长选区等待解释。完整命令target改由稳定外层task(id:)捕获当前渲染Binding，拒已取消任务并以当前正文设UTF16末尾；旧onChange仅清不匹配目标，不可读旧正文或装旧Binding。安装保留最新layout，GeometryReader只传Equatable布局，不能恢复旧篇绑定。保留正向切篇的完整正文/UTF16选区断言，追加切回后的只改当前篇、layout-only不覆绑定和真实离场无操作。

同方法双SKTestSession方案被实际Device verification / Missing transaction data / File not found否定，取消与验签改为两个独立方法，每方法只有单一会话。两者都注册异步teardown，显式清purchase和verification模拟错误并读回nil，失败记XCTFail而非吞错，最后才清交易/reset。原真实verified交易、Pro期限、精确invalidSignature及生产撤权断言全部保留。

云端原有两份预检xcresult继续保留：商店3项为空快照/xcode购买、取消、验签；界面4项为原两项导航、真实焦点/双向切篇及marked-text跨篇。任一组失败都阻止完整311项与发布放行，另一组仍取证，不盲跑全套；商店3/3与导航/输入4/4成功才跑完整声明数、25图/3素材和两平台/Release。账号团队正式签名按人工要求后置，不阻塞软件验证，也不能伪称已上传。

最新 run40628750871/attempt1 两包已下载并核同 SHA、digest/大小、未加密、CRC 和独立下载逐文件哈希。商店预检真实 3 项 2pass/1fail，失败为注入后 Transaction.latest 未返回预期 unverified；不是取消或真实购买失败。GitHub 阶段状态滞后导致主线程误判并取消，导航前两项通过、焦点切篇触发旧 Binding 断言，完整回归未完成；准备实际成功、test build 成功，不能把状态延迟当模拟器卡死根因。设备 archive succeeded、0error/0warning，仍 unsigned。下一 SHA 需完整 311 项与原图片/平台构建门槛。
