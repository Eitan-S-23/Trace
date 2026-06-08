# Plan Review Log: 码表 UI 一比一复刻重做
Act 1（grill）完成 — 计划已与用户锁定。MAX_ROUNDS=5。

## Round 1 — Codex（model gpt-5.5，read-only，medium effort，session 019ea7dd）

VERDICT: REVISE。10 条发现（原文要点）：
1. 路线详情想用 `RideController.recentRides` 画真实 GPS 轨迹，但 `RideSession` 不含轨迹点，`RideController.points` 只暴露当前实时骑行。修：为选中骑行加 DB 取点路径，或声明路线详情仅风格化/示例。
2. 新增公开 `DeviceDetailPage` 会与已存在、被 `PowerMeterPage` 引用的 `lib/pages/device_detail_page.dart` 同名冲突。修：改名 `RideDeviceDetailPage` 等。
3. 开始/暂停规格不全：未记录时 `pauseResume()` 是空操作，且没有 停止/保存/结束 入口。修：中间键 `isRecording ? pauseResume() : start()`，并提供可达的保存/停止动作。
4. 「固定头部 + Expanded 选中页」若 `_DashboardPage` 仍是固定高 `Column` + 大卡片、无滚动兜底，仍会溢出。修：每个 tab 用 `LayoutBuilder` 驱动，高度不足时内容包 `SingleChildScrollView`。
5. `_TopChrome` 要显示真实设备状态/型号，但 `RideController` 无 BLE/连接字段，现在靠 tab 索引伪造连接。修：要么接入既有 BLE 控制器，要么标注为静态占位 UI。
6. 在超大私有单文件里塞详情页增加编译风险、类型/命名错误难定位。修：把新详情页放进唯一命名的独立文件并显式 import。
7. 轨迹归一化只提到空/单点，未处理同纬/同经、非法坐标、NaN、跨 180° 子午线。修：映射前清洗点、对零经纬跨度加保护。
8. 复用图表画笔有除零风险：`_BarChartPainter` 除以 `values.length`、`labels.length-1`、`maxValue`；空周期会崩/画 NaN。修：所有画笔对空列表/单标签/非正最大值提前返回或画空态。
9. 周/月/年/全部聚合超出 `RideController` 现有 API，很可能需要被划为 out-of-scope 的 `DatabaseService` 访问。修：把统计约束在已加载的 `recentRides` 字段，或先（只读）扩展控制器/API。
10. `PLAN.md` 是乱码，实施者误读中文串/部件名有 CI 成本。修：实施前用合法 UTF-8/ASCII 重写计划。

### Claude's response（最终仲裁人）
已用代码核实后处置：

- **采纳并改计划**：#1 路线详情地图改为风格化（路线本就是示例数据），不新增 DB 取点；仪表盘英雄卡在记录中用 `controller.points` 画实时轨迹。#2+#6 两个详情页一律做成 speedometer_page.dart 内**文件作用域私有部件**（`_RideRouteDetailView`/`_RideDeviceDetailView`），私有类不会与公开 `DeviceDetailPage` 冲突——既解决同名又避免拆文件带来的共享私有部件/import 风险（#6 的"必须拆文件"部分按此理由部分保留）。#3 中间键 `isRecording?pauseResume():start()`，记录中长按中间键弹确认并 `saveCurrentRide()` 结束保存。#4 每个 tab 内容统一包 `SingleChildScrollView`（在 `Expanded` 内），正常机型一屏放下、矮屏可滚、绝不溢出崩溃。#5 顶部设备状态降级为**静态占位**（不谎称真实，不接 BLE，避免扩面）。#7 轨迹点清洗（剔除 NaN/Inf、零经纬跨度兜底为示例环线）。#8 审计所有画笔加空/零保护（`values.length<2`、`maxValue<=0`、`labels.length<=1` 提前返回/空态）。#9 统计页定位为**示例数据驱动的设计复刻**，`recentRides` 有数据时仅反映当前周期总览，不新增 DB 查询；功率/心率/强度分布纯示例（设备无此数据）。
- **拒绝（附理由）**：#10。已验证 `PLAN.md` 为合法 UTF-8 无 BOM（首字节 `23 20 50`=`# P`）。乱码是 Codex 在 Windows 区域设置下读取工具误解码 UTF-8 所致（本机 bash 显示中文同样乱码）；Dart/Flutter 源码按 UTF-8 编译，现有已提交的 `speedometer_page.dart` 满是中文串且能构建，故无需改动。

## Round 2 — Codex（恢复同一会话 019ea7dd，read-only，medium effort）

VERDICT: REVISE。5 条：
1. PLAN.md 仍乱码（#10 未解），实施者可能误读。修：用合法 UTF-8/ASCII 重写。
2. 骨架 `Column([_TopChrome, Expanded(_SelectedPage), _RideTabBar])` + 「每页 Column([fixed, Expanded(SingleChildScrollView)])」对无固定子头的页/经 `Get.to` 进入的页不成立（无界 Expanded 无效）。修：逐页明确有界根——主 tab 由父级 Expanded 提供边界；push 详情页用 `Scaffold>SafeArea>Column>Expanded(scroll)`。
3. 路线页滚动区写成 `ListView`，又规定每页 `Expanded(SingleChildScrollView)`；`ListView` 套 `SingleChildScrollView` 会无界/滚动差。修：每页只一个滚动体，列表用 `ListView.builder` 直接放进 Expanded。
4. 长按中间键保存太隐蔽，桌面/Windows 不可达。修：记录中加显式可见的 停止/保存。
5. 详情页私有塞进超大 `speedometer_page.dart` 降 import 风险但升最脆弱文件的编译/回归风险。修：拆私有 part 文件并提取共享部件，或首版最小化、推迟详情页复杂度。

### Claude's response
- **采纳并改计划（v3）**：#2 写入精确「布局契约」——根 = `Scaffold>SafeArea>Column([_TopChrome,Expanded(_SelectedPage),_RideTabBar])`；有固定子头的 tab = `Column([固定,Expanded(单一滚动体)])`，无固定子头（仪表盘）直接单一滚动体；push 详情页自带 `Scaffold>SafeArea>Column>Expanded(SingleChildScrollView)`+固定底栏（已核实既有 `DeviceDetailPage` 以 Scaffold 为根）。#3 每页恰好一个滚动体、绝不嵌套：列表 `ListView.builder` 直接进 Expanded，非列表用 SingleChildScrollView。#4 记录中显示**可见**停止/保存控件（非仅长按），移动+桌面均可点。#5（spirit）分阶段 push：S1 骨架+四 tab 绿 → S2 详情页 → S3 打磨。
- **拒绝（附理由）**：#1 已生成英文镜像 `PLAN.en.md` 供 Codex 阅读（中文 `PLAN.md` 经验证合法 UTF-8，仅 Codex Windows 读取器误解码）。#5 的「现在就拆 Dart part 文件」部分——在无本地构建下引入 `part/library` 指令属结构性新机制、本身有 CI 失败风险，且 part 只是转移而非降低风险；改以「文件内私有部件 + 分阶段 push」达成同样的增量把关目的。

## Round 3 — Codex（恢复同一会话，读 `PLAN.en.md`，read-only，medium effort）

编码问题（#1）已消除。VERDICT: REVISE，仅 3 条（持续收敛 10→5→3）：
1. 仪表盘说内容在 `SingleChildScrollView` 内又用 `LayoutBuilder` 按可用高度分配——滚动体内高度约束无界/无限。修：`LayoutBuilder` 放在有界 tab 根算视口高度，再据有限约束构建滚动内容。
2. 多处 tab 固定区写「顶部栏」，但 `_TopChrome` 已在根固定——会重复头部、浪费有界高度。修：tab 固定区仅为子头，绝不再放顶部栏/标题栏。
3. 设备扫描开关写成真实核心交互，但未说明是否接既有 BLE 控制器；误 `Get.put(BleController())` 会全局改变扫描生命周期。修：明确复用既有 BLE 模式，或本次重做将扫描降级为占位。

### Claude's response（全部采纳）
- #1：`LayoutBuilder` 置于 tab 有界根（滚动体之上）取有限 maxHeight，内部用 `SingleChildScrollView(ConstrainedBox(minHeight:c.maxHeight,...))`；不在滚动体内测高。
- #2：tab 固定区一律仅子头；唯一 `_TopChrome` 在根。
- #3：设备页用本地视觉状态 + 示例设备，**不**调用真实 `BleController`、不 `Get.put(BleController())`，连接=占位；真实扫描仍归既有 设备/功率计 页（避免全局生命周期副作用）。
- 三处均已写入 `PLAN.md` v3 与 `PLAN.en.md`。

## Round 4 — Codex（恢复同一会话，read-only，medium effort）

VERDICT: REVISE，仅 1 条（措辞漂移）：
1. 统计 step 7、路线 step 9 仍写「Fixed: top bar」，与「仅根持有 `_TopChrome`」契约矛盾；Codex 自评为 wording drift，若照字面会重复头部。修：改为「fixed subheader」。

### Claude's response（采纳）
- 已将统计 step 7、路线 step 9 的「固定：顶部栏」改为「固定子头（无第二顶部栏）」，`PLAN.md` 与 `PLAN.en.md` 同步。纯文档一致性，无实现影响。

## Round 5 — Codex（恢复同一会话，read-only，medium effort）

**VERDICT: APPROVED** ✅

收敛轨迹：10 → 5 → 3 → 1 → APPROVED（5 轮）。计划已通过跨模型对抗式评审，等待用户最终签字后进入实现（分阶段 push：S1 骨架→S2 详情页→S3 打磨）。
