# 项目核心流程

## 当前执行方式

v0.95 按用户最新要求分模块并行：手机导航/编辑与性能、设置/隐私/数据安全、StoreKit/高级导出分别实施，主线程集成工程、发布构建和文档。统一 main 提交直推 origin/main，云端两个 job 并行验证，再由主线程或交叉审查者下载最新同 SHA/run/attempt 结果包。此方式覆盖旧的 A→B→C 串行开工门槛，仍保留数据安全、轻量本机检查与真实云端证据要求。

## 应用与状态所有权

`MDJournalApp` 创建共享的 `JournalStore`、`JournalSubscriptionStore` 和 `JournalAppLockStore`。主窗口以及 Catalyst 统计窗口均经过 `JournalPrivacyGate` 并注入同一权益/应用锁对象；App 回到活跃态刷新订阅权益。没有日记服务器或登录账号。

仅 DEBUG 的 XCTest 宿主默认窗口返回空根视图，不调用生产内容闭包，避免原 App 树在夹具临时替换 root 后仍被恢复闭包保留。专项用例显式安装各自的真实生产视图；首个手机导航用例组合 JournalPrivacyGate 与 ContentView，注入独立关闭的锁和不自动启动的订阅 Store，等待真实 scenePhase 活跃、window scene 前台且无需隐私遮罩后才导航，不伪设 active。宿主同时关闭全局订阅 Store 的自动查询和 scenePhase 刷新，避免本地测试会话建立前查询 Sandbox；交易测试仍显式使用真实 StoreKit Store、Product 和 transaction listener。普通开发启动与 Release 保持完整生产视图和正常自动启动路径。

`ContentView` 拥有 selectedEntryID、搜索、分类、sheet 与原生 UUID 导航数组。手机 compact 的 NavigationStack 直接绑定 `@State compactEntryPath`，首次展示资料库，NavigationLink 和系统返回直接更新该数组；不由选中项加布尔标志在 getter/setter 中反推路径。compact 以实际路径为准同步有效选中，选中 observer 仅在 regular 回写已呈现目标，两者都拒绝过时回调；相邻命令和筛选/删除修复显式同步，空路径保持资料库。compact 列表不安装原生 selection 绑定，行高亮仍消费 selectedEntryID，避免列表 diff 的选择回写与导航路径竞争。系统返回保留有效选择，能够再次打开同篇。常规宽度和 Catalyst 使用 NavigationSplitView，继续保留原生列表 selection。

新建经过 `JournalStore.createEntry() -> ID?`，失败不清筛选、不伪造 ID；成功后清搜索和分类并选中真实新 ID，compact 打开详情。筛选、删除及 Store 发布按当前可见日记修复 selection，空结果解除无效详情。相邻导航沿当前可见顺序，首尾不循环。

列表按同一 Calendar/Locale 派生年月 Section，行只持有可见标量投影；Equatable 不比较正文或小节数组。context menu/swipe 先进入统一删除确认，确认后才回到 Store。设置和统计由单一 sheet 枚举管理；Catalyst 统计保留独立窗口。

## 日记与持久化

JournalEntry 保持原有 Codable 格式、分类/心情兼容解码和 ISO-8601 日期。JSON 位于私有 Documents/md-journal-entries.json。

Store 是唯一集合修改入口：加载/创建构建正文展示投影，正文变更只重建当前篇，元数据更新复用，删除释放。展示投影只保留词数、可见性、有限摘要和小节信息；生产有界派生不先保留完整 summary 或 section markdown，旧纯 summary API 保留作语义对照。完整词数仍扫描全文，统计/概览仍聚合元数据，不宣称整体常数复杂度。

更新先同步发布内存，再以 450ms debounce 合并保存；创建、删除、确认合并导入立即提交快照。JournalPersistenceWriter actor 串行 JSON 编码及 atomic 写入，以 revision 拒绝过时请求。iOS 使用首次解锁后可访问的系统文件保护；这允许设备首次解锁后的锁屏保存，不是自定义密码加密。离开活跃态同步调用 Store.flushForBackground，先申请有限系统后台执行时间、再异步 flush；共享 Store 只保留一个在途任务，完成与系统到期幂等释放，申请失败也照常尝试保存，不无限续期。系统到期不伪造写入结果，也不能中断 actor 内编码；强制终止和超大文件仍无必然保存保证。durableRevision、写入错误仲裁和重试规则保持。界面的“仅在本机”不是已落盘声明，系统设备备份可能包含用户日记。

读取异常或重复日记 ID 设置独立 readFailureMessage，原文件保持不动。关闭错误 alert 只关闭展示，不清写保护；create/update/delete/import/flush 均拒绝写入。设置提供原始字节恢复导出及重新读取，只有完整解码和校验成功才解除保护。不存在文件与合法空数组仍可正常创建。

## 备份与安全合并

设置的免费 JSON 导出从当前完整内存快照在后台编码，原正文和元数据不截断。导入通过系统文件选择器和 security-scoped resource 读取；25MiB/10,000 篇上限、合法 JSON、兼容模型与唯一 ID 均先校验，不改变 Store。预览显示新增/保留数量和有限列表。

用户确认后，Store 检查预览 revision、再次校验 ID，跳过所有本机已存在 ID，只追加新 ID，以一次 mutation/快照写入；预览期间本机变化则拒绝并要求重新选择，不静默覆盖任何日记。失败、取消及只预览都不改集合。导入写盘失败明确展示内存已合并而磁盘失败，不假称已安全保存。

## 应用锁与隐私

JournalAppLockStore 默认关闭，偏好只存本应用 UserDefaults。启用、关闭与解锁均通过 LAContext.deviceOwnerAuthentication，系统可选择 Face ID、Touch ID 或设备密码。应用不接收生物特征或设备密码。generation 防止后台或新请求后迟到的认证结果解锁；后台取消在途认证并锁定，inactive 只遮挡以免取消系统验证页。

JournalPrivacyGate 保留底层视图结构，同时关闭交互与辅助访问并展示锁定内容。UIKit 窗口级 shield 在 willResignActive 同步遮挡、覆盖已呈现 sheet，首次遮挡收起键盘；同一 UIWindowScene 的 willDeactivate 同步遮挡，didEnterBackground 立即锁定并取消过期认证，didActivate 不能绕过锁，其他 scene 通知不影响本窗口。inactive 不取消系统验证。遮罩的纸面和解锁按钮使用应用的动态主题色。JSON 保存与遮罩独立，未增加第二份日记状态。

隐私页和公开政策说明本机存储、系统备份、主动导出、可选应用锁、Apple 支付和删除边界。PrivacyInfo.xcprivacy 声明不跟踪、不收集，UserDefaults 为本应用偏好使用 CA92.1。Debug/Release 均将显式 MDJournal/Info.plist 中的公开 HTTPS 链接与订阅商品 ID 合并进最终 App，其他系统键继续生成；archive verifier 检查最终值，不能只凭工程设置判断接线成功。最终 Info 包含 Face ID 说明，关闭文档共享，声明只使用系统豁免加密。

## 编辑与预览

标题节点保持固定位置并使用 FocusState，正文沿用 UIKit bridge。完成同时清除标题/正文焦点；进入预览也清除两者；聚焦正文、专注写作、插入与缩进命令先清标题再走原正文入口。正文桥先完成初始正文与 UTF-16 选区配置再安装 delegate；外部程序化更新期间只更新 UIKit，不回写 Binding，用户输入及选区回调照常发布。UTF-16 范围、marked text 延迟覆盖、一次性正文/选区 token 和异步焦点代数不改变。

低高度、辅助字号与宽度控制纸面和头部预算；单栏上限 760pt，实际详情 >=1120pt 且非辅助字号才双栏。单/双栏切换保留编辑器内部输入节点。分享用 Transferable 在实际导出时构造完整 UTF-8 Markdown，布局和选区更新不预先拼接全文。

MarkdownPreviewUpdateModel 的 document 与 inline cache 为同一 Published 快照。150ms trailing debounce、entry ID 与 generation 保证 latest-wins，隐藏/离开/切篇使旧请求失效。parser 保持轻量逐行 Markdown、### 小节与现有 fenced code 规则；预览只读结果，不保存日记。

## 订阅与高级导出

JournalSubscriptionStore 通过真实 Product 查询白名单月/年自动续期商品，显示 Apple 本地化名称、价格和周期。没有商品或隐私链接时购买不可用，不伪造价格/成功。Transaction.updates 启动监听，verified 交易完成后刷新 currentEntitlements；未知商品、未验证、已撤销、已升级或无有效期限不能解锁。宽限期还需已验证 renewalInfo 且有限 grace 到期日。状态刷新用 generation，定时到期/回前台重查；恢复只在用户主动操作时 AppStore.sync，管理走系统订阅页。

组状态只查询 currentEntitlements 中已验证白名单交易给出的 subscriptionGroupID，不从可售商品目录补组。Apple 的 currentEntitlements 包含 subscribed 和 inGracePeriod 的自动续期交易，因此无目录的冷启宽限期仍能查询已验证 renewalInfo；终态仍覆盖旧交易。没有已验证当前交易时以空候选撤权，不为从未订阅的用户额外等待一个只会返回空数组的目录组查询。

刷新首次 await 前同步清除已到期的缓存权限，不取消正在执行的到期刷新任务；返回后重新读取当前时刻才提交状态。所有截止判断和定时器使用同一时钟，生产默认系统时间，测试可确定性推进。统一 hasPremiumAccess 同时核对 Pro 标志和包含有限宽限期的 accessExpirationDate，截止时刻严格拒绝。

Pro 增加批量 Markdown 日记集及 CoreText 真分页 PDF；Markdown 按 64 KiB UTF-8 块直接构建 Data，PDF 只对当前篇建立 framesetter、逐页释放临时对象，新篇从新页开始，两种格式均检查取消。单篇排版及最终输出仍使用内存。日期和分类过滤使用同一 Calendar，按日期从早到晚稳定排序。导出在 actor 生成，视图生成前后均调用 hasPremiumAccess，系统查询等待或生成期间到期不能沿用过期布尔缓存；撤销权益取消在途输出。没有改写 Store。基础写作、统计、单篇分享和 JSON 备份继续免费。

## 云端执行与发布边界

main push 同时触发：

1. macos-15/Xcode26.2/iOS26.2：31 项纯 Python fixture、静态检查、既有设备准备、MDJournalCI 专用 StoreKit test plan、独立 build-for-testing、真实空快照及 .xcode 购买环境/取消/验签三项预检、两项导航和一项真实焦点/切篇预检（任一失败拒绝完整验收，两者都取证）、同 UDID 串行全部 310 项 XCTest、25 图与 3 张商店尺寸素材导出核对，再做 iOS/Catalyst Debug 与 universal Mac Release 内部包。手机生产 host 临时使用既有 key window 的根控制器槽位并恢复；所有导航测试只改变包含式画布及 traits，不改系统窗口原生几何。Gate 夹具从同一真实 UIWindowScene 的状态及通知映射 scenePhase，单栈转场必须填满 hosting 画布。新建先核筛选、空导航和真实空态画面文字；详情图等待转场完成。交易回归先确认真实授权再执行到期或签名失败，后者核对 SDK 实际未验证结果和生产 reader 撤权，不冒充购买错误文案覆盖。测试或图片失败时跳过重复平台构建，终门继续要求六阶段全成功，不减验收；运行期间每 25 秒保存存活宿主 2 秒有界采样，测试命令失败后保存仍存活宿主的有界采样和可用 xcresult 诊断。保留原 257 项测试和 16 图，新增生产导航/焦点、保护/导入/认证、交易/导出和有界派生证据。
2. macos-15/Xcode26.2/iPhoneOS26.2：generic iOS Release archive，不使用模拟器；核 arm64/device平台、实际 SDK、版本、图标、PrivacyInfo/FaceID/加密说明与全部文件哈希，生成 unsigned xcarchive ZIP、manifest、JUnit、日志和 xcresult。

最终下载两个最新 artifact，核同 SHA/run/attempt、未加密、digest/CRC/独立解压哈希、各阶段日志及实际 XCTest/图片/商店配置结果。StoreKitTest 不等于 Apple Sandbox；unsigned archive 需要真实开发者团队、Distribution 签名与商店元数据才能上传，发布流程见 docs/app-store-release.md。没有正式账号配置、签名或审核证据时不宣布已发布。

功能包另从相同 308 项用例的附件直接打包 3 张商店尺寸 PNG：原生 iPhone 窗口 3x 的资料库/详情，以及完整 regular ContentView 画布 2x 的 iPad 素材。独立核尺寸、无透明通道、PNG 完整性、来源与摘要，不缩放原 25 张回归图；两套图片共同进入导出阶段门槛。iPad 画布素材不充当设备运行证据，正式发布前仍需对应设备检查。

首次本地加载直接读取，仅明确的文件不存在错误才创建示例；暂不可访问和解码失败保持独立写保护。保护重读从不建替代文件。恢复导出后台读取完整原字节，不沿用正常导入的 25 MiB 限制。系统认证完成只清除自身 LAContext 引用，迟到旧请求不会使新请求失去取消入口。

内容与编辑命令分别由 StateObject 持有的 JournalContentSceneActions 和 EntryEditorSceneActions 管理，通过原生 focusedSceneObject / FocusedObject 传递稳定引用，不再向焦点图发布函数型值。内容目标持 Store 与当前选择、筛选、路径绑定；动作执行时重新读取可见快照，菜单可用性仅在生命周期或真实状态变化时按 Equatable 标量发布。编辑完整目标只由稳定外层 onAppear / entry ID 回调安装，显式使用本轮当前 entry Binding，并持 workspace、titleFocus、details 绑定；ID 不匹配则清目标拒绝命令。GeometryReader 仅更新 Equatable 布局，绝不重建或覆写日记 Binding；按钮、菜单、插入与缩进都走同一 router。两者离场清空目标，旧命令不能修改离场文档，应用锁继续逐次拦截菜单操作。该改动针对实际采样中的 focused-values 布局反馈，新 SHA 仍需自己的云端运行证据。

本轮按人工最新指令只完成发布前软件，账号/开发者团队/正式签名后置；结果真实性与 unsigned 边界保持，不把后置账号当作软件回归阻塞。
