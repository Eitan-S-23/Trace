# Plan: 码表（SpeedometerPage）UI 一比一复刻重做（v3，经 Codex 第 1-2 轮评审修订）
_经 grill 锁定 — by Claude + eitan_
（英文镜像 `PLAN.en.md` 仅为 Codex 评审用临时辅助，本文件为权威计划。）

## Goal（目标）
重做 `lib/pages/speedometer_page.dart`，按设计图一比一复刻「仪表盘 / 统计 / 路线 / 设备」四页及「路线详情 / 设备详情」两详情页。删除顶部分类标签（现已基本无）。底栏固定 仪表盘 / 统计 / 开始-暂停 / 路线 / 设备。用 `power_meter_page.dart` 的「固定头部 + 有界滚动区」模式取代「整页单一 ListView」，消除整页滚动并修复按钮点不动。地图风格化 CustomPaint（记录中画实时轨迹）；数据真实优先、无数据用与设计图一致示例兜底。仅 GitHub Actions 构建（push main → APK/EXE → 自动 Release）。

## 布局契约（精确回应第2轮 #2/#3）
- **根**：`Scaffold > SafeArea > Column([ _TopChrome(固定), Expanded(_SelectedPage), _RideTabBar(固定) ])`；`_SelectedPage` 由 `Expanded` 得到有界高度。
- **每个主 tab 页**（单一 `_TopChrome`/标题栏只在根；tab 固定区仅为**子头**，绝不再放第二个顶部栏——R3#2）返回其一：
  - 有固定子头（统计：周期+日期；设备：雷达+扫描控制；路线：分段+搜索+计数）→ `Column([ 子头..., Expanded(child: 单一滚动体) ])`。
  - 无固定子头（仪表盘）→ tab 有界根用 `LayoutBuilder`（从父 `Expanded` 拿到**有限** maxHeight），其内返回 `SingleChildScrollView(child: ConstrainedBox(minHeight:c.maxHeight, child: 内容))`；**绝不**在滚动体**内部**用 `LayoutBuilder` 测高（那里约束无界）——R3#1。
- **每页恰好一个滚动体、绝不嵌套**：列表页 → `ListView(.builder)` 直接放进 `Expanded`（路线列表、设备可用列表）；非列表页 → `SingleChildScrollView`（仪表盘、统计面板列）。
- **push 详情页**（`Get.to`）= 自带 `Scaffold > SafeArea > Column([ 固定顶部, Expanded(SingleChildScrollView 内容), 固定底部操作栏 ])`，不依赖外层 Expanded（已确认既有 `DeviceDetailPage` 同样以 Scaffold 为根）。

## Approach
### A. 骨架
1. 用上面的根契约替换整页 ListView；删 `_scrollController`/`PageStorageKey`。
2. `_TopChrome` = 设备状态 + 居中标题 + sync/more；标题随页变。设备状态为**静态占位**（不再用 tab 索引伪造、不接 BLE）——回应 R1#5。

### B. 仪表盘（仪表盘.png，单屏）
3. 内容（`SingleChildScrollView` 内，紧凑优先一屏，矮屏可滚、绝不溢出）：英雄卡（风格化地图+总距离大字+时间/均速/爬升/训练负荷）、6 指标卡（2×3+迷你折线）、速度&海拔双线图、功率/心率双环。
4. 区块高度取自 tab 根 `LayoutBuilder`（置于滚动体**之上**）给出的有限高度，而非滚动体内部（R3#1）。
5. 修英雄卡 `Stack` 命中：地图垫底、圆钮置顶层、文字用 `Positioned` 限域，避免 Column 盖住圆钮。
6. 记录中：英雄卡数值就地变实时（`_RideSample`←`RideController`）；地图画 `controller.points` 实时轨迹（无点→示例环线）。

### C. 统计（统计.png + 统计_周_全部.png）
7. 固定子头（无第二顶部栏）：周/月/年/全部（默认月）+ 日期选择器。滚动区按周期切面板：周/月=总览(6)+里程趋势(柱)+时长趋势(柱)；年=类型分布(环)+月度统计(柱1→12)+强度分布(环)；全部=总览(6)+类型分布(环)+月度里程趋势(柱)。
8. 统计=**示例数据驱动的设计复刻**（R1#9）：示例值合设计图；`recentRides` 有数据时仅当前周期总览反映；**不新增 DB 查询**；功率/心率/强度分布纯示例。

### D. 路线 + 路线详情（路线.png 左/右）
9. 固定子头（无第二顶部栏）：分段+搜索+计数。滚动区=`ListView.builder` 示例路线卡（单一滚动体，不再外套 SingleChildScrollView——R2#3）。
10. 卡片点击 → `Get.to(() => _RideRouteDetailPage(...))`，**文件内私有部件**（私有类不与公开 `DeviceDetailPage` 冲突、复用本文件私有 `_GlassPanel/_RideColors/画笔`）——R1#2/#6。
11. 路线详情=自带 Scaffold：返回+标题；风格化地图+全屏/分享；标题/日期/公开；距离·爬升；公路·难度；简介(展开)；海拔 area chart；起/终点·最高海拔；底部固定「发送到设备」+「导航」。地图**纯风格化**（路线是示例数据、不接 DB 取点）——R1#1。

### E. 设备 + 设备详情（设备.png 左/右）
12. 固定子头（无第二顶部栏）：雷达+文案+停止扫描。滚动区=`ListView` 可用设备(连接) + 未找到我的设备。[R3#3] 扫描开关/停止与连接均为**本地视觉状态 + 示例设备**——本次重做**不**调用真实 `BleController`（此处不 `Get.put(BleController())`），以免改动全局 BLE 扫描生命周期；真实扫描仍留在既有 设备/功率计 页。连接=占位。
13. 设备点击 → `Get.to(() => _RideDeviceDetailPage(...))`——**私有名避开公开 `DeviceDetailPage`**（R1#2）。
14. 设备详情=自带 Scaffold（返回+标题；设备图+已连接/固件/电量；设置/页面配置/传感器+自动暂停/自动计圈开关；设备信息；解除绑定），内容在 SingleChildScrollView。

### F. 地图与图表（健壮性）
15. `_RouteMapPainter` 加可选 `List<RidePoint> track`：映射前清洗——剔 NaN/Inf、纬经跨度为 0 兜底示例环线、忽略异常坐标（R1#7）。
16. **审计所有画笔加空/零保护**（R1#8）：`values.length<2`、`maxValue<=0`、`labels.length<=1`、`total<=0` 时提前返回/画空态，杜绝除零/NaN。

### G. 底栏与交互
17. `_RideTabBar` 维持五项。中间键 `isRecording ? pauseResume() : start()`；**记录中显示可见的 停止/保存 控件**（中间区显示暂停+显式停止键，或计时旁停止芯片）→ `saveCurrentRide()`，移动端与 Windows 桌面均可点（R2#4，非长按）。
18. 核心交互真实；外围按钮 `_showUiMessage` 优雅占位。

### H. 验证与发布（以分阶段回应 R2#5）
19. 无法本地编译；CI `flutter analyze`(continue-on-error) + `flutter build apk`/`build windows` 是真正门槛。严控 Dart 正确性（const/泛型/null 安全/`shouldRepaint`/私有作用域）。
20. **分阶段 push**，让脆弱大文件增量落地、CI 逐段把关：S1 骨架+四 tab 编译通过；S2 路线/设备私有详情页；S3 还原度打磨。详情页复杂度不前置。
21. push `main` → Actions → 自动 Release；本机 `gh` 未认证，由用户看/装 Release 验证。

## Key decisions & tradeoffs
- 固定头部 + 每 tab 单一有界滚动体：解决整页滚动/点不动/溢出崩溃。
- 详情页=文件内私有部件（非公开类、非 part 文件）：避开 `DeviceDetailPage` 同名、复用私有部件、规避拆文件 import 风险与 `part/library` 结构性新机制在无本地构建下的风险。
- 风格化地图 + 记录中实时轨迹；路线详情纯风格化。
- 统计=示例驱动复刻、零 DB 改动。
- 顶部设备状态=静态占位。
- 真实优先+示例兜底（主要用于实时仪表盘）。

## Risks
- 构建风险最高（无本地编译、历史有 build errors）。缓解：保守写法、复用既有 widget、画笔空/零保护、分阶段 push、S1 仅编译骨架。
- 矮屏适配→ SingleChildScrollView 兜底（头部固定）。
- 文件增大（>4500 行）：接受，分阶段防回归，后续再议拆分。
- 轨迹/聚合数据有限→ 风格化地图+示例统计、不加 DB。

## Out of scope
- 真实地图 SDK；保存路线 DB 取点；统计聚合新 DB 查询。
- now.jpg 式独立实时表盘页；训练页。
- 外围按钮后端逻辑。
- `MainAppPage` 三标签结构；`DatabaseService`/模型结构性改动。
