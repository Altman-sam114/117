# 项目流程图

## 当前模块与状态边界

```mermaid
flowchart TD
  App["MDJournalApp / 共享 Store、订阅、应用锁"] --> Gate["JournalPrivacyGate / 窗口级隐私遮罩"]
  Gate --> Content["ContentView / 唯一选中、筛选、sheet"]
  Content --> Compact["手机 compact / NavigationStack + UUID path / 列表无原生selection回写"]
  Content --> Regular["iPad regular、Catalyst / NavigationSplitView"]
  Compact --> Library["年月资料库 / NavigationLink / 新建 / 设置"]
  Regular --> Library
  Library --> Editor["标题 FocusState / 正文 UIKit / UTF-16"]
  Editor --> Mutation["JournalStore 唯一 mutation"]
  Library --> Mutation
  Mutation --> Health{"原文件读取成功？"}
  Health -- "否" --> Protect["拒新建/更新/删除/导入/flush / 保留原字节"]
  Protect --> Recovery["设置：恢复导出 / 重读成功后解锁"]
  Health -- "是" --> State["内存日记 + 当前篇有限正文投影"]
  State --> ListStats["列表、概览、统计 / 只消费展示值"]
  State --> Save["450ms debounce / revision快照 / actor atomic JSON"]
  Save --> File["私有Documents / iOS系统文件保护 / OS设备备份"]
  Editor --> Preview["150ms latest-wins / parser + 同文档inline cache"]
  Editor --> Share["实际分享时生成完整UTF-8 Markdown"]
```

## 备份与系统认证

```mermaid
flowchart LR
  Settings["设置"] --> Export["免费完整JSON后台编码 / 系统fileExporter"]
  Settings --> Import["security-scoped文件 / 25MiB与10000篇校验"]
  Import --> Preview["唯一ID / 新增与保留预览 / revision"]
  Preview --> Confirm{"用户确认且预览未过期？"}
  Confirm -- "是" --> Store["Store只追加新ID / 不覆冲突 / 一次快照保存"]
  Confirm -- "否" --> Keep["现有集合不变"]
  Settings --> Lock["应用锁偏好 / UserDefaults CA92.1"]
  Lock --> LA["系统设备所有者认证 / 无生物数据读取"]
  Background["后台 / 过期请求"] --> Generation["锁定 / invalidate / generation拒迟到结果"]
  Inactive["willResignActive"] --> Shield["窗口顶层遮罩 / 收键盘 / 覆盖sheet"]
  LA --> Active["认证成功且generation有效才显示日记"]
  Generation --> Shield
```

## 订阅与高级导出

```mermaid
flowchart TD
  Products["Apple Product / 实际价格与周期"] --> Paywall["Pro页 / 隐私、EULA、恢复、管理"]
  Paywall --> Purchase["purchase / pending、cancel、verified、unverified"]
  Updates["Transaction.updates / currentEntitlements / 前台与到期刷新"] --> Verify["白名单 / 已验证 / 未撤销升级 / 有限期限与宽限期"]
  Purchase --> Verify
  Verify --> Entitled{"有效 Pro？"}
  Entitled -- "是" --> Filter["日期与分类选择 / 稳定日期排序"]
  Filter --> Actor["导出actor / 完整Markdown / CoreText分页PDF"]
  Actor --> Recheck["生成后仍有权益且未取消"]
  Recheck --> Files["用户选定目的地 / fileExporter"]
  Entitled -- "否" --> Free["保留免费编辑、预览、统计、单篇分享和JSON备份"]
```

## 当前并行实施与云端验证

用户选择按板块并行，覆盖旧的 A→B→C 串行轮转。功能与发布 archive 两个云端 job 对应同一提交。

```mermaid
flowchart TD
  User["人工目标 / 模块并行 / 云端编译"] --> Mobile["手机导航、焦点、长文派生"]
  User --> Safety["设置、备份、隐私、应用锁、原文件保护"]
  User --> Pro["StoreKit 2 / Markdown与PDF高级导出"]
  Mobile --> Integrate["主线程工程集成 / main直推"]
  Safety --> Integrate
  Pro --> Integrate
  Integrate --> Regression["Xcode16.4/iOS18.5 / 全量XCTest / 25图 / iOS与Mac构建"]
  Integrate --> Archive["Xcode26.2/iPhoneOS26.2 / Release设备archive / 实际Info链接及商品ID / 不用模拟器"]
  Regression --> Results["两个未加密artifact / manifest、JUnit、日志、xcresult"]
  Archive --> Results
  Results --> Review["最新同SHA/run/attempt下载 / digest、CRC、哈希 / 逐图与交易核验"]
  Review --> Gate{"通过？"}
  Gate -- "否" --> Fix["按具体失败追加修复 / 同因失败按规则停止"]
  Fix --> Integrate
  Gate -- "是" --> Account["真实团队、商品、协议、定价、签名、真机与Sandbox/TestFlight"]
  Account --> Upload["账号条件满足后才上传App Store / 不预称已审核"]
```
