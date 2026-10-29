# 当前任务

## 用户目标与边界

- 完整目标：将 MD Journal iOS 的写作、UI、性能、隐私/设置、安全和高级订阅完善到可直接提交 App Store 的状态；云端构建与验证。不是只交付软件候选或一个绿色 CI。
- 保留 iOS 16、既有本地 JSON、Store 唯一写入与读取保护，不引入日记服务器/账号/第三方 App 依赖；不开子智能体，不在本机 build、XCTest、App/模拟器运行或性能采集。
- 不伪造 Team、商品/价格、签名、开发者法定资料或发布状态；私钥/密码只进入受保护 GitHub environment secrets，不通过聊天或仓库传递。签名材料清理须由发起人明确确认且仅限本 run 临时所有物，不碰日记。
- 整体目标未完成，保留工作台；完成子阶段的历史已转入 [更新日志](update_log.md)，不能清为“暂无任务”。

## 起点、Git 与本轮文件

- 总任务起点 f4b42403450f50af43351feac6cfb76ed640d64c / main，初始工作区干净，无用户未提交改动；实际目录 /Users/a114514/Desktop/codex/md。
- 云端交付补充阶段起点 7d780f1c8247f4b54a9b605c250febfc3ff79faa / main，初始干净；实现 beaa667cfaca07c37dc1b39c50bd2f538f69a692 已 push origin/main。后续只改日志/工作台，恢复时以实际 Git HEAD/远端核对，不把文档 HEAD 当被测 SHA。
- 此阶段相关文件：.github/workflows/app-store-release.yml；script/app_store_release.py、sign_app_store_release.sh、tests/test_app_store_release.py；docs/app-store-release.md；md/test/test.md；md/flow/flow.md、flowchart.md；work.md、update_log.md。App、Swift 测试与工程相对 384f55e 完全无 diff。

## 验收与当前证据

1. [x] 软件层：写作偏好/辅助字号/IME、真实保存状态与重试、无变化更新短路、分类对比度、默认多任务遮罩、Pro 封面和完整导出；隐私/支持/发布材料与真实能力一致。
2. [x] App 云端 full：精确 384f55e6e08db8d4fe1c29cbe9fe326505a7b18b / run40711015205 / attempt2 两 job success；319/319 XCTest、零失败/跳过、28 审查图/3 素材、iOS/Catalyst Debug、Mac Release、unsigned iOS Release 两包均已下载/逐图/实际产物核对。不能称此结果属于后续脚本或文档 HEAD。
3. [x] 补齐正式交付入口：只接受 main 历史中精确 SHA 的成功 full run/最新 attempt 和两包；默认只导出，同一已测 archive 云端签名，不重建不同源码/改号；显式 testflight 才调用 Apple，不提交审核/发布。要求保护环境审批、禁管理员绕过；验 Distribution 私钥、明确 profile/团队/App ID/期限，导出后复查 Apple 信任/证书/profile/权限、代码小节、资源/隐私；原子安装与所有权清理，脱敏失败与上传不确定恢复动作。
4. [x] 发布脚本回归：精确 beaa667cfaca07c37dc1b39c50bd2f538f69a692 / targeted run40809560857 / attempt1 success，实际 38/38 脚本 fixtures、零失败/跳过、static 一阶段 JUnit1/0/0/0；只有脚本/static，App/XCTest/模拟器/图片/构建/归档均未选。
5. [ ] 真实发布：实际 Team ID/注册 Bundle ID、App Store Connect App/订阅组/月年商品/定价/协议与法定信息；有效 Distribution P12/密码/profile 与受控凭证；真实签名导出 IPA 并下载验收；Sandbox/TestFlight 与设备输入/VoiceOver/认证/锁屏保存，以及实际 Apple 处理/可提交状态。当前没有这些真实证据，不能宣布可直接上传或目标完成。

## 实际保护配置与产物

- GitHub app-store 环境已实际创建并 GET 核对：确认授权用户=真实 User owner Altman-sam114 且 admin=true、创建前环境为空后才操作。Required reviewer=该 owner、仅 main/branch、自定义部署规则、can_admins_bypass=false；prevent_self_review=false 是单人明确审批，不冒充独立双人复核。没有更改 main 提交规则。
- 目前 environment secret 名称列表实际 []，没有写任何凭证。新 workflow400139824 已 active，但 delivery runs API 实际 total_count=0；没有真实签名/Apple请求/上传，也没有正在等待的签名 job。
- 当前保护配置与只读真实 API 合同复核：/private/tmp/mdjournal-release-checks-20261029/environment-setup.json、live-evidence-gate.json、delivery-runs.json。新校验器对真实 App 两包只读接受319项、34个Mach-O file-backed section与4资源；未提供 Team 或执行任何本机 security/codesign。
- App 功能 artifact12866300471（190484573bytes / SHA256 50e0e3b5fbea60af6a8f414402643db86a90895de4a91f9f1e68cbe85bdf59fc），设备 artifact12864643311（2649057bytes / d9ea1b2b89877160191cdbfa11de1406b8b232385ecb97fa8a456a0f5efa90b6），缓存 /private/tmp/mdjournal-review-40711015205/attempt-2/；设备实际1.0(226.2)/arm64/iPhoneOS26.2，仍unsigned。
- 本阶段脚本 artifact12869109458，mdjournal-ci-v0.95-targeted-main-beaa667-run40809560857-attempt1，3610bytes / SHA256 60dc752f52af254ce916a3344fb1477cd02b30728d984a2e9d9da5a7c59d0342。API ZIP 与 gh run download 双下载，5文件身份/范围/大小/digest/未加密/CRC/安全路径/独立解压逐hash、manifest/JUnit/实际38项日志全部通过。证明 /private/tmp/mdjournal-review-40809560857/attempt-1/review-proof.json。

## 验证选择与完成步骤

- baseline：git diff --check、受影响文档本地链接；direct：新38项纯静态/合成 fixtures、Python AST、bash/YAML/4个run块语法；本机最终38/38（1.618s），本地链接12条通过。所有真实 Apple/keychain 调用都被 mock，没有本机 App 构建或运行。
- 云端实际命令：gh workflow run ci-results.yml --ref main -f validation_profile=targeted -f python_test_pattern=test_app_store_release.py；run40809560857/attempt1/beaa667，job11s，实际38/38（1.164s）。已是终态success，不要重复 dispatch，也不把普通会话续行当等待运行中的任务。
- 已完成：计划落盘 → 交付代码/文档 → 本机轻检 → 实现提交push → targeted云测 → 下载核对 → 更新日志。文档收尾仅本工作台/日志两份记录，diff与6份相关文档14条本地链接已通过；此恢复点随收尾提交，后续动作是核实人工发布条件，不重跑App。

## 阻塞与最少人工输入

- 上一 goal turn 是有效进展（App full/两包核对与提交），首次向用户请求实际发布信息。本 goal turn 也有有效进展：补齐正式交付软件、真实配置审批环境、云端38项验证与下载。没有把原目标缩小为软件候选。
- 同一剩余条件在这两个连续 goal turn 中均未解除：用户尚未提供实际 Team/注册 App/商品定价，环境没有 Distribution/profile/API 凭证。当前已没有可安全代替真实账号而继续签名/商店验收的动作；这是第2个连续核实该人工条件的goal turn，不提前标complete/blocked。若后续仍需继续，必须先重查真实Git、secrets名称、环境与delivery run，不只依赖本记录计数。
- 下一步请账号持有人确认实际 Apple Developer Team ID、注册 Bundle ID（当前工程com.codex.mdjournal），App Store Connect App及月/年商品ID/定价；按 [发布配置](docs/app-store-release.md) 在app-store环境设置真实P12/密码/profile，实际上传才另加API key。不要发私钥/密码到聊天。
- 有资料后先确认临时签名材料清理授权，以精确full证据调用新workflow的默认export并经环境审批，下载核对真正IPA；成功后再按明确授权走TestFlight。任何首次实际导出错误按真实日志最小修复，不能以合成fixture当签名成功；上传不确定先查Apple再重试，重跑须整轮生成当前attempt输入。
- 后续只有文档收尾不跑无关App；如注册身份/商品需改App配置，重新评估并云端验证受影响内容。详细测试边界见 [测试规范](md/test/test.md)。
