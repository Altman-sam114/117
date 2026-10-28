# 当前任务

## 目标与边界

- 用户目标：快速将 iOS 版推进发布级，完善写作、UI/适配、性能、设置、隐私安全与有价值的高级订阅；仅云端编译/测试。
- 非目标：不引入日记服务器/账号/第三方依赖，不改变既有 JSON 兼容格式，不猜测开发者身份或伪造商品/签名，不在本机运行 App、模拟器、构建或 XCTest；不创建子智能体。
- 发布边界：软件验收与账号侧上架分开。正式团队/签名、商品销售配置、Sandbox/TestFlight、真机交互及 App Store Connect 提审必须有对应真实证据。

## 起点与工作区

- 分支：main；起点：f4b42403450f50af43351feac6cfb76ed640d64c；origin/main 与本地一致，2026-10-28 已 fetch。
- 初始工作区干净，无需保留的未提交改动；历史软件基线有 311 项 XCTest 与发布归档，但不作为本轮结果。
- 实际项目目录：/Users/a114514/Desktop/codex/md（环境提供的 /Users/codex/workspace 不存在）。

## 验收标准

1. 对真实源码做发布缺口审计，优先修复数据安全、输入体验、订阅权益/设置和长文性能问题，保持中文纸本风格及 iOS 16 兼容。
2. 本轮功能有直接回归；隐私/支持/发布材料与实际能力一致，无虚构价格、跟踪或安全保证。
3. 发布范围跨层，执行一次 full 云端验收：实际非零全测零失败/零跳过、相关 UI/性能附件、iOS/Catalyst 构建与设备 unsigned Release 归档，并下载精确 SHA/run/attempt 产物核对；失败据证修复。
4. main 相关变更提交并推送；日志记录实际证据和无法替代的人工发布项，满足软件验收后清空本工作台。

## 步骤与进度

- [x] 读取 AGENTS、工作台、Git、核心流程/测试规范与发布文档；核实远端和有效 gh 授权。
- [x] 审计现有编辑/列表/设置/锁/订阅/导出：已有完整本地 JSON、认证锁、月/年真实 StoreKit 与高级导出；本轮补写作偏好、保存透明性、默认预览隐私和 PDF 封面，不重做成熟路径。
- [x] 实现免费纸页/字体/字号/行距，环境注入与 IME 期间样式推迟；真实保存状态及重试、无变化回写短路；默认隐藏多任务预览且不能绕过应用锁；Pro 可选自定义封面，保持完整原文、取消与权益期限检查。
- [x] 补直接回归：3 项偏好、2 项保存/无变化更新、2 项预览隐私、1 项 PDF 封面；加强实际 bridge 排版更新和真实 marked-text 隔离用例。新测试声明总数待云端实际核对（声明不等于执行）。
- [ ] 本机仅相关静态轻检；核 diff、提交 main、push，主动 dispatch 云端。
- [ ] 等待并下载核对功能/设备包、图片、测试与性能结果；按实际失败修复。
- [ ] 更新受影响架构/隐私/支持/发布文档与日志，收口并清空工作台。

## 编辑范围与验证选择

- 当前编辑：work.md；MDJournal/ContentView.swift、MDJournalApp.swift；Stores/JournalStore.swift、JournalAppLockStore.swift；Utilities/JournalWritingPreferences.swift（新增）、JournalPremiumExport.swift；Views/JournalWritingSettingsView.swift（新增）、JournalSettingsView.swift、JournalPrivacyGate.swift、JournalPrivacyView.swift、EntryEditorView.swift、MarkdownBodyTextView.swift、MarkdownPreviewView.swift、JournalPremiumExportView.swift、JournalPaywallView.swift；MDJournalTests/JournalWritingPreferencesTests.swift（新增）、JournalStoreTests.swift、JournalSecurityTests.swift、JournalPremiumExportTests.swift、MarkdownTextInputConfigurationTests.swift、JournalInterfaceTests.swift；MDJournal.xcodeproj/project.pbxproj；.github/workflows/ci-results.yml（仅增加 3 张必要审查图，25 -> 28）；README.md、docs/privacy.md、docs/support.md、docs/app-store-release.md、md/flow/flow.md、md/flow/flowchart.md、md/test/test.md。
- baseline：git diff --check；受影响文档本地链接检查。
- direct：每项补丁对应 XCTest、生产 host UI 回归及必要 plist/资源检查；不以 Swift parse 替代编译。
- optional（有依据）：用户明确要求发布级且涉及编辑、UI、安全、订阅与发布元数据，选择现有 full 发布配置；保留全部门槛与独立 iOS Release job。
- 未运行项：本机所有构建/运行/性能采集；真实 Sandbox/TestFlight、签名上传与真机系统行为不能由云端合成画布或 StoreKitTest 替代。

## 阻塞与下一步

- 当前无软件阻塞。本机轻检已通过：21 个变更/新增 Swift 的 DEBUG parse（仅语法）、project/Info/Privacy 三 plist、3 新源码正确 target 注册、17/17 CI 范围 Python fixtures、workflow YAML/15 bash/3 Python 语法、27 条文档本地链接、git diff --check。没有本机 build/XCTest/模拟器。
- 下一步：最终自查 diff、只提交上述文件到 main、push 并发起 full 云端；立即记录实际 SHA/run/attempt。云端未跑前不能宣称类型检查、交易、交互或视觉验收已通过。

## 提交与云端恢复点

- 实现已提交：fceaa608ac57de01f7b178ce34e026afac4b8fbc / main，31 个明确本轮文件。319 项 XCTest 声明（不是执行数）。最终 DEBUG parse 21 源与 staged diff 检查通过。
- 2026-10-28 21:12 台北时间 `git push origin main` 成功；随后执行 `gh workflow run ci-results.yml --ref main -f validation_profile=full`，run 40694382474 / attempt 1 / main / headSha fceaa608ac57de01f7b178ce34e026afac4b8fbc 已核实。两个 job 正在执行，静态检查成功，iOS Archive 构建中，功能准备云端模拟器；不要重复 dispatch。
- 预期产物：同 SHA/attempt 的 mdjournal-ci-v0.95-full-main-... 功能包与独立 mdjournal-ios-release-... 设备包，完整319项、28张审查图/3张商店图、性能 JSON 与 PDF 附件、iOS/Catalyst Debug、Mac Release 和 unsigned iOS Release。实际 run/结果待填。
- 设备 job 已 success（3m38s），artifact 12817814983 / 2647229 bytes / SHA-256 f2e7d6a6daa5b5a5a9576e4356835deeaad52bbb9b0d6d82028e1128a1c84c6f；已通过 gh api 下载到 /private/tmp/mdjournal-review-40694382474/attempt-1/ 并核 GitHub digest/大小、外ZIP 13文件/未加密/CRC/安全路径、manifest身份、JUnit1/0/0/0。内ZIP2621975bytes、SHA905b5e0f34c91e096cc19d113a8af210a9d4059e94c87d93a62fdd11ed4cc1ca，25条目/11实文件逐hash匹配；只读解析真实 Mach-O/Info/Privacy：arm64 iOS device、SDK26.2、1.0(222.1)、FaceID/两链接/商品/无测试storekit正确。UIFileSharingEnabled未显式出现在最终Info（系统默认false，不作缺键错误）。unsigned，未上传。
- 额外 gh run download 在同一设备包停滞超过3分钟后主动终止，未声称双下载成功；API ZIP已完整并匹配GitHub摘要，不受此阻塞。原始记录 review-proof.json / device-review.json。
- 公开仓库确认 private=false；GitHub Contents API核 privacy/support 两文档blob与本轮提交一致。普通 curl 对外链接在本机网络超时000，不能声称已HTTP200，提交前仍需在外部网络打开商店URL确认。
- 首轮 full 整体失败：设备包成功；实际日志证实319项完成，318通过、1个用例失败（3条断言），0 unexpected。唯一失败是本轮新增偏好用例在 accessibilityExtraLarge 对标准17pt字体错误假定 >40，而系统正确返回40。生产输入/marked-text、隐私/默认遮罩、保存/无变化回写、交易、PDF全通过；28张图片完整导出。其余平台构建按门槛未执行，不称发布通过。
- 追加最小修复仅测试：把错误固定阈值替换为五档辅助字号全部逐一精确匹配 UIFontMetrics，逐档严格增大，并保留最大档>40的要求；不是删用例/跳过或降低断言，也不修改正确的系统字体。下一提交再次 full，须核新SHA自己的两包；旧功能248979605bytes包正在API下载（12818888751，GitHub digest 1ea72241637e0e557d5bf645e18ee303ef62927611c824966db37bb0111cb762），未完成前不声称核对完成。
