# Plan Review Log: Dialplate HUD Watchface System v1
Act 1 (grill) complete - plan locked with the user. MAX_ROUNDS=5.

## Round 1 - Codex CLI

Attempted to run the required read-only `codex exec` adversarial review.

CLI version check:

```text
codex-cli 0.136.0
```

The first PowerShell `codex` shim was blocked by Windows execution policy, so `codex.cmd` was used instead. A read-only review thread was started:

```text
THREAD_ID=019ec6bd-3a40-7ae2-a912-56ead7a4f19c
```

The review output file could not be written to `D:\tmp`, and subsequent attempts to retrieve the review from the same read-only thread failed with authentication errors:

```text
unexpected status 401 Unauthorized: Missing bearer or basic authentication in header
stream disconnected before completion: error sending request for url (https://api.openai.com/v1/responses)
turn.failed
```

No valid `VERDICT: APPROVED` or `VERDICT: REVISE` was produced.

### Codex response

Formal Act 2 review is blocked by local `codex` CLI authentication/output issues. The plan is not marked approved.

---

## Round 2 — Claude 代行对抗式评审（用户要求不调用 Codex，由 Claude 扮演评审者）

被评审计划：`DIALPLATE_GRILL_NOTES.md`（第一幕已锁定 Q1–Q12）。
工具说明：本会话无 `sequential-thinking`/`desktop-commander` 等 MCP，改用标准 Read/Grep/Glob 完成等价代码核验，结论均附 `file:line` 证据。本节同时作为 CLAUDE.md 要求的验证留痕。

### A. 已核实为“真”的前提
- 硬件 240×320 portrait — `USER/HAL/HAL_Config.h:51-52`。
- `GPS_Info_t.course` 存在且来自真实 GPS — `USER/App/Common/HAL/HAL_Def.h:28`、`USER/HAL/HAL_GPS.cpp:101`。
- DialplateModel 已有发布订阅 + `account->Pull("GPS")` — `DialplateModel.cpp:11,28`。
- 当前 Dialplate 为硬编码 LVGL v8 布局，约 208 行 — `DialplateView.cpp`。
- BLE 确为 `+…\r\n`、256B 包缓冲、当前只 echo/print 不分发 — `Bluetooth.h:19`、`Bluetooth.cpp:46-58`。
- lv_port_fs 只暴露 open/read/write/seek/tell/dir，无 mkdir/remove/rename/truncate — `lv_port_fs_sdfat.cpp:27-37`。
- Flash 充裕：ER_IROM1 已用 ~291KB / 1MB（余 ~733KB）— `X-Track.map:26201`。
- LVGL v8、LV_COLOR_DEPTH=16、LV_USE_CANVAS=1、LV_MEM_SIZE=72KB — `lv_conf.h:29,61,516`。

### B. 缺陷清单（每条附一句话修复）

- **[阻断-1] RAM 预算可能不成立，且计划零预算分解。** RW_IRAM1 已用 0x4c180=304KB / 上限 0x60000=384KB，仅剩 ~80KB（`X-Track.map:29100`）；LVGL 私有堆仅 72KB（`lv_conf.h:61`）；240×320 RGB565 全屏帧=150KB 已超余量两倍。计划在此之上叠加声明式 widget 树/manifest 缓冲/BLE chunk 组装/CRC/canvas，无任何预算表。
  修复：加硬性内存预算表，约束 routePreview 用 lv_line/lv_img 而非大 canvas、安装走单个 ≤512B 行缓冲。

- **[阻断-2] “校验后原子提交”在 FAT/SdFat 上不成立，且缺提交能力。** FAT 目录 rename 非原子、掉电即损；lv_fs 无 remove/rename（`lv_port_fs_sdfat.cpp:27-37`）；HAL 仅用过 exists/mkdir（`HAL_SD_CARD.cpp:36-39`），无递归删目录，`+WF_DELETE` 无法实现。
  修复：改为“写完文件 + 单独 `.ready` 标记，激活只认带 `.ready` 的目录”；新增直接走 `SdFatSdioEX SD` 的小 SD 层补 mkdir/remove/递归删除。

- **[阻断-3] Q12 依赖不存在的页面。** AppFactory 仅注册 Template/LiveMap/Dialplate/SystemInfos/Startup，无 MainMenu（`AppFactory.cpp:40-44`），但 Q12 要 MENU 打开 MainMenu。
  修复：将“新建 MainMenu”显式纳入范围，或 v1 先指向 SystemInfos、MainMenu 列后续。

- **[阻断-4] BLE 层不具备承载分块协议的基础，被低估。** 写包无长度上限、`pRxPacket` 为 uint8_t 会回绕覆写（`Bluetooth.cpp:41-42`）；收满包只空壳 OTA()+原样 echo（`Bluetooth.cpp:53-54`），无命令分发；无 CRC 工具；每帧无条件发 `X-Trace`（`HAL_Bluetooth.cpp:63`）污染上行；`BT_printf` 仅 100B 栈缓冲、WF_LIST 会截断（`HAL_Bluetooth.cpp:44`）。
  修复：把 BLE 收发层重写（带上限的环形接收 + 表驱动分发 + 去掉每帧 X-Trace/echo + CRC 工具 + 响应分片）作为前置任务单独立项，勿假设“在现有 parser 上扩展”。

- **[重要-5] 声明式渲染器 v1 范围与“复刻 2.png”冲突，等于在 MCU 上造通用 UI 引擎。** Q8 要默认 HUD 也走 manifest，Q10 要复刻含 polyline/旋转箭头/多模块的 2.png；二者叠加工作量与 RAM 远超“重绘一页”。
  修复：默认 HUD 用 C++ 硬编码 LVGL（最快出视觉）；manifest 系统 v1 只支持简单 widget（image+label/metric），复杂控件仅在内置默认表盘硬编码，不强求默认表盘走 manifest。

- **[重要-6] “复刻 2.png”动态数据大半是占位，需明确预期。** 无心率传感器、无导航引擎、无现成坡度源；真实数据仅 speed/avgSpeed/trip/time/calorie/altitude/satellites/course。Q11 已承认占位但未量化。
  修复：列“真实绑定 vs 占位”清单，明确 v1 是“静态外观复刻 + 部分真实动态数据”。

- **[次要-7] 模拟器 480→240 横向布局回归未评估。** LiveMap tile 宽度计数可能按宽屏调过（`LiveMapView.cpp:102`）。
  修复：改尺寸后跑模拟器逐页目检并记录回归。

- **[次要-8] lv_fs 写模式不创建文件。** `LV_FS_MODE_WR` 用 O_WRONLY 不带 O_CREAT（`lv_port_fs_sdfat.cpp:106-119`）。
  修复：表盘写入走自建 SD 层显式 O_CREAT|O_TRUNC。

### C. 可观测性缺口
- 无安装失败诊断约定。修复：定义 `+WF_ERR:<stage>,<code>` 回包并经 RTT 打印。
- 无“激活表盘/回退原因”可见性。修复：启动时 RTT 打印 active id 与回退原因。

### VERDICT: REVISE
4 个阻断级（RAM 预算、伪原子提交、依赖不存在的 MainMenu、BLE 层不具备基础）+ 2 个重要级（声明式引擎范围、占位预期）。写代码前需先修订。

---

## Round 3 — Claude 对抗式评审（第二轮深挖，用户要求“再对抗一轮”）

定位：计划尚未修订，故本轮不是复查修订，而是“完整性批判”——攻击第一轮未触及的并发/实时性、解码路径、安装状态机、几何保真等维度，并诚实修正上一轮的误判。

### 新增缺陷（第一轮未触及）

- **[阻断-9] 协作式单线程 + 10s 看门狗 vs 同步安装 = 必然复位。** `HAL.cpp:9,118` 用非抢占的 MillisTaskManager；`BT_Update` 每 200ms（`HAL.cpp:107`）、喂狗 `WDG_ReloadCounter` 每 1000ms（`HAL.cpp:101`）、LVGL 渲染全在同一循环串行。看门狗超时 10s（`HAL_Config.h:209`）。BLE 同步装包 / 整包 CRC / SD 大量写一旦单步 >10s 必触发看门狗复位；几十 KB 包经 115200 串口 + SD 写极易超时。计划无任何实时性/分片让步约定。
  修复：安装做成“每次 BT_Update 只推进一小步”的非阻塞状态机，CRC 增量计算，单次 SD 写控制在百 ms 级，明确禁止任何 >1s 同步阻塞。

- **[阻断/重要-10] 全屏 PNG 背景每帧重解码。** `lv_img_png.cpp:158,188,247,262`：每次 `DRAW_MAIN_BEGIN` 都重新 open + zlib inflate 整张 PNG。小图标可接受，但下载表盘用全屏 PNG 背景 = 每帧从 SD 读 + 解压整图，帧率崩溃并与喂狗争用 CPU。这与“声明式表盘用 SD PNG 资产”直接冲突。
  修复：全屏背景禁用每帧解码的 lv_img_png；改纯 LVGL 绘制背景，或限制 PNG 只用于小图标；若必须全屏图，需重设计为一次性解码缓存（但 150KB 全屏帧放不下，需降采样/分块）。

- **[重要-11] zlib inflate 32KB 滑窗 RAM 未计入预算。** PNGdec 自带 inflate（`inflate.c`/`inftrees.c`）。
  修复：内存预算表为 PNG 解码预留 ~32KB 窗口 + 行缓冲（`lv_img_png.cpp:260`）。

- **[已缓解-12] manifest 解析器其实已存在。** 项目已集成 ArduinoJson v6（`USER/App/Utils/ArduinoJson`），manifest.json 解析不需自研。但 JsonDocument 容量要纳入预算。
  修复：固定 StaticJsonDocument 上限（如 4KB），manifest 超限即判非法。

- **[重要-13] GPS course 抖动会让箭头乱转。** 静止/低速时 GPS course 噪声大（`HAL_GPS.cpp:101` 直接取 deg）。
  修复：低速阈值下冻结箭头朝向 + course 角度低通滤波。

- **[重要-14] 信息密度/字体可读性 + 霓虹辉光保真度。** 2.png 在 240×320 物理小屏要塞约 13 个信息块，字体会很小；LVGL v8 无廉价 box-shadow/glow。
  修复：辉光用预渲染素材或近似；排版做可读性取舍并记录；补所需字体（Flash 余量充裕，可接受）。

- **[重要-15] 安装会话状态机边界未定义。** Q9 排除 resume，但未定义：WF_CHUNK 无 BEGIN、重复 BEGIN、WF_END 缺文件、断连后会话悬挂、启动时清理上次 `.install` 残留。
  修复：定义非法转移处理 + 启动清理 `/Watchfaces/.install/` + 会话 N 秒无 chunk 自动中止。

### 对 Round 2 的诚实修正
- **撤回 [次要-7] 的几何冲突担忧**：实际查看 `generated-images/2.png` 后确认其本身即竖屏布局（宽高比 ≈3:4，与 240×320 基本一致），Q1“保留比例缩放”与 Q10“保留全部模块”不构成几何冲突。真正的风险改判为 [重要-14] 的信息密度/可读性。模拟器尺寸回归（原 7 的后半）仍需验证。

### VERDICT: REVISE
本轮新增 2 个阻断级（看门狗复位、全屏 PNG 每帧解码）与多个重要级；并缓解 1 条（解析器已存在）、修正 1 条（几何冲突撤回）。结论稳定指向：先重构 BLE/安装实时性与 PNG 策略、收窄声明式引擎范围，再实施。继续多轮对抗的边际收益已下降。
