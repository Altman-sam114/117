# iOS 1.0 发布配置与提审材料

本文件对应 v0.95 的代码和发布准备，不代表已上传、签名或通过 App Store 审核。实际云端 SHA、run、attempt 和产物以 update_log.md 与交付记录为准。

## 当前工程配置

| 项目 | 值 |
| --- | --- |
| 应用名称 | MD Journal |
| iOS Bundle ID | com.codex.mdjournal |
| 发布版本 / 最低系统 | 1.0 / iOS 16.0 |
| 高级订阅 | MD Journal Pro，同一订阅组中的月度、年度自动续期商品 |
| 月度商品 ID | com.codex.mdjournal.pro.monthly |
| 年度商品 ID | com.codex.mdjournal.pro.yearly |
| 价格 | 在 App Store Connect 由开发者设置，应用只显示 StoreKit 的实际本地化价格 |
| 隐私政策 URL | https://github.com/Altman-sam114/117/blob/main/docs/privacy.md |
| 支持 URL | https://github.com/Altman-sam114/117/blob/main/docs/support.md |
| 使用条款 | https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ |

Bundle ID 必须在开发者团队中注册且与 App Store Connect 的 App 记录一致。如已有上架记录，应使用其实际 Bundle ID；不要为绕过冲突新建另一个 App 来替换它。商品 ID 必须与真实商店商品一致。更改商品和公开链接请编辑显式 `MDJournal/Info.plist`，其中 JournalSubscriptionProductIDs 为字符串数组；Debug/Release 合并此文件，发布检查核对实际 App 的键值。不要只添加自定义 INFOPLIST_KEY 构建设置，也不要在界面硬编码价格或折扣。

## 开发者账号中的必要配置

1. 使用实际开发者团队创建或确认上述 App ID 和 App Store Connect App。工程不会猜测团队归属或上传任何私钥。
2. 在 App Store Connect 完成付费应用协议、税务与银行信息；这类账号信息不进入代码仓库。
3. 建立一个 Pro 订阅组，创建月度、年度商品，设置实际销售地区、价格、本地化名称与描述、审核截图、可销售状态，并按业务决定是否启用家人共享。没有配置试用优惠时，界面不宣传免费试用。
4. 设置隐私政策和支持 URL，检查对外联系方式符合实际开发者主体。上述 URL 是随本轮提交公开的项目文档；若使用自有域名，应同时更新工程 URL 和 App Store 元数据。
5. 对照实际二进制填写 App Privacy：应用不向开发者或第三方收集日记、身份、位置、广告或分析数据；不跟踪。Apple 自己提供的商店、系统备份等数据处理按 Apple 规则填写，未来引入分析或服务端时必须重审。
6. 填写年龄分级、内容权利、版权主体、发布地区、审核联系人、欧盟经营者身份及相应证明；这些必须来自真实开发者，不能由代码虚构。应用没有账号体系，不需要提供虚构登录账号。
7. 用真实开发者团队完成 Apple Distribution 签名与 App Store provisioning。云端 unsigned xcarchive 验证代码和 SDK，不能直接作为已签名 IPA 上传。
8. 在 Sandbox/TestFlight 中验证实际商品加载、购买、待批准、恢复、取消续期、到期、退款和 Apple 账号切换；本地 StoreKit 配置测试不能代替商店配置验收。最后核对真机中文输入、VoiceOver、Face ID/密码与锁屏后台保存。

Apple 自 2026-04-28 起要求上传使用 Xcode 26 或更新版本和 iOS 26 SDK：[官方要求](https://developer.apple.com/news/upcoming-requirements/)。CI 使用 Xcode 26.2/iOS 26.2 进行功能回归，并独立在相同 Xcode 26.2/iPhoneOS 26.2 上构建 Release 设备 archive；后者不启动模拟器。两项结果必须对应同一提交。

## 受保护的手动云端交付

[app-store-release.yml](../.github/workflows/app-store-release.yml) 提供独立的 `workflow_dispatch` 入口，不随 push 或普通 CI 自动运行。它复用已验收的云端设备 archive，由 Xcode 26.2 导出并重新签名，不在本机编译，也不重新构建另一份源码。**脚本和纯 fixture 验证不等于实际签名成功；首次真实导出仍须有效账号、证书和 profile，并下载核对自己的结果。**

### 账号持有人先配置

1. 在 GitHub 仓库 Settings → Environments 创建或确认 `app-store`，至少指定一名 Required reviewer，禁止管理员绕过审批，并用自定义部署规则只允许 `main`。流水线会检查环境确实有审批者、禁止 bypass 且使用显式分支策略，不能依赖 GitHub 自动创建一个无保护环境。审批人须核对精确被测 SHA、产物和真实账号信息；单人维护允许本人明确审批时，不把它称作独立双人复核。
2. 把下表材料放入该环境的 secrets，不提交仓库、不发到聊天、不放进普通 CI artifact。P12 必须包含分发证书的私钥，profile 必须与实际 App ID/团队及该证书一致；开发、ad-hoc、企业或通配符 profile 会被拒绝。
3. 完成上一节的真实 App/商品/合同与发布资料。导出不创建 App Store Connect App、不配置价格、不生成或猜测签名身份，也不替代真实商店与设备验收。

| Environment Secret | 内容与用途 |
| --- | --- |
| `IOS_DISTRIBUTION_P12_BASE64` | Apple Distribution 证书及私钥的密码保护 P12，经 base64 编码 |
| `IOS_DISTRIBUTION_P12_PASSWORD` | 上述 P12 的非空密码 |
| `IOS_APP_STORE_PROFILE_BASE64` | 该团队和明确 Bundle ID 的 App Store provisioning profile，经 base64 编码 |
| `ASC_KEY_ID` | 仅 `testflight` 操作需要：实际 App Store Connect API Key ID |
| `ASC_ISSUER_ID` | 仅 `testflight` 操作需要：实际 Issuer ID |
| `ASC_PRIVATE_KEY_P8_BASE64` | 仅 `testflight` 操作需要：具有所需 App 交付权限的实际 API 私钥，经 base64 编码 |

签名材料的创建、导出与权限由账号持有人在 Apple 系统完成；base64 只是传输编码，不是加密。GitHub secret 名称不能证明其内容有效，实际导出前仍会校验过期日、明确 App ID、团队、非调试 profile、有效 Apple Distribution 私钥身份以及证书与 profile 的交集。

### 显式选择已验收版本

Actions 手动表单必须填写完整 `source_sha`、`validation_run_id`、最新成功的 `validation_attempt` 和实际 `team_id`。三个版本字段必须指向同一次 full 验收，不接受分支名、短 SHA、targeted、跳过/零测试或只通过设备归档的结果；source 必须属于当前 main 历史。流水线下载两包并核 GitHub digest、大小、未加密/CRC/路径、manifest、六阶段 JUnit、与该 SHA 源码匹配的实际全测及预检摘要、图片与性能证据、设备内包逐文件哈希和真实 Mach-O。没有可用证据就停止，不绕过门槛重建未知版本。

默认 `operation=export` 只导出，不向 Apple 上传。仅在账号持有人明确选 `operation=testflight` 时，才调用 Apple 验证与上传；不自动提交审核、不选发布地区、不修改价格、不自动发布。可用已有有效 gh 授权手动发起，例如以下变量必须先填真实、已查看通过的值，不能原样照抄空值：

```sh
gh workflow run app-store-release.yml --ref main \
  -f source_sha="$VERIFIED_SHA" \
  -f validation_run_id="$VALIDATION_RUN_ID" \
  -f validation_attempt="$VALIDATION_ATTEMPT" \
  -f team_id="$APPLE_TEAM_ID" \
  -f operation=export \
  -f allow_temp_cleanup=true
```

`allow_temp_cleanup` 默认 false，必须由发起人明确确认：允许清理本次云 runner 创建的临时私钥、P12、keychain、profile 和解包文件，绝不清理日记。临时材料权限收紧；profile/API key 以原子方式安装并记录 inode/hash，不覆盖既有文件；退出/失败及 always 步骤恢复 keychain 搜索列表并清理本次所有物。若文件已被另一写入者替换，保留它并报告失败，但仍清理自己的私钥。不要在本机运行该签名脚本。

### 下载与真实验收

成功 artifact 为 `mdjournal-app-store-<release_run>-attempt<attempt>`，只包含 IPA、实际交付 manifest 与导出日志，保留 7 天；不上传 P12/P8、私钥目录或原始 Apple 账号响应。签名后再次检查 Apple 信任锚/团队、证书、profile/有效期、非调试 entitlement、版本、隐私/资源及已测可执行代码/数据段一致性。它保留已验收归档的版本与构建号；若 Apple 已接收相同 build，先查 App Store Connect 状态，不原地改号伪装成同一次验收。

manifest 的 `exported-not-uploaded` 只证明已核验导出；`upload-accepted-processing-unverified` 只代表上传命令和 Apple 确认成功，**不证明处理完成、TestFlight 可用、Sandbox/真机验收、提交审核或正式发布**。失败只保留脱敏阶段与错误码；如在上传阶段超时或失败，可能已被 Apple 接收，必须先查 App Store Connect 再决定是否重试，不能重复盲传。公开仓库的 artifact 访问与保留期应按实际发布策略管理；IPA 包含应用公开团队与 profile 身份，不含用户日记。

若确需重跑交付流程，重新 dispatch 或选择 rerun 全部 job，让新 attempt 重新预检并审批；不能只重跑签名 job 来复用另一 attempt 的中间包。中间包绑定当前 release run/attempt，不提供跨 attempt 绕过入口。

## 商店图片

功能 artifact 的 `app-store-screenshots/` 包含独立命名的三张无透明 PNG 和可追溯 index；只有该提交云端完成、下载核对并逐图确认后，才能选作提交素材：

| 素材 | 像素 | 来源 |
| --- | --- | --- |
| iPhone 资料库 | 1179×2556 | 云端 iPhone 原生 393×852pt 窗口直接 3x 渲染 |
| iPhone 日记详情 | 1179×2556 | 同一生产导航栈真实打开详情、转场稳定后直接 3x 渲染 |
| iPad 完整界面 | 2732×2048 | 生产 ContentView regular 完整 1366×1024pt 画布直接 2x 渲染 |

图片使用确定性演示日记，不含个人数据；不从旧图放大，不添加虚构商品价格或系统状态栏。iPad 素材是生产视图画布，不能作为 iPad 设备运行证据，上传前应在对应设备确认实际表现。28 张回归图（含外观设置与疏朗大字正文）单独保留。

截至本轮核查，Apple 的 [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 接受 iPhone Dynamic Island medium 的 1179×2556 或 1206×2622；支持 iPad 时另需 13 英寸截图，接受 2064×2752 或 2048×2732 及相应横向尺寸。最终按 App Store Connect 当前表单核对，图像无 alpha，尺寸合格仍需实际视觉审核。

## 商店文案草稿

副标题：把日常，写成值得回看的文字

简介：MD Journal 是一款安静的 Markdown 日记应用。用纸本般的界面记录日常，以日期、分类和心情回看你的生活。

- 原生中文写作界面，支持 iPhone 与 iPad 竖横屏、深色和辅助字号。
- 免费选择纸页外观、正文字体、字号和行距；显示真实本机保存状态，失败可重试。
- Markdown 编辑和阅读预览，三级标题小节、列表、待办、引用和代码块。
- 本机 JSON 保存、免费备份与安全合并导入，无注册账号和自建日记服务器。
- 默认隐藏多任务预览，可另启用免费的系统身份验证应用锁。
- 搜索、年月资料库和写作统计。
- 可选 MD Journal Pro：按日期、分类筛选，批量导出 Markdown 和带自定义纸本封面的分页 PDF（保留 Markdown 原文）。订阅由 Apple 处理并自动续期，价格和期限以购买页为准，可随时在系统订阅管理中取消。

关键词草稿：日记,Markdown,写作,笔记,心情,本地,隐私,日常,记录

审核备注草稿：无需注册或登录。设置入口位于资料库导航栏。基础编辑、单篇分享、统计、JSON 备份与导入免费；Pro 导出位于设置的高级导出入口，订阅页提供隐私、许可协议、恢复购买与管理订阅。启用应用锁需设备已设置系统密码。测试备份请使用审查人员创建的内容，应用不会从服务器下载日记。

以上商店文案应在最终云端和真机结果通过后使用，开发者联系信息、版权、定价、销售地区与分级仍须由账号持有人确认。
