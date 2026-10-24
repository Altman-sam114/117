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

工作流还需逐 run 块 `bash -n`、所有内嵌 Python 与脚本 `ast.parse`；所有颜色/图标 JSON、StoreKit 配置 JSON 与资源注册检查。Swift parse 仅验证语法，不是类型检查。纯 Python 当前 15 项：8 项固定 runtime/已有设备选择，加 7 项 iOS archive 元数据/SDK/平台/隐私/公开链接/商品 ID 拒绝条件 fixture，不启动系统服务。

## 云端功能 job

`.github/workflows/ci-results.yml` 的 `ci-results` 固定 macos-15/Xcode16.4/iOS18.5：

1. 静态检查与纯 Python fixtures。
2. 读取可用设备 JSON，只在固定 runtime 中选一台已有 iPhone，Booted 优先，再 iPhone16；缺 runtime 或设备明确失败，不创建克隆、不回退别的系统。提前启动并记录 UDID/runtime/初始状态。
3. 先独立 build-for-testing 上限 600 秒；同一 UDID bootstatus 上限 240 秒；串行 test-without-building 上限 720 秒，不借机删测试、跳过或缩减门槛。启用 XCTest 进程外逐用例 watchdog，默认/最大 180 秒，四项生产导航/焦点 host 用例明确 60 秒，避免主线程循环阻止用例内等待超时后又耗尽整轮预算；超时仍计失败。
4. 导出 xcresult 附件，校验原 16 图及新增 9 图的名称、PNG、精确尺寸、manifest 和 index。缺任何一图使工作流失败。
5. 测试与图片成功后再运行 generic iOS Debug、Mac Catalyst Debug 和 universal Mac Catalyst Release 构建、图标/架构/签名/ZIP/文件内容与权限校验。Mac 为 ad-hoc 内部包，不代表公证或公开发布。

测试或图片失败时跳过重复平台构建，以更快获得失败包；终门仍要求全部六阶段 success，skip 不能放行。JUnit 表达六个工作流阶段，真正 XCTest 数来自 `xctest.log` 和 `MDJournalTests.xcresult`。测试汇总需核对全部测试实际执行、失败/跳过为零、新增交易和 host 回归的具体名称。成功结果包含四份 xcresult；失败包保留实际已执行并生成的 bundle、阶段日志、failure summary、设备选择与未加密 artifact。测试命令失败后，在清理宿主前对仍存活的 MDJournal 进程采样 3 秒，并尝试导出 xcresult diagnostics；各自有 15/30 秒外部上限，诊断缺失不会抹掉原失败状态。

若测试执行已生成可读 xcresult，即使 xcodebuild 返回失败，也先保存 `xctest-summary.json` 再使阶段失败，便于准确区分失败用例数与断言记录数；源声明数、实际执行数和零跳过终门保持。模拟器准备或测试进程中断导致 xcresult 不完整时，日志中的实际错误仍使阶段失败。

## 关键回归及证据边界

- 模型/Markdown：保留分类和心情兼容解码、ISO-8601、Foundation 换行、### 小节、fenced code 旧规则、词数、解析、inline cache、防抖、UTF-16、片段/回车/缩进和输入 traits 全部基线。
- 手机：真实 ContentView compact host 临时借用既有前台 key window，更换根控制器并在结束时完整恢复，避免原 App 与测试内容在同一 scene 同时发布两套 focusedSceneValue。此夹具隔离不等于已证实旧超时根因。List 按公开 shouldSelect、selectItem、didSelect、primaryAction 顺序激活 NavigationLink，查看系统导航栈与真实标题/正文，系统 pop 后同篇重开；异步等待先让出一次显示周期，初次 push 前确认真实两行。新建用例先等待初始两行，再逐项核对阻断筛选、真实空态、公开 accessibility/automation 子树中的可见标识和空导航，最后调用生产新建动作、核对清筛选/新 ID/持久化，阶段输出区分挂载、筛选和动作。删除/筛选及 compact/regular 转换仍修复选择。它是 UIKit host/delegate 证据，不声称物理触屏或交互返回手势实测。
- 焦点：通过 DEBUG probe 设置生产标题 FocusState 并同时确认绑定和真实输入 first responder，再使用与按钮相同的生产完成/预览/写作 action，断言实际 responder、标题焦点、正文内容与选区；保留标题高度变化及正文单/双栏身份测试。不是中文输入法完整实测。
- 有界派生：逐字段与旧 JournalEntryBodySummary 截断路径对照，覆盖 CR/LF/CRLF/Unicode newline、任务标记任意位置、空白、组合字符/emoji/区域指示符、fenced code、长内容和确定性混合输入。旧纯入口保留；新路径不物化全文摘要或小节 Markdown。
- 性能附件：`performance-bounded-body-derivation` 记录同一约 160k 字符/40 小节 Debug 正文，旧/新各 3 次 ContinuousClock 毫秒和中位数，先断言完整投影等价；不设不稳定耗时阈值，不把它当 UI 帧率、真实输入延迟或分配测量。
- 安全：真实临时 JSON 读取失败后 create/update/delete/import/flush 均不改原字节，关 alert 不能解锁；重读成功和合法空库可写，重复 ID、无效导入、stale 预览及冲突均无静默覆盖。原 revision/debounce/actor 保存回归保留。
- 应用锁：可注入系统认证协议测试启用/关闭/失败/后台/迟到结果/请求重叠；生产 Gate 先呈现真实 sheet，再锁定并检查 UIWindow 顶层 shield。截图捕获整个 window。假认证用于确定性边界，不声称真实 Face ID/设备密码已验收。
- 订阅：纯权益测试拒绝未知商品、未验证、到期、撤销、升级，处理有限宽限期。StoreKitTest 从测试 bundle 的 `.storekit` 配置创建真实本地会话，执行生产 purchase/restore/refund/待批准/冷启/到期/取消/验证失败，以及自动 transaction listener 回归。取消和验证失败需读回真实注入状态并进入对应生产分支，普通购买报错不能当覆盖；退款等待真实撤销状态传播后断言权益清除。session、SDK await 与清理即时记录阶段，30秒轮询不是非协作 SDK 的硬中断，进程外 watchdog 仍计超时失败。不能以这些结果声称 Sandbox、真实付款或 App Store 商品已配置。
- 交易前置条件：仅 DEBUG 且存在 XCTest 配置或运行时 XCTestCase 的宿主，关闭 App 全局 Store 的自动启动与回前台订阅刷新，避免真实 Sandbox 查询先于 SKTestSession 配置。测试显式构造的 Store 仍正常调用生产代码，自动监听用例继续使用 startsAutomatically=true。普通 DEBUG 启动与 Release 不走隔离；此隔离是否解决已观察到的 daemon 停滞，以新云端结果判断。
- 导出：日期/时区/分类过滤、完整 Markdown、空选择拒绝、CoreText PDF 真分页与末尾正文保留；导出 actor 不改 Store，生成前后需有效 Pro，失效取消输出。旧免费功能不付费墙。

## 25 张图片矩阵

保留原 16 图：完整 regular ContentView 1360×860 和 1120×720、双栏 1440×900、手机编辑 390×720 浅/深色与辅助字号、844×320 低高度、320×900 资料库浅/深色/历史滚动/辅助字号、1100×900 与手机 390×900 统计、390×720 预览与空态。

新增均 390×844：compact 完整资料库、真实打开后的 detail；设置浅色与 accessibility3；隐私页；真实 presented sheet 之上的深色锁；StoreKit 真实商品的 Pro 方案页、verified 有效 Pro 导出页；无商品 accessibility3。方案图在加载完成后、购买前截取，最后一张滚动到 fallback，以便检查实际不可购及恢复入口。图片仅证明对应云端 iOS 渲染，不代表真机、Mac 窗口或 VoiceOver。

## 独立现代 SDK 发布 job

`ios-release` 与功能 job 并行，在同一 SHA 使用 macos-15/Xcode26.2/iPhoneOS26.2 执行：

```sh
bash script/archive_ios_release.sh "$GITHUB_WORKSPACE/ios-release-results"
```

只对 `generic/platform=iOS` 构建 Release archive，SWIFT_OPTIMIZATION_LEVEL=-O、run number/attempt build number、CODE_SIGNING_ALLOWED=NO，不启动或选择模拟器。脚本验证实际 Mach-O arm64、iOS device 平台、SDK >=26、Info 中的 Xcode/SDK、iOS16 deployment target、图标/Assets、PrivacyInfo UserDefaults CA92.1、不跟踪/收集、Face ID 用途及系统豁免加密声明、私有目录未开放文件共享，以及最终 App 中的两项公开 HTTPS 链接和两项不同商品 ID；记录每个 archive 文件 SHA256 与 ZIP SHA256。

结果为 `MDJournal-iOS-unsigned.xcarchive.zip`、release xcresult、日志、manifest、JUnit 和 failure summary。Manifest 明确 unsigned、未执行上传，不能把结构验证当作签名或商店审核。正式发布还需要真实开发者团队和 Distribution/provisioning；详见 docs/app-store-release.md。

## 最新结果包核对

确认当前 main 和同仓库 origin/main，`git fetch origin` 后锁定最新完整 SHA。使用已有有效 gh 授权安全登录，不打印 token；下载缓存 `/private/tmp/mdjournal-c-review-<run_id>/` 或按 job 区分子目录。

必须核对两个 artifact 的 branch/commitSha/runId/runAttempt/workflow/version、GitHub digest 与大小、本地 ZIP SHA256、未加密 flag、CRC、独立解压与逐文件哈希。功能包核六阶段 JUnit、四份 xcresult 和具体新增测试、25 图逐张；release 包核实际 archive SDK/平台/架构/资源和内部清单，重新只读执行 verifier 不启动 App。提取性能 JSON 并按实际值记录，不预填更快。

失败回到负责模块追加最小修复并推 main，不回滚用户数据。同因 CI 连续失败、连续三轮同阻塞、连续两轮无有效 diff、未知冲突或账号权限需求按入口规则停止/求取必要人工信息，不无限重跑。完整结果写入 update_log.md；任何后续新 SHA 都需要自己的云端结果。
