# 测试规范

本文指导 Agent A、Agent B 和 Agent C 选择测试层级、记录命令和判断当前基线。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/md`。
- 默认协作分支：`main`。
- 默认远端目标：`origin/main`。
- Xcode 工程：`MDJournal.xcodeproj`。
- Scheme：`MDJournal`。
- 当前最低 iOS 版本：16.0。
- 当前没有第三方依赖和包管理器。
- 当前没有正式 XCTest target。
- 当前默认策略：本机只跑轻量检查，重验证交给 GitHub Actions。
- 若仓库没有 `origin` 远端、GitHub Actions 权限或 artifact 下载权限，必须记录阻塞，不能伪装云端验证完成。

## 1. 本地轻量检查

本地轻量检查用于尽快发现空白、配置、语法和 workflow 断点。除非人工明确要求，本机不默认跑完整 build。

### 1.1 通用检查

触发条件：

- 任意文档、Swift 文件、Xcode 工程文件或 workflow 改动。
- Agent B 实现后、commit 前。

命令：

```sh
git diff --check
```

当前基线：

- 无输出并返回 0。

### 1.2 Xcode project 检查

触发条件：

- 修改 `MDJournal.xcodeproj/project.pbxproj`。
- 修改构建配置或需要确认 project 文件未损坏。

命令：

```sh
plutil -lint MDJournal.xcodeproj/project.pbxproj
```

当前基线：

- 输出 `MDJournal.xcodeproj/project.pbxproj: OK`。

### 1.3 Swift 解析检查

触发条件：

- 修改 Swift 源码。
- 修改可能影响 Swift 编译输入的工程结构。

命令：

```sh
xcrun swiftc -parse -parse-as-library $(rg --files -g '*.swift' MDJournal)
```

当前基线：

- 返回 0 且无错误输出。

### 1.4 Workflow YAML 检查

触发条件：

- 新增或修改 `.github/workflows/*.yml` 或 `.github/workflows/*.yaml`。

命令：

```sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

当前基线：

- 输出 `yaml ok` 并返回 0。

### 1.5 JSON 检查

触发条件：

- 新增或修改本地 JSON 示例、manifest 模板或其他 JSON 文件。

命令：

```sh
python3 -m json.tool path/to/file.json >/dev/null
```

当前基线：

- 返回 0。

## 2. 云端重验证

云端重验证是默认主验证路径。Agent B push 到 `origin/main` 后，GitHub Actions 运行 `.github/workflows/ci-results.yml` 并上传未加密结果包。

触发条件：

- `main` 分支 push。
- 手动触发 `workflow_dispatch`。

workflow 名称：

- `MD Journal CI Results`

云端命令基线：

```sh
git diff --check
plutil -lint MDJournal.xcodeproj/project.pbxproj
xcrun swiftc -parse -parse-as-library $(git ls-files 'MDJournal/*.swift' 'MDJournal/**/*.swift')
```

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath "$RUNNER_TEMP/mdjournal-derived-data" \
  -resultBundlePath ci-results/MDJournal.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  build
```

云端结果包至少包含：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `static-checks.log`
- `xcodebuild.log`
- `junit.xml`
- `MDJournal.xcresult`，如果 `xcodebuild` 成功生成

manifest 至少包含：

```json
{
  "version": "v0.3",
  "branch": "main",
  "commitSha": "...",
  "shortSha": "...",
  "runId": "...",
  "runAttempt": "...",
  "workflowName": "MD Journal CI Results",
  "createdAt": "...",
  "projectName": "MD Journal",
  "scheme": "MDJournal",
  "destination": "generic/platform=iOS",
  "resultBundlePath": "ci-results/MDJournal.xcresult",
  "junitPath": "ci-results/junit.xml",
  "buildLogPath": "ci-results/xcodebuild.log",
  "failureSummaryPath": "ci-results/ci-failure-summary.md",
  "staticChecksOutcome": "success/failure",
  "buildOutcome": "success/failure",
  "testOutcome": "skipped",
  "projectSpecificReports": []
}
```

artifact 命名规则：

```text
mdjournal-ci-v0.3-main-<short_sha>-run<run_id>-attempt<run_attempt>
```

## 3. Agent C 下载和复判

Agent C 必须先具备 GitHub CLI 权限：

```sh
gh auth login
```

下载缓存默认位置：

```text
/private/tmp/mdjournal-c-review-<run_id>/
```

推荐命令：

```sh
gh run list --branch main --workflow "MD Journal CI Results" --limit 5
gh run download <run_id> --dir /private/tmp/mdjournal-c-review-<run_id>
```

Agent C 必须核对：

- `origin/main` 最新 commit SHA。
- GitHub Actions run id 和 run attempt。
- `ci-artifact-manifest.json` 的 `branch`、`commitSha`、`runId`、`runAttempt`。
- `junit.xml` 或等价摘要中失败数。
- `static-checks.log` 和 `xcodebuild.log` 的关键错误。
- `ci-failure-summary.md` 是否与实际 outcome 一致。
- artifact 是否来自本轮最新 run，而不是旧 run 或旧输出。

## 4. 本机完整构建

只有人工明确要求“本机测试”“本地 build”“本地 xcodebuild”“本地跑模拟器”等，或云端环境缺失导致必须本机补证时，才默认运行本机完整构建。

命令：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MDJournal.xcodeproj \
  -scheme MDJournal \
  -configuration Debug \
  -destination generic/platform=iOS \
  -derivedDataPath /private/tmp/mdjournal-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
```

当前基线：

- generic iOS Debug build 应以 `** BUILD SUCCEEDED **` 结束。
- 若 Xcode 或 CoreSimulator 环境问题导致失败，必须贴出关键错误并说明是否与本轮代码相关。

## 5. 手动交互验证

当前环境 CoreSimulator 服务不可用时，不要求本机模拟器交互验证，但必须记录原因。

人工或可用模拟器环境下建议验证：

- 新建日记后生成默认 `###` 小节模板。
- 编辑标题、日期、分类、心情和正文后能保存。
- 重启后本地 JSON 数据仍能加载。
- Markdown 预览能渲染标题、段落、引用、列表、待办、代码块、分割线和 `###` 分组。
- 搜索和分类筛选可用。
- 统计看板指标随数据变化。
- iPhone 竖屏和横屏布局不重叠。

## 6. Full

Full 适用于重要里程碑、数据迁移、大范围重构、新增测试 target 或人工明确要求完整验证。

当前 Full 包含：

1. 本地轻量检查。
2. push 到 `origin/main`。
3. GitHub Actions 云端重验证。
4. Agent C 下载并核对结果包。
5. 必要时补本机完整构建或人工交互验证。

如未来新增 XCTest target，再补充：

```sh
xcodebuild test ...
```

当前基线：

- 当前仓库还没有可执行 XCTest 基线。
- 自动化重验证由 `MD Journal CI Results` workflow 承担。

## 7. 规则

- 每次实现前先读本文件。
- 默认本地轻量检查 + 云端重验证。
- 不得伪造本地测试、云端 run、artifact 下载或结果包核对。
- 不得用“验证过”替代具体命令、run id、artifact 名称和结果。
- 文档-only 修改可只跑本地轻量检查，但若本轮目标包含云端流程验证，必须说明是否已 push 并下载 artifact。
- 若新增测试 target、脚本或 CI，必须同步更新本文件、`README.md` 和 `update_log.md`。
