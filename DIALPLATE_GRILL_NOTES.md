# Dialplate HUD Redesign Grill Notes

## Source Request
- Redesign the current bike-computer dialplate/dashboard UI to closely match `generated-images/2.png`.
- Use `frontend-skill` design discipline.
- Rework the dashboard code so the phone/PC upper app can update or change the dashboard through BLE later.
- Use `grill-me-codex`; keep live notes in a file to avoid losing detail.

## Confirmed From First Pass
- Design reference: cyber HUD bike-computer dashboard with dark map background, cyan cut-corner panels, neon-green route/navigation, large speed readout, right-side metric stack, bottom three-tab nav.
- Current dashboard page is under `USER/App/Pages/Dialplate`.
- BLE code exists under `USER/HAL/HAL_Bluetooth.cpp` and `Libraries/Bluetooth`.
- Worktree is already dirty; implementation must avoid reverting unrelated changes.
- Hardware display config: `USER/HAL/HAL_Config.h` defines `CONFIG_SCREEN_HOR_RES=240`, `CONFIG_SCREEN_VER_RES=320` (portrait).
- LinuxSDL2 simulator Makefile currently builds `LV_HOR_RES=480`, `LV_VER_RES=320` (landscape).
- Current `DialplateView` is a simple hard-coded LVGL layout: gray top speed panel, four bottom values, three icon buttons.
- Current BLE parser accepts `+...\r\n` packets, logs/echoes them, and does not yet dispatch dashboard/theme/config commands.
- Existing storage layer can persist registered scalar/string fields to `/SystemSave.json`; a dashboard config node can reuse this pattern if kept compact.
- Existing LiveMap has real tile/track rendering but is heavier and page-local; Dialplate can either reuse/adapt it or draw a lightweight HUD route preview.

## Frontend-Skill Framing Draft
- Visual thesis: futuristic cycling HUD, deep-map cockpit surface, cyan technical framing, neon-green active route/navigation energy.
- Content plan: top status/navigation, central map/route, large speed block, secondary metric stack, bottom action/navigation bar.
- Interaction thesis: lightweight LVGL animations only where safe on MCU: active route pulse, selected bottom tab glow, metric value transitions.

## Grill Status
- Act 1 started.
- Code inspection complete enough to start decisions.

## Decision Log
- Q1 target layout orientation and pixel-fit strategy:
  - User decision: target hardware and simulator as `240x320` portrait.
  - Implementation implication: update LinuxSDL2 simulator from `480x320` to `240x320`, and design Dialplate coordinates for portrait first.
  - Recommended layout strategy accepted: preserve the design reference's visual hierarchy and proportions, scaled to 240x320 rather than making a landscape adaptation.
- Q2 center map/route fidelity:
  - User decision: use the recommended lightweight HUD route preview.
  - Route preview should mimic the design: dark map-like background, blue road/grid strokes, neon-green route, current-position triangle, small waypoint labels.
  - Do not embed/reuse LiveMap's real tile map inside the dashboard for this redesign.
  - Critical requirement: current-position arrow must point to the actual current travel direction.
  - Implementation implication: subscribe/pull `GPS_Info` in `DialplateModel` and rotate the HUD arrow using `GPS_Info.course`.

## Watchface System Deep Dive

### Industry Patterns
- Low-power bands/watches commonly use a watchface package rather than arbitrary remote code. The package usually contains a manifest plus bitmap resources, fonts, widget definitions, data bindings, and checksums.
- Small MCU-class devices often render a static background bitmap plus dynamic overlays for time/speed/heart rate/battery/steps. This is cheap, safe, and lets downloaded watchfaces look completely different.
- Mid-range proprietary systems often use a declarative layout: JSON/TLV/binary manifest describes widgets, coordinates, colors, image IDs, number format, z-order, and data source. Firmware interprets the manifest with a fixed safe renderer.
- Higher-end systems can run sandboxed apps or scripts, such as full watch apps/watch faces. This allows arbitrary logic but requires much more RAM/flash/OS support and is not a good fit for the current AT32 + LVGL firmware.
- Most systems validate model/resolution/version/checksum before install, transfer packages in BLE chunks, write to a temporary slot, then atomically activate after the package is complete.
- Devices store multiple watchfaces in internal flash or external storage. The active face is just an ID/path in persistent settings. Failed installs keep the previous active face.

### Fit To This Project
- Display target is 240x320 portrait.
- MCU firmware already uses LVGL, SD filesystem, and a custom PNG object that can read PNG files through `lv_fs`.
- Existing `/SystemSave.json` persistence is suited for active watchface ID and small settings, not for large watchface asset payloads.
- BLE currently has only a 256-byte `+...\r\n` packet parser and echo path. A real watchface update needs chunking, offset, CRC/checksum, package metadata, and install/commit commands.
- Flash/RAM from the current map file: IROM max 1MB, current RO about 305KB; IRAM max 384KB, current RW/ZI about 258KB. Full-screen decoded frame buffers must be avoided; stream/decode assets line-by-line or use LVGL image paths.
- SD card is the pragmatic storage target for multiple downloadable watchfaces. Internal flash should keep only firmware and small settings.
- `lv_port_fs_sdfat.cpp` exposes LVGL read/write/dir operations but not mkdir/remove/rename. `HAL_SD_CARD.cpp` uses a non-static `SdFatSdioEX SD` and already creates the track directory with `SD.mkdir`.
- Watchface installation will need a small controlled SD operation layer: ensure directory exists, write/truncate chunk files, remove temp install leftovers, and optionally rename/commit folders.

### Recommended Architecture For This Task
- Implement the design reference as the first built-in/default watchface using the same watchface runtime that remote packages will use.
- Define a `Watchface` package format now:
  - `manifest.json` or compact binary/TLV manifest with `id`, `name`, `version`, `targetWidth=240`, `targetHeight=320`, `entry`, `assets`, `widgets`, `dataBindings`, and `crc`.
  - Assets stored under `/Watchfaces/<id>/`, for example PNG backgrounds/icons and optional font names.
  - Widgets are safe built-in types: `image`, `label`, `metric`, `line`, `polyline`, `panel`, `button`, `routePreview`, `statusIcons`.
  - Data sources are whitelisted: speed, avgSpeed, maxSpeed, tripDistance, elapsedTime, calorie, gpsSatellites, gpsCourse, battery, recState.
- BLE update protocol should install package files in chunks:
  - `+WF_BEGIN:{...}\r\n`
  - `+WF_CHUNK:<file>,<offset>,<crc>,<base64-or-hex>\r\n`
  - `+WF_END:<package_crc>\r\n`
  - `+WF_ACTIVATE:<id>\r\n`
  - `+WF_LIST?\r\n`, `+WF_DELETE:<id>\r\n`, `+WF_ACTIVE?\r\n`
- Keep arbitrary scripting out of scope for the first version. A declarative renderer is enough to make faces look completely different while keeping memory and crash risk controlled.
- The current HUD design should be represented as a built-in manifest/default style, so later downloaded faces use the same rendering pathway.

## Updated Decisions
- Q3 BLE/watchface change boundary:
  - User accepted the recommended boundary.
  - Support a safe declarative watchface/package system, not arbitrary remote code.
  - BLE should update installable watchface packages, including assets and manifests, with validation and persistence.
- Q4 task scope:
  - User confirmed this task is upgraded to "watchface system v1".
  - Scope is no longer only repainting `Dialplate`; it includes default HUD watchface, local multi-watchface storage/loading/switching, and BLE install protocol framework.
- Q5 watchface storage:
  - User accepted the recommendation.
  - Store downloadable watchface packages on SD card under `/Watchfaces/<id>/`.
  - Keep a built-in default HUD watchface fallback in firmware for no-SD, missing active face, corrupt manifest, or failed install.
  - Persist only lightweight state such as active watchface ID in `/SystemSave.json`.
- Q6 first-version widget capability:
  - User accepted the recommendation.
  - Supported built-in widget types: `image/background`, `label/metric`, `panel`, `line/polyline`, `routePreview`, `statusIcon`, `button`.
  - Per-widget config should include position, size, color, font, format, data source, z-order, and display condition where practical.
  - Explicitly out of scope for v1: arbitrary scripts, complex animation engine, custom touch logic, and dynamic third-party font loading.
- Q7 package and BLE transfer format:
  - User accepted the recommendation.
  - Watchface package v1: `manifest.json` plus PNG/bin assets.
  - BLE transport remains compatible with current `+...\r\n` packet framing, expanded with watchface install/list/delete/activate commands.
  - Chunk payload should use HEX encoding in v1 to avoid control-character framing problems.
  - Install into a temporary path such as `/Watchfaces/.install/<id>/`; validate manifest/files/CRC before committing to `/Watchfaces/<id>/`.
  - Failed installs must not affect the active watchface.
- Q8 default HUD watchface dependency:
  - User accepted the recommendation.
  - Default HUD watchface should be built into firmware as a manifest/config and drawn with LVGL primitives, not dependent on SD-card images.
  - Downloaded watchfaces can use SD-card PNG/bin assets.
  - No-SD or corrupt active-face fallback must still show the full default dashboard.
- Q9 BLE watchface update implementation depth:
  - User accepted the recommendation.
  - Implement a complete command/protocol framework and a minimum usable install loop.
  - Required v1 commands: `WF_BEGIN`, `WF_CHUNK`, `WF_END`, `WF_LIST`, `WF_ACTIVE`, `WF_ACTIVATE`.
  - `WF_BEGIN` creates an install session, `WF_CHUNK` writes file fragments, `WF_END` validates manifest/files and registers the watchface.
  - Out of scope for v1: resume after disconnect, compressed archive extraction, old-resource garbage collection, and phone-side package builder.

## External App Agent Spec
- User requested a separate file for the AI agent working on the independent phone/upper-computer app project.
- Created `WATCHFACE_APP_AGENT_SPEC.md`.
- Purpose: document package layout, manifest schema, supported widgets/data sources, BLE framing/commands, expected responses, install flow, and v1 scope boundaries for the external app implementation.
- This file should be kept in sync with the final locked plan and any implementation changes.

## Correction
- Q10 was incorrectly framed as choosing which design-reference elements to keep.
- User clarified the original requirement: replicate `generated-images/2.png`.
- Correct interpretation: default HUD watchface must preserve the design reference's structure and visual hierarchy as closely as possible on 240x320 portrait.
- Scaling is allowed; arbitrary removal of major modules is not.
- If the 240x320 size forces simplification, it should be detail-level simplification only: thinner/shorter labels, fewer tiny decorative ticks, simplified chart detail, abbreviated text, and tighter typography.
- User confirmed this corrected Q10 interpretation.
- Q11 missing data source handling:
  - User accepted the recommendation.
  - Bind real firmware data where available: speed, average speed, elapsed time, trip distance, calorie, altitude, GPS satellites, GPS course/direction, battery/BLE state if accessible.
  - Data not currently available should be represented by configurable placeholder fields in the built-in face/watchface manifest.
  - Placeholder defaults should preserve the design reference: navigation distance/instruction/street, heart rate `145`, grade `3.2%`, waypoint labels, etc.
  - Future phone app/navigation modules can update those fields without changing the visual renderer.
- Q12 bottom action behavior:
  - User accepted the recommendation.
  - `MAP` opens `Pages/LiveMap`.
  - `REC` keeps current record behavior: short press pause/continue, long press start/ready-stop/stop depending on state.
  - `MENU` should open `Pages/MainMenu`, not `Pages/SystemInfos`.

---

# 最终锁定计划（对抗式评审后修订版）

本章为第二幕对抗评审（见 `PLAN-REVIEW-LOG.md` Round 2–3，共 15 条）后修订的可落地计划。
所有结论附 `file:line` 证据；本章取代上文 Q1–Q12 中与之冲突的部分（冲突处以本章为准）。

## Goal（目标）
在 AT32F435（240×320 portrait，LVGL v8，剩余 RAM ~80KB + LVGL 堆 72KB）上，先以硬编码 LVGL 高保真复刻 `generated-images/2.png` 的默认 HUD 表盘并接入真实数据；再在其上增量构建“本地多表盘存储/切换 + 声明式简单表盘 + BLE 非阻塞分片安装”的表盘系统 v1。全程不引入任何 >1s 的同步阻塞，确保 10s 看门狗不被饿死。

## 范围分层（评审⑤收窄的关键决策）
- **v1 核心（必交付）**：默认 HUD 表盘硬编码复刻 `2.png` + 真实数据绑定 + 占位字段。
- **v1 框架（交付）**：本地多表盘存储/加载/切换；BLE 收发层重写；BLE 非阻塞分片安装；声明式渲染器**仅简单 widget**（image 小图标 / label / metric / panel / line）。
- **v2 推迟**：复杂 widget 的声明式化（routePreview/旋转箭头/柱状图仅在内置默认表盘硬编码）、断点续传、压缩包、旧资源 GC、手机端打包器、心率/导航/坡度真实数据。

## Approach（分阶段，每阶段须可独立编译验证）

### 阶段 1：默认 HUD 表盘硬编码复刻（最高优先，独立交付）
- 沿用现有 MVP 模式扩展 `DialplateView.cpp`（`USER/App/Pages/Dialplate/`），**不走 manifest 路径**（评审⑤）。
- 布局（竖屏，参照 `2.png`，评审⑭撤回了几何冲突顾虑、改为可读性取舍）：
  - 顶部状态条：GPS/电量/蓝牙图标 + 转向导航块（距离/指示/路名，占位）+ 右上海拔/坡度（海拔真实、坡度占位）。
  - 中部 routePreview：`lv_line` 画霓虹绿路线 + `lv_img`+`lv_img_set_angle` 画当前位置黄三角（小图标，RAM 可控）+ 路点标签（占位）。
  - 左侧大速度数字（真实）+ 左下 MAX 柱状图（真实 max）。
  - 右侧指标栈：AVG / TIME / TRIP / CAL（全真实）。
  - 底部三按钮 MAP / REC / MENU。
- **背景**：纯 LVGL 绘制（深色 + 网格线 `lv_line`/色块），**禁止全屏 PNG 背景**（评审⑩）。
- **图标**：编译进 Flash 的 C 数组图片（沿用 `ResourcePool::GetImage`），**不在内置表盘里用运行时 PNG 解码**（评审⑩：lv_img_png 每帧重解码，`lv_img_png.cpp:158,247,262`）。
- **箭头方向**（评审⑬）：`account->Pull("GPS")` 取 `GPS_Info.course`（`HAL_Def.h:28`，`HAL_GPS.cpp:101`）；低于速度阈值（如 <2km/h）冻结朝向；course 角做低通滤波，避免静止抖动乱转。
- **字体**（评审⑭）：按 `2.png` 字号补充所需字体资源（Flash 余量 ~733KB，可接受）。
- **辉光**（评审⑭）：neon glow 用预渲染小图标或半透明描边近似，不依赖 LVGL box-shadow blur。

### 阶段 2：本地多表盘存储 / 加载 / 切换（不依赖 BLE）
- 持久化“当前激活表盘 ID”到 `/SystemSave.json`（仅小标量）。
- 启动加载顺序：读 active id → 加载该表盘 → 失败回退到内置默认 HUD（评审：无 SD / manifest 损坏 / 无 `.ready` 均回退，全程仍显示完整默认表盘）。
- **页面/对象生命周期**：表盘切换时彻底释放上一表盘的 lv_obj、定时器、`Account` 订阅（参照 `DialplateView::Delete` 现仅清 anim_timeline，`DialplateView.cpp:42-49`，需扩展为完整清理），防止 72KB 堆上反复切换导致 OOM。

### 阶段 3：BLE 收发层重写（安装功能的前置，评审④⑨⑮）
现状证据：`Bluetooth.cpp:41` 写包无长度上限、`pRxPacket` 为 `uint8_t` 会回绕覆写；`:53-54` 收满包只空壳 `OTA()`+原样 echo、无命令分发；`HAL_Bluetooth.cpp:63` 每帧无条件发 `X-Trace`；`HAL_Bluetooth.cpp:44` `BT_printf` 仅 100B 栈缓冲。
- 接收：带长度上限的状态机/环形缓冲，超长丢弃整包并报错，不再回绕覆写。
- **移除** `HAL_Bluetooth.cpp:63` 每帧 `X-Trace` 与 `Bluetooth.cpp:54` 原样 echo（清洁上行，便于 ACK/流控）。
- 命令分发：表驱动注册表（命令字 → handler），替代现 if/echo。
- 响应：分片发送 API 替代 100B `BT_printf`，`WF_LIST` 等长响应分多帧。
- CRC：优先复用项目内 zlib crc32（`USER/App/Utils/lv_img_png/PNGdec/src/crc32.c`）；若该符号为 `local`/未导出导致链接不通，则内置一个独立紧凑 CRC32 查表实现（256 项表，~1KB Flash）。

### 阶段 4：声明式简单 widget 渲染器（下载表盘用，评审⑤⑫）
- manifest 用 `manifest.json`，解析复用已集成的 **ArduinoJson v6**（`USER/App/Utils/ArduinoJson`）。
- **v1 仅支持简单 widget**：`image`(小图标) / `label` / `metric` / `panel` / `line`。复杂控件（routePreview/旋转箭头/柱状图）**不**纳入声明式，只在内置默认表盘硬编码。
- 数据绑定：白名单数据源字符串 → 运行时映射到 `Account` 数据 + 单位/格式化（见“数据绑定清单”）。
- 下载表盘若用 PNG：仅限小图标且数量受限；明确告知每帧解码开销（评审⑩）。

### 阶段 5：BLE 非阻塞分片安装状态机（评审②⑨⑮）
- **文件操作直接走 `SdFatSdioEX SD`（非 lv_fs）**：lv_port_fs 无 mkdir/remove/rename（`lv_port_fs_sdfat.cpp:27-37`），且 `fs_open` 写模式不带 O_CREAT（`:106-119`）。新增小 SD 操作层（extern 全局 `SD`，`HAL_SD_CARD.cpp:8`）补齐：确保目录存在、`O_CREAT|O_TRUNC` 写、删文件、**递归删目录**（SdFat 无现成递归删除）。
- **非阻塞状态机**（评审⑨核心）：`IDLE → RECEIVING → VALIDATING → COMMIT`，由 `BT_Update`（每 200ms，`HAL.cpp:107`）每次只推进一小步；单次 SD 写压在百 ms 级；CRC **增量**计算；严禁任何 >1s 同步阻塞（看门狗 10s，`HAL_Config.h:209`，喂狗每 1s `HAL.cpp:101`）。
- **提交策略（放弃伪原子 rename，评审②）**：所有文件写入 `/Watchfaces/.install/<id>/`，全部校验通过后写入 `.ready` 标记文件；激活逻辑**只认带 `.ready` 的目录**；随后在后续 tick 内删除旧目录并落位。FAT 无原子 rename 保证，`.ready` 标记规避半提交。
- **会话边界**（评审⑮）：WF_CHUNK 无 BEGIN→拒绝并报错；重复 BEGIN→中止旧会话；WF_END 缺文件/CRC 不符→整体丢弃 `.install/<id>`；会话 N 秒无 chunk 自动中止；**启动时清理 `/Watchfaces/.install/` 残留**。
- 失败绝不影响当前激活表盘。

## 内存预算表（评审①⑪⑫，硬约束）
基线：RAM 已用 304KB / 384KB，余 ~80KB（`X-Track.map:29100`）；LVGL 堆 `LV_MEM_SIZE=72KB`（`lv_conf.h:61`），表盘对象从此分配。

| 组件 | 类型 | 上限 | 说明 |
|---|---|---|---|
| 单个表盘 lv_obj 树 | 常驻(LVGL堆) | ~20KB | 切换时必须完整释放（阶段2） |
| routePreview lv_line 点数组 | 常驻 | ≤1KB | 几十个点×4B |
| 旋转箭头 lv_img 小图标 | 常驻 | ≤2KB | 如 32×32 RGB565 |
| manifest JsonDocument | 瞬时(栈/静态) | ≤4KB | StaticJsonDocument，超限判非法 |
| BLE 安装会话 | 常驻 | ≤2KB | 文件句柄+chunk行缓冲+CRC上下文 |
| PNG 解码 zlib 窗口 | 瞬时(lv_mem_buf) | ~32KB | 仅解码瞬间占用，用后释放；故禁止每帧/全屏解码 |
| PNG 行缓冲 | 瞬时 | ≤512B | `lv_img_png.cpp:260` |
- **禁止**：240×320 全屏 RGB565 常驻帧缓冲（=150KB，超余量两倍）。

## BLE 协议（修订版）
- 帧仍兼容 `+...\r\n`；chunk 用 HEX（避免控制字符）。
- 命令：`WF_BEGIN`（建会话）/ `WF_CHUNK:<file>,<offset>,<crc>,<hex>` / `WF_END:<pkgcrc>` / `WF_LIST` / `WF_ACTIVE` / `WF_ACTIVATE:<id>` / `WF_DELETE:<id>`。
- 每命令有结构化响应；错误回包 `+WF_ERR:<stage>,<code>`（评审 C：可观测性）。

## 数据绑定清单（评审⑥，管理预期）
- **真实可绑定**：speed / avgSpeed / maxSpeed / tripDistance / elapsedTime / calorie / altitude / gpsSatellites / gpsCourse / battery / recState / BLE 连接态。
- **占位字段（v1 无真实源）**：心率（无传感器）、导航转向/距离/路名（无导航引擎）、坡度（无现成源）、路点标签。占位值默认沿用 `2.png`（心率 145、坡度 3.2% 等），由未来手机 App 更新，不改渲染器。
- **结论**：v1 = “`2.png` 静态外观高保真 + 上述真实动态数据”，非全字段实时。

## Key decisions & tradeoffs（评审改写的原决策）
- 默认 HUD **硬编码而非走 manifest**（改 Q8）：最快出视觉、避免在 MCU 上造通用 UI 引擎、RAM 可控。
- 声明式渲染器 **v1 仅简单 widget**（收窄 Q6）：复杂控件留在内置表盘硬编码。
- 提交用 **`.ready` 标记而非目录 rename**（改 Q7“atomically activate”）：FAT/SdFat 无原子 rename。
- 安装走 **直连 SdFat + 非阻塞状态机**（补 Q9）：lv_fs 能力不足 + 看门狗实时性约束。
- 全屏背景 **纯 LVGL 绘制、PNG 仅小图标**（补 Q8）：lv_img_png 每帧重解码。

## Risks / open questions
- **BLE 实际空中吞吐未实测**：115200 UART 理论 11.5KB/s，但透传模块空中速率可能 1–5KB/s；几十 KB 包 HEX 后翻倍。需实测以确定 chunk 大小、会话超时、是否需要简单流控。
- **neon glow 保真度上限**：LVGL v8 难高效实现辉光，近似程度需用户验收。
- **模拟器 480→240 横向布局回归**（评审⑦后半）：改尺寸后须跑模拟器逐页目检 LiveMap（`LiveMapView.cpp:102` tile 宽度计数）/StatusBar。
- **CRC 复用**：zlib crc32 符号能否独立链接待实施确认。

## Out of scope (v1)
复杂 widget 声明式化、断点续传、压缩包解压、旧资源 GC、手机端打包器、心率/导航/坡度真实数据、任意脚本/动画引擎/自定义触摸逻辑/动态第三方字体加载。

## MainMenu 决策（评审③，原 Q12 依赖不存在的页面）—— 已定稿
`AppFactory.cpp:40-44` 仅注册 `Template/LiveMap/Dialplate/SystemInfos/Startup`，原无 MainMenu。
用户最终决定（取代上文 Q12 与上一版 A/B 方案）：
- 新建 `Pages/MainMenu` 页面并注册进 `AppFactory`，纳入 v1 范围。
- **MainMenu 取代原 SystemInfos 的入口**：原先直接进入“设备信息（SystemInfos）”的入口，改为进入 MainMenu。
- **SystemInfos 降级为 MainMenu 的一个子功能**：从 MainMenu 内部再进入设备信息页。
- Dialplate 底部 `MENU` 按钮 → 打开 `MainMenu`。
- 实现归入新增「阶段 1.5」（见下），在默认 HUD 之后、表盘系统之前完成。

## 15 条评审修复映射（验证全部吸收）
1. RAM 预算 → 「内存预算表」
2. 伪原子提交 → 阶段5「`.ready` 提交策略」
3. 不存在的 MainMenu → 「MainMenu 决策」
4. BLE 层缺陷 → 阶段3「BLE 收发层重写」
5. 声明式引擎范围 → 「范围分层」+ 阶段1/4
6. 占位数据 → 「数据绑定清单」
7. 模拟器回归 → 「Risks」
8. lv_fs 无 O_CREAT → 阶段5「直连 SdFat」
9. 看门狗/单线程 → 阶段5「非阻塞状态机」
10. 全屏 PNG 每帧解码 → 阶段1「背景/图标」+ 内存预算「禁止」
11. zlib 32KB 窗口 → 「内存预算表」
12. manifest 解析器 → 阶段4「ArduinoJson v6」+ 预算 4KB
13. course 抖动 → 阶段1「箭头方向」
14. 信息密度/字体/辉光 → 阶段1「字体/辉光」
15. 安装会话边界 → 阶段5「会话边界」
