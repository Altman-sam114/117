# 项目核心流程

## 自主迭代与恢复

用户给出目标后，由当前模型自行定位源码、拆解任务、实现、自查和验收，不设置角色交接，也不默认创建子智能体。先读取根目录 [AGENTS.md](../../AGENTS.md)、[work.md](../../work.md) 和 Git 状态；按需要再读相关架构、测试和历史记录。

任务开始即把目标、边界、验收标准、分步计划、起点 SHA、编辑范围、测试选择与下一步写入工作台，每完成一步更新。上下文压缩后先读工作台并核对实际 diff/远端/云端状态再继续；云端待完成或阻塞时保留记录，任务验收结束后把必要证据移入更新日志，再清空工作台，不累积历史计划。

默认 `main` 直推，云端验证由模型按本轮直接和必要关联影响主动 dispatch。纯文档检查链接与 diff 即可；构建、XCTest、App/模拟器运行、性能采集和归档未经用户特别要求不得在本机执行。详细选择规则见 [测试规范](../test/test.md)。

## 应用与状态所有权

外观与排版使用 app-owned UserDefaults / AppStorage，只存偏好，不写入日记 JSON。每个生产窗口由 journalPreferences 注入同一环境值与 preferredColorScheme，设置可免费修改字体/字号/行距。UIKit 正文只在样式改变或外部替换正文时应用段落属性，marked text 期间推迟任何字体/段落更新，已存在的 UTF-16 选区与输入实例不因此替换；预览复用相同字体与辅助字号。

`MDJournalApp` 创建共享的 `JournalStore`、`JournalSubscriptionStore` 和 `JournalAppLockStore`。主窗口以及 Catalyst 统计窗口均经过 `JournalPrivacyGate` 并注入同一权益/应用锁对象；App 回到活跃态刷新订阅权益。没有日记服务器或登录账号。

仅 DEBUG 的 XCTest 宿主默认窗口返回空根视图，不调用生产内容闭包，避免原 App 树在夹具临时替换 root 后仍被恢复闭包保留。专项用例显式安装各自的真实生产视图；首个手机导航用例组合 JournalPrivacyGate 与 ContentView，注入独立关闭的锁和不自动启动的订阅 Store，等待真实 scenePhase 活跃、window scene 前台且无需隐私遮罩后才导航，不伪设 active。宿主同时关闭全局订阅 Store 的自动查询和 scenePhase 刷新，避免本地测试会话建立前查询 Sandbox；交易测试仍显式使用真实 StoreKit Store、Product 和 transaction listener。普通开发启动与 Release 保持完整生产视图和正常自动启动路径。

`ContentView` 拥有 selectedEntryID、搜索、分类、sheet 与原生 UUID 导航数组。手机 compact 的 NavigationStack 直接绑定 `@State compactEntryPath`，首次展示资料库，NavigationLink 和系统返回直接更新该数组；不由选中项加布尔标志在 getter/setter 中反推路径。compact 以实际路径为准同步有效选中，选中 observer 仅在 regular 回写已呈现目标，两者都拒绝过时回调；相邻命令和筛选/删除修复显式同步，空路径保持资料库。compact 列表不安装原生 selection 绑定，行高亮仍消费 selectedEntryID，避免列表 diff 的选择回写与导航路径竞争。系统返回保留有效选择，能够再次打开同篇。常规宽度和 Catalyst 使用 NavigationSplitView，继续保留原生列表 selection。

新建经过 `JournalStore.createEntry() -> ID?`，失败不清筛选、不伪造 ID；成功后清搜索和分类并选中真实新 ID，compact 打开详情。筛选、删除及 Store 发布按当前可见日记修复 selection，空结果解除无效详情。相邻导航沿当前可见顺序，首尾不循环。

列表按同一 Calendar/Locale 派生年月 Section，行只持有可见标量投影；Equatable 不比较正文或小节数组。context menu/swipe 先进入统一删除确认，确认后才回到 Store。设置和统计由单一 sheet 枚举管理；Catalyst 统计保留独立窗口。

## 日记与持久化

保存状态由 Store 持有：载入成功为 saved，真实 mutation 后为 saving，只有当前 revision 的写盘确认才回到 saved，当前失败为 failed，读取错误为 readProtected。关闭提示不改变状态；编辑器/设置和错误弹窗都提供实际 flush 重试。无变化的标题/正文/日期/分类/心情回写（包括仅更新时间戳）不发布集合、不派生、不增 revision、不延后已有 debounce；迟到旧保存结果不能改变当前状态。

JournalEntry 保持原有 Codable 格式、分类/心情兼容解码和 ISO-8601 日期。JSON 位于私有 Documents/md-journal-entries.json。

Store 是唯一集合修改入口：加载/创建构建正文展示投影，正文变更只重建当前篇，元数据更新复用，删除释放。展示投影只保留词数、可见性、有限摘要和小节信息；生产有界派生不先保留完整 summary 或 section markdown，旧纯 summary API 保留作语义对照。完整词数仍扫描全文，统计/概览仍聚合元数据，不宣称整体常数复杂度。

更新先同步发布内存，再以 450ms debounce 合并保存；创建、删除、确认合并导入立即提交快照。JournalPersistenceWriter actor 串行 JSON 编码及 atomic 写入，以 revision 拒绝过时请求。iOS 使用首次解锁后可访问的系统文件保护；这允许设备首次解锁后的锁屏保存，不是自定义密码加密。离开活跃态同步调用 Store.flushForBackground，先申请有限系统后台执行时间、再异步 flush；共享 Store 只保留一个在途任务，完成与系统到期幂等释放，申请失败也照常尝试保存，不无限续期。系统到期不伪造写入结果，也不能中断 actor 内编码；强制终止和超大文件仍无必然保存保证。durableRevision、写入错误仲裁和重试规则保持。生产编辑器消费当前 Store 的真实保存状态，不用存储位置冒充写入成功；系统设备备份可能包含用户日记。

读取异常或重复日记 ID 设置独立 readFailureMessage，原文件保持不动。关闭错误 alert 只关闭展示，不清写保护；create/update/delete/import/flush 均拒绝写入。设置提供原始字节恢复导出及重新读取，只有完整解码和校验成功才解除保护。不存在文件与合法空数组仍可正常创建。

## 备份与安全合并

设置的免费 JSON 导出从当前完整内存快照在后台编码，原正文和元数据不截断。导入通过系统文件选择器和 security-scoped resource 读取；25MiB/10,000 篇上限、合法 JSON、兼容模型与唯一 ID 均先校验，不改变 Store。预览显示新增/保留数量和有限列表。

用户确认后，Store 检查预览 revision、再次校验 ID，跳过所有本机已存在 ID，只追加新 ID，以一次 mutation/快照写入；预览期间本机变化则拒绝并要求重新选择，不静默覆盖任何日记。失败、取消及只预览都不改集合。导入写盘失败明确展示内存已合并而磁盘失败，不假称已安全保存。

## 应用锁与隐私

JournalAppLockStore 默认关闭，偏好只存本应用 UserDefaults。启用、关闭与解锁均通过 LAContext.deviceOwnerAuthentication，系统可选择 Face ID、Touch ID 或设备密码。应用不接收生物特征或设备密码。generation 防止后台或新请求后迟到的认证结果解锁；后台取消在途认证并锁定，inactive 只遮挡以免取消系统验证页。

隐藏多任务预览独立且默认开启，不要求应用锁或购买；非活跃时同一窗口级遮罩覆盖内容及 sheet，回到活跃态在未开启锁时直接恢复、不调用认证。用户可关闭该预览偏好，但不能用它绕过已开启的锁。预览遮罩不会阻止主动截屏/录屏或导出。

JournalPrivacyGate 保留底层视图结构，同时关闭交互与辅助访问并展示锁定内容。UIKit 窗口级 shield 在 willResignActive 同步遮挡、覆盖已呈现 sheet，首次遮挡收起键盘；同一 UIWindowScene 的 willDeactivate 同步遮挡，didEnterBackground 立即锁定并取消过期认证，didActivate 不能绕过锁，其他 scene 通知不影响本窗口。inactive 不取消系统验证。遮罩的纸面和解锁按钮使用应用的动态主题色。JSON 保存与遮罩独立，未增加第二份日记状态。

隐私页和公开政策说明本机存储、系统备份、主动导出、可选应用锁、Apple 支付和删除边界。PrivacyInfo.xcprivacy 声明不跟踪、不收集，UserDefaults 为本应用偏好使用 CA92.1。Debug/Release 均将显式 MDJournal/Info.plist 中的公开 HTTPS 链接与订阅商品 ID 合并进最终 App，其他系统键继续生成；archive verifier 检查最终值，不能只凭工程设置判断接线成功。最终 Info 包含 Face ID 说明，关闭文档共享，声明只使用系统豁免加密。

## 编辑与预览

标题节点保持固定位置并使用 FocusState，正文沿用 UIKit bridge。完成同时清除标题/正文焦点；进入预览也清除两者；聚焦正文、专注写作、插入与缩进命令先清标题再走原正文入口。正文桥先完成初始正文与 UTF-16 选区配置再安装 delegate；外部程序化更新期间只更新 UIKit，不回写 Binding，用户输入及选区回调照常发布。同篇的 UTF-16 范围、marked text 延迟覆盖和一次性正文/选区 token 保持；正文 bridge 按 entry UUID 隔离，切篇卸载先失效 coordinator 与排队焦点、清 delegate/缩进闭包再结束 responder。旧篇迟到回调不能触及任一篇，共享 workspace 不因布局变化重建。

低高度、辅助字号与宽度控制纸面和头部预算；单栏上限 760pt，实际详情 >=1120pt 且非辅助字号才双栏。单/双栏切换保留编辑器内部输入节点。分享用 Transferable 在实际导出时构造完整 UTF-8 Markdown，布局和选区更新不预先拼接全文。

MarkdownPreviewUpdateModel 的 document 与 inline cache 为同一 Published 快照。150ms trailing debounce、entry ID 与 generation 保证 latest-wins，隐藏/离开/切篇使旧请求失效。parser 保持轻量逐行 Markdown、### 小节与现有 fenced code 规则；预览只读结果，不保存日记。

## 订阅与高级导出

PDF 在用户选择时生成独立纸本封面，显示自定义名称（清理空白、最多 80 Character）、所选日期范围与篇数；正文逐篇分页及完整 Markdown 原文保持不变，封面不开启也可导出。封面与输出在同一个 actor 内生成，不触碰 Store，不放宽生成前后的权益核验。

JournalSubscriptionStore 通过真实 Product 查询白名单月/年自动续期商品，显示 Apple 本地化名称、价格和周期。没有商品或隐私链接时购买不可用，不伪造价格/成功。Transaction.updates 启动监听，verified 交易完成后刷新 currentEntitlements；未知商品、未验证、已撤销、已升级或无有效期限不能解锁。宽限期还需已验证 renewalInfo 且有限 grace 到期日。状态刷新用 generation，定时到期/回前台重查；恢复只在用户主动操作时 AppStore.sync，管理走系统订阅页。

组状态只查询 currentEntitlements 中已验证白名单交易给出的 subscriptionGroupID，不从可售商品目录补组。Apple 的 currentEntitlements 包含 subscribed 和 inGracePeriod 的自动续期交易，因此无目录的冷启宽限期仍能查询已验证 renewalInfo；终态仍覆盖旧交易。没有已验证当前交易时以空候选撤权，不为从未订阅的用户额外等待一个只会返回空数组的目录组查询。

刷新首次 await 前同步清除已到期的缓存权限，不取消正在执行的到期刷新任务；返回后重新读取当前时刻才提交状态。所有截止判断和定时器使用同一时钟，生产默认系统时间，测试可确定性推进。统一 hasPremiumAccess 同时核对 Pro 标志和包含有限宽限期的 accessExpirationDate，截止时刻严格拒绝。

Pro 增加批量 Markdown 日记集及 CoreText 真分页 PDF；Markdown 按 64 KiB UTF-8 块直接构建 Data，PDF 只对当前篇建立 framesetter、逐页释放临时对象，新篇从新页开始，两种格式均检查取消。单篇排版及最终输出仍使用内存。日期和分类过滤使用同一 Calendar，按日期从早到晚稳定排序。导出在 actor 生成，视图生成前后均调用 hasPremiumAccess，系统查询等待或生成期间到期不能沿用过期布尔缓存；撤销权益取消在途输出。没有改写 Store。基础写作、统计、单篇分享和 JSON 备份继续免费。

## 场景命令与数据恢复

内容与编辑命令分别由 StateObject 持有的 JournalContentSceneActions 和 EntryEditorSceneActions 管理，通过原生 focusedSceneObject / FocusedObject 传递稳定引用，不向焦点图发布函数型值。内容目标持 Store 与当前选择、筛选、路径绑定，执行时重读可见快照，菜单可用性仅在真实状态变化时发布 Equatable 标量。

编辑完整目标由稳定外层 task(id: entry.id) 捕获当前渲染绑定；取消任务拒安装，安装段不跨 await，选区从当前正文算 UTF-16 末尾，保留最新几何布局。旧 onChange 仅使不匹配目标失效，GeometryReader 只更新 Equatable 布局，不能重装旧 Binding；按钮和菜单共享 router，离场清空目标，应用锁逐次拦截操作。

首次加载只有明确文件不存在才创建示例，保护重读不创建替代文件；原字节恢复导出不受正常导入大小上限限制。系统认证完成只清自身 LAContext，迟到旧请求不能使新请求失去取消入口。

## 按范围云端验证与发布

`.github/workflows/ci-results.yml` 只提供 workflow_dispatch，不因 push 自动执行发布全套。模型先在工作台写明范围、原因和预期产物，再提交本轮文件、push 到 origin/main，并选择：

- `targeted`：指定精确 XCTest 类/方法、一个 Python fixture 文件或必要 Debug 构建平台；空选择失败。只跑所选检查和构建依赖，不执行无关商店/导航预检、图片或 Release 包。测试选择先对照源码校验，实际执行数必须匹配且零失败/跳过。
- `full`：有发布或跨层验收依据时，显式运行原完整门槛：静态与 Python、固定云端工具链/既有 iPhone、商店与导航/输入预检、全部声明 XCTest、审查图和商店素材、iOS/Catalyst Debug 与 universal Mac Release；独立 job 同 SHA 执行 generic iOS unsigned Release archive。完整模式不接受局部过滤，不借局部测试放行发布。

所选阶段必须成功，范围外阶段写入 notSelectedStages，不冒充通过。流程相关脚本变更可只跑直接 fixture，不启动 App 或模拟器；共享模块变更补必要上下游验证，而不是机械覆盖所有模块。针对性配置不提供的产物若确有需要，应先补最小相关入口，不能仅因全套现成就跑无关检查。

下载本次精确 branch/SHA/run/attempt/profile 的未加密结果包，核对 manifest、所选阶段 JUnit、实际测试摘要、主日志和任务所需产物；需要图片时逐图检查，需要归档时核 SDK/平台/架构/配置。结果有缺失或失败就追加最小修复，保留日志，不回滚用户数据、不放宽断言。验证后仅改文档、日志或清空工作台不重复 App 回归，记录实际被测 SHA，不能把它改写成后续文档 HEAD 的结果。

云端工具链、设备准备、超时和证据边界见测试规范，具体历史 run/产物见 [更新日志](../../update_log.md)。StoreKitTest 不等于 Apple Sandbox；iPad 合成画布不是 iPad 设备运行；unsigned archive 和 ad-hoc Mac 包不等于正式签名、公证、上传或审核。账号、团队和正式签名后置，不阻塞可执行的软件验证，发布步骤见 [发布配置](../../docs/app-store-release.md)。
