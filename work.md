# 当前任务

## 目标与边界

- 目标：移除当前入口中的 ABCX 角色、交接和并行模块前提，改为单模型根据目标自主规划、实现与验收。
- 参考：只读借鉴 aitrans 的文档分工、按改动选测试和自主决策，不迁移其分支或本地构建规则。
- 保留：main 直推、默认云端构建测试、数据安全边界；不改应用功能、持久化或发布账号配置，不开子智能体。
- 完成标准：活动文档无旧角色门槛，work.md 生命周期明确，测试仅覆盖本轮直接及必要关联范围，检查通过后将本任务结论写入 update_log.md 并清空工作台。

## 基线与本轮编辑记录

- 起点：main / ee170c7，初始工作区干净，与本地 origin/main 一致。
- 本轮编辑：AGENTS.md、README.md、md/flow/flow.md、md/flow/flowchart.md、md/test/test.md、md/prompt/README.md、update_log.md、work.md。
- CI 相关编辑：.github/workflows/ci-results.yml、script/verify_xctest_summary.py、script/tests/test_xctest_summary.py；只调整范围选择与验收，不改业务/工程/原发布脚本。
- 历史 prompt 和历史验收记录保留，不重写历史事实；参考项目不修改。

## 计划与进度

- [x] 阅读现有入口、当前状态、流程/图、测试、README、prompt 入口及参考规范，确认工作区与分支。
- [x] 重写自主迭代规则和 work.md 的写入、恢复、更新、完成清理约定（AGENTS、README、prompt 入口已落地）。
- [x] 按直接/关联影响收敛测试规范与必要 CI 入口，默认云端、禁止擅自本地构建测试。
- [x] 同步 README、流程图、历史 prompt 入口和维护日志；检查 diff、活动文档一致性与链接。
- [ ] 推送本轮实现，主动发起仅 test_xctest_summary.py 的云端 targeted 验证，下载并核对本轮结果包。
- [ ] 记录实际验证与未运行原因，清空工作台；仅提交本轮文件并按规则处理远端。

## 验证与下一步

- 本轮只改流程文档及必要 CI 入口：运行 git diff --check、Markdown 本地链接/路径与旧流程残留检查；若改 workflow，增加 YAML 和受影响脚本语法/选择逻辑检查。
- 不运行本机 build、XCTest、模拟器、App 或无关 fixture/图片/Release archive；有必要的执行验证只放云端。
- CI 方案：同一 workflow 仅保留 workflow_dispatch；targeted 必须指定测试类/方法、一个精确 Python 测试文件或必要构建平台，默认无选择直接失败；full 显式保留原完整门槛。结果区分 requiredStages 与 notSelectedStages，不将未选步骤写成成功。
- 已实现范围选择、targeted XCTest 分支与动态终门；summary verifier 保留完整套件计数，新增 17 项直接回归覆盖精确/重叠/未知选择、零执行/失败/跳过、空任务拒绝、Python-only 不选 XCTest 与动态 manifest 终门。
- 本机轻检通过：git diff --check；精确 Python fixture 17/17；workflow YAML/唯一 dispatch 事件/默认范围、15 个 bash run 块与 3 个内嵌 Python/2 个改动脚本 AST；33 个活动文档本地链接及旧角色门槛残留检查；原完整套件仍解析出 311 个声明（只做选择兼容检查，未运行 XCTest）。Ruby 发出本机 /opt/homebrew PATH 权限警告，不是编译结果。
- 远端：git fetch origin 成功，HEAD 与 origin/main 均为 ee170c7070c1afeeccebcc90f797e42fd73b467e；gh 已有有效登录，不重新索取授权。
- 提交前再次同步时 Git HTTPS 连接遇 HTTP/2 错误，HTTP/1.1 的有界 fetch 45 秒超时；已停止本任务超时进程，没有动其他会话。GitHub API 再核远端仍为 ee170c7070c1afeeccebcc90f797e42fd73b467e，与本地一致，尚未提交或推送。
- 下一步：核本轮提交范围与远端，提交并 push；执行 gh workflow run ci-results.yml --ref main -f validation_profile=targeted -f python_test_pattern=test_xctest_summary.py，记录其 SHA/run/attempt 后等待并下载核对；不跑 App 或完整发布配置。
