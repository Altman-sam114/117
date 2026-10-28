# 测试规范

本文件只描述可复用的测试选择、云端入口和证据边界。当前计划与恢复点写入 [work.md](../../work.md)，具体 SHA、run、计数和历史结论写入 [update_log.md](../../update_log.md)，不把某轮发布矩阵当成所有任务的默认清单。

## 1. 默认云端与本机禁区

- 完整构建、XCTest、App/模拟器运行、性能采集和发布归档默认且只能在云端，包括 Mac Catalyst；未经用户特别要求，禁止本机调用 xcodebuild、simctl、build/run 脚本或 Instruments。云端失败或排队不是自行改用本机的授权。
- 本机只做本轮相关静态/轻量检查，如 diff、文档链接、受影响的 YAML/脚本语法或不启动系统服务的纯 Python fixture。不得借“轻检”运行 Swift 测试宿主、App 或模拟器。
- 用户明确要求本机 iOS 操作时，必须核实并只使用现有 UDID 以 `FAC4325D` 开头的唯一模拟器，不创建或选择其他设备；云端不限。
- 当前模型负责选择、发起、等待与核对云端验证，不需要角色交接或用户再次催测。有效 gh 授权可直接使用，缺权限时如实保留阻塞。

## 2. 按本轮改动选测试

开始实质修改前，在工作台记录 `baseline + direct + optional`、选择理由及未覆盖范围。以本轮编辑记录和真实依赖决定范围，不因为其他会话、累计提交或历史 CI 清单扩大测试。

- **baseline**：所有改动运行 `git diff --check`；文档检查本地链接、路径与当前规则一致性。这不是 App 编译或运行证据。
- **direct**：验证本轮改动的业务、脚本或配置；新增缺陷回归，优先精确方法/单个 fixture，多个方法相互依赖或整个测试类都相关时才选类。
- **optional**：仅增加有明确因果关系的上下游、共享组件、平台或发布检查，在工作台写明为什么需要。不是“可顺手跑的所有内容”。

| 改动范围 | 直接及必要关联检查 | 不默认执行 |
| --- | --- | --- |
| 纯文档、任务计划与历史说明 | diff、本地链接/路径、活动规则一致性 | App build、XCTest、脚本全套、截图、归档、任何无关 CI |
| workflow / 验证脚本 | YAML、受影响 shell/Python 语法与对应 fixture；必要时云端运行同一范围确认调度和结果包 | 因 CI 文件变化就运行全部业务测试/图片/发布包 |
| 模型、Markdown、统计或派生 | 对应 XCTest 类/方法；共享输出的解析/预览/列表等必要消费者 | 无关订阅、认证、图片与发布包 |
| Store、持久化、备份与读取保护 | JournalStoreTests、JournalBackupTests 中受影响用例及兼容/错误/取消边界 | 无关 UI/订阅；除非确实影响共享路径 |
| 导航、焦点、输入和布局 | 对应导航/输入算法及 JournalInterfaceTests 的精确生产 host 方法；只查相关图片和字号/宽度 | 混合 UI 类里的无关设置、方案页与整套商店素材 |
| 隐私、应用锁 | JournalSecurityTests 中相关保护/认证/遮罩方法；必要关联保存/生命周期 | 无关交易或全图矩阵 |
| 订阅、高级导出 | JournalSubscriptionTests、JournalPremiumExportTests 中相关真实交易、权限期限或输出回归 | 无关导航/统计；StoreKitTest 不冒充 Sandbox |
| 平台/工程/发布配置或广泛共享变更 | 对应 plist/资源/脚本检查与必要 iOS/Catalyst 构建；有跨层或发布验收依据才选完整配置 | 将无关平台构建/签名/素材变成任意小修复的门槛 |

保留已有测试与断言，不为提速删除、放宽或静默跳过所选测试。选择范围可缩小，但必须真实证明本轮行为；无法覆盖时明确说明，不能以“CI 绿”代替范围判断。

## 3. 相关轻量检查示例

每次只取与本轮有关的命令，不整段照跑：

```sh
git diff --check
# 仅 workflow 改动时
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
# 仅对应脚本改动时
bash -n script/archive_ios_release.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s script/tests -p 'test_xctest_summary.py' -v
# 仅工程或隐私配置改动时
plutil -lint MDJournal.xcodeproj/project.pbxproj MDJournal/Info.plist MDJournal/PrivacyInfo.xcprivacy
```

必要时检查受影响 workflow run 块的 bash 语法、内嵌 Python AST、scheme/test plan/资源格式或注册。Swift parse 只证明语法，不是类型或运行检查；未改 Swift 不解析全应用，未改设备选择/归档/商店素材不跑对应 fixture。

## 4. 云端任务入口

[ci-results.yml](../../.github/workflows/ci-results.yml) 只有 `workflow_dispatch`，push/文档收尾不自动运行全量。默认分支 `main`，由模型在 push 后按计划主动触发；不是改为默认本机验证，也不要求用户每次另行授权云端。

### targeted：日常按范围验证

`validation_profile=targeted` 为默认配置，必须至少选择一项，空选择明确失败：

| 参数 | 含义 |
| --- | --- |
| `only_testing` | 空格分隔的 `MDJournalTests/类名` 或 `MDJournalTests/类名/test方法名`；先对照当前源码验证，不接受空范围、未知标识、通配符或额外命令参数 |
| `python_test_pattern` | `script/tests` 下一个实际存在的精确 `test_*.py` 文件名，不接受 glob 或路径越界 |
| `build_platform` | `none` / `ios` / `catalyst` / `both`，只补任务必要的 Debug 构建；所选 XCTest 的模拟器宿主已由 build-for-testing 构建 |

只跑相关脚本检查时不准备模拟器、不跑 XCTest；只构建时不运行测试；选择 XCTest 时仅串行执行选中类/方法，不自动追加商店与导航预检、全套图片或 Release。编译测试 target 仍会编译其依赖，不代表运行全部用例。

```sh
# 修改 Markdown 解析与相关预览时，选择这两个类；其他任务不要照抄
gh workflow run ci-results.yml --ref main   -f validation_profile=targeted   -f only_testing='MDJournalTests/MarkdownBlockParserTests MDJournalTests/MarkdownPreviewTests'

# 只验证 CI 范围/结果脚本时，不启动 App 或模拟器
gh workflow run ci-results.yml --ref main   -f validation_profile=targeted -f python_test_pattern=test_xctest_summary.py

# 只有 Catalyst 编译分支受影响且不需要运行测试时
gh workflow run ci-results.yml --ref main   -f validation_profile=targeted -f build_platform=catalyst
```

针对性 XCTest 仍保留固定工具链、既有云端设备、独立 build-for-testing、串行执行、进程外 watchdog、失败诊断和 xcresult；`verify_xctest_summary.py --only-testing ...` 要求所选声明的实际执行数匹配且零失败/跳过。重复/重叠选择按唯一方法计数，非零方法才可验收；局部结果明确 `fullSuiteVerified=false`。

如果任务需要针对性配置尚未提供的相关产物，例如单独 Release 或局部图导出，应先补最小相关入口并验证，不把运行无关全套当作省事替代。

### full：完整发布与有依据的跨层回归

工作台写明发布或跨层验收依据后才使用；不带 targeted 过滤参数：

```sh
gh workflow run ci-results.yml --ref main -f validation_profile=full
```

保留完整配置的现有门槛，不因自主迭代而缩减：

1. macos-15 / Xcode 26.2 / iOS 26.2；静态检查及全部纯 Python fixtures。
2. 固定 runtime 中选择一台已有云端 iPhone，查询各限 60 秒、准备步骤 4 分钟；复用库存 initialState，不创建克隆或回退 runtime。
3. MDJournalCI scheme/test plan 显式本地 StoreKit；build-for-testing 600 秒、bootstatus 240 秒；商店 3 项及导航/输入 4 项预检分别有界，任一失败保留另一组诊断并阻止全测。
4. 预检通过后，同 UDID 串行执行全部源码声明测试，实际数量匹配、零失败/跳过；test-without-building 720 秒、逐用例 watchdog 180 秒，生产导航/输入 host 的 60 秒预算保留。测试期间按阶段每 25 秒保存有界采样，失败保留可用 xcresult/diagnostics。
5. 校验 25 张审查图及性能附件、另 3 张商店尺寸素材的完整性、来源、尺寸和摘要；商店 PNG 必须无 alpha/tRNS，普通审查图不套用这一限制。iPhone 商店图原生窗口 3x，iPad 是完整生产画布 2x，不把画布当设备运行。
6. 测试与图片成功才执行 generic iOS Debug、Catalyst Debug、universal Mac Release 内部包；完整六阶段均须成功，因失败跳过仍不放行。
7. 独立 `ios-release` job 同 SHA 使用 iPhoneOS 26.2 执行 generic iOS unsigned Release archive，不启动模拟器；核实际 SDK、arm64/device 平台、版本、图标、隐私/Face ID/链接/商品 ID 与内部文件哈希。

完整配置的 JUnit 表达阶段数，不是 XCTest 数；测试数以实际 xcresult/日志和源码声明为准。最终必须同时核对功能与设备归档两份 artifact，任何一个失败都不宣布完整通过。

## 5. 云端结果验收与收口

1. dispatch 前核对当前 `main`、本轮提交范围和 origin/main SHA；dispatch 后尽快把命令、预期范围、run ID/attempt 写入工作台。`gh run view` 核 headSha/headBranch，不能只按“最近一次”或 artifact 名猜测归属。
2. 使用已有有效 gh 授权下载本次未加密结果到 `/private/tmp/mdjournal-review-<run_id>/attempt-<attempt>/`。核 manifest 的 branch、commitSha、runId、runAttempt、workflow、validationProfile 与 validationScope；若远端在等待中变化，先说明被测提交与当前 HEAD 的关系，不把过期包当最新结果。
3. 核 GitHub 大小/digest、本地 ZIP SHA-256、未加密 flag、CRC 和安全解压；按任务需要核内部文件哈希。核所选阶段主日志、JUnit、实际测试摘要和产物，不能只看 Actions 总状态或模型汇报。
4. `requiredStages` 必须成功；`notSelectedStages` 只代表范围外，不能称已通过。所选 XCTest 零执行、缺失、失败或跳过都不通过；仅声明计数或 `test-selection.json` 不算执行。`validationPassed` 仅针对当前配置，full 还需独立 archive job 通过。
5. 根据具体失败追加最小修复，重新评估并只重跑受影响验证；同因失败先诊断，不无限重试或降低断言。阻塞和未验证范围保留在工作台，并在交付中说明。
6. 通过后将实际范围、命令、SHA/run/attempt/artifact、下载核对和风险写入更新日志，清空工作台。后续只有文档/日志变更不再次运行 App 回归；证据仍归属实际被测 SHA，不声称文档 HEAD 做过同一运行验证。

StoreKitTest 不等于 Apple Sandbox，unsigned/archive/ad-hoc 不等于正式签名、公证或上传；合成 UIKit/SwiftUI 画布不证明真机旋转/交互、IME、VoiceOver、系统认证或锁屏保存。账号团队后置不阻塞软件验证，也不能用软件结果冒充正式发布。
