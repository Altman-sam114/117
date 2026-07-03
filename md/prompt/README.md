# Prompt 目录

本目录保存每轮 Agent A 写给 Agent B 的详细实现提示词。提示词必须服务于当前真实流程：Agent B 在 `main` 上实现并直推 `origin/main`，GitHub Actions 生成未加密 CI 结果包，Agent C 下载结果包复判。

## 角色召唤

- `agenta`、`a:` 或 `A:`：召唤 Agent A。
- `agentb`、`b:` 或 `B:`：召唤 Agent B。
- `agentc`、`c:` 或 `C:`：召唤 Agent C。
- 未带前缀时按普通 Codex 任务处理；若任务必须分角色执行，先提醒人工指定角色或说明本轮按普通任务执行。

身份标识：

- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## 命名建议

- `md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md`
- `md/prompt/v0（项目初始化）/v0.2（优化测试规范）.md`
- `md/prompt/v0（协作云端化）/v0.3（main直推云端验证）.md`
- `md/prompt/v1（核心功能）/v1.0（实现主流程）.md`
- `md/prompt/v1（核心功能）/v1.1（修复主流程问题）.md`

## 版本管理规则

- Agent A 每次写提示词都必须写入版本号。
- 人工指定版本时，以人工指定为准。
- 人工未指定版本时，Agent A 自动判断版本，沿当前阶段递增小版本。
- 同一阶段的小任务、修复、优化递增小版本，例如 `v0.1` -> `v0.2` -> `v0.3`。
- 大任务、架构阶段、核心功能阶段或重要里程碑新开大版本，例如 `v0.x` -> `v1.0`。
- 同一大版本下的提示词放在同一个目录：`md/prompt/v0（简要标题）/`、`md/prompt/v1（简要标题）/`。
- 文件名使用 `v0.1（简要说明）.md`，说明要短，能表达本轮目标。

## 每份提示词必须包含

- 版本号。
- 版本分配依据。
- 背景。
- 目标。
- 非目标。
- 架构依据。
- 影响范围和关键文件。
- 实现步骤。
- 本地轻量检查要求。
- `main` 直推要求。
- GitHub Actions workflow 或结果包要求。
- Agent C 下载 artifact 和核对 manifest/JUnit/log 的验收要求。
- 文档更新要求。
- 风险和禁止项。

## Agent A 云端阶段提示词要求

Agent A 写给 Agent B 的提示词必须明确：

- 本轮默认分支是 `main`，目标远端是 `origin/main`。
- 本轮不创建 `smalldata_test`、`develop`、`codeb/...` 等候选分支，不创建 PR，不写 PR merge 流程。
- Agent B 开始前必须同步最新 `origin/main`；如果没有远端或无法同步，必须记录阻塞。
- Agent B 完成后本地只跑 `md/test/test.md` 要求的轻量检查，随后 commit 并 `git push origin main`。
- Swift / Xcode / Web / CLI / 业务探针相关改动默认交给 GitHub Actions 重验证。
- Agent C 只验收最新 `origin/main` commit 对应的 run 和 artifact。
- artifact 必须未加密，至少包含 manifest、failure summary、主日志、JUnit 或等价摘要和项目关键产物。
- manifest 必须能追溯 `branch`、`commitSha`、`runId`、`runAttempt`、workflow 名称、日志路径和各阶段 outcome。
- Agent C 下载缓存默认放在 `/private/tmp/mdjournal-c-review-<run_id>/`。
- 云端失败时，Agent B 在 `main` 上追加修复 commit 后继续 push，不默认回滚。

## 禁止项

- 禁止把其他项目的业务探针、模型、截图、私有数据或分支制度硬复制到 MD Journal。
- 禁止要求 Agent C 只看 Agent B 文字汇报。
- 禁止把旧 artifact、旧 output 或 checkout 自带报告冒充本轮云端结果。
- 禁止在没有 GitHub 权限或没有 `origin/main` 时伪装云端验收完成。
