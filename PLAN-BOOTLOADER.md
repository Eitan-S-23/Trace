# Plan: AT32F435 双区 Bootloader（OTA 防变砖）+ 外部 Flash 中文字库
_经 grill 锁定 — by Claude + eitan；v4 已纳入 Codex Round 1(16)+Round 2(14)+Round 3(10) 审查_

## Goal
在 AT32F435RGT7 的 X-Track 码表工程中引入产品级 OTA 架构与外部 flash 中文字库：

1. **OTA bootloader**：独立 Bootloader 常驻内部 flash `0x08000000`；APP 后移到 `0x08010000`（单一执行区，全速运行）。外部 QSPI flash 设**两个角色对称槽 slot0/slot1**：其一为 `lkg`（已知可启动好镜像），另一为 `download/candidate`（下载新固件）。Bootloader 经 **XIP** 对候选槽做完整可启动性校验（CRC32+头/向量 sanity+版本），通过后经集中守卫 API 刷入内部 APP 区，全镜像复校；APP 启动做**关键外设自检**并在 **AT24C02** 写"确认 OK"、持续喂狗；APP 跑飞则 Bootloader **回滚到 `lkg` 槽**。**提升新版本 = 移动 `lkg_slot` 指针，绝不擦当前 LKG 槽**。本 OTA 为 **reliability-only（无真实性/防篡改安全声明）**，符合项目规范。一切受下方"安全不变量"约束。

2. **外部 flash 中文字库**：GB2312（6763 字）16+24px、4bpp XBF 字库烧入外部 raw 字库区；APP 仿 `font_bahnschrift_26.c` 自定义 `lv_font_t`+getdata 回调，经 **XIP 零拷贝按需读字形**；现有内置 `font_cn_16.c`（17 字）改用 XIP 后移除。

基于 `Doc/ota/` 教学方案按本工程硬件适配。

## 硬件与现状基线（已查证）
- MCU：AT32F435RGT7，内部 flash **1MB**（`0x08000000`–`0x080FFFFF`），SRAM `0x20000000` 起 384KB（**全部 SRAM 区与栈范围按数据手册列明**，供向量 SP 校验）。APP 实测 ROM **313KB**。
- 外部 flash：QSPI1，XIP 基址 **`0x90000000`**，`0x6B` Quad+3 字节地址。容量常量 8MB（型号名暗示 16MB，**阶段 0 读 JEDEC ID 实测**，并记录 sector/block 擦除粒度）。当前空闲，不作 U 盘。
- USB MSC 单 LUN，当前 **SD 卡**。
- 伪升级痕迹：`FileBrowser.cpp` 写 SD `0:/IAP/IAP.TXT`+`restart_to_bootloader()`，将被取代。
- AT32 flash 驱动：`flash_crc_calibrate`（硬件 CRC，仅内部、按扇区）、`flash_slib_enable`（sLib 锁区）、独立 bank 擦写；无透明 bank swap。
- AT24C02：I2C EEPROM 256B，驱动现成；**页大小按器件手册确认**。
- 字体：`font_bahnschrift_26.c` 已是 XBF+回调模板（未启用）。
- BLE：`Libraries/Bluetooth/`、`HAL_Bluetooth.cpp` 框架存在（能力待评估）。

## 安全不变量（Safety Invariants — 最高约束）
- **INV1**：无任一槽含有效镜像时绝不擦/写内部 APP（停 Boot 安全模式）。
- **INV2（永不毁 LKG）**：**绝不擦/覆盖当前 `lkg_slot`**；提升新版本只通过原子移动 `lkg_slot` 指针完成；旧 LKG 槽仅在指针已移走后、作为下次 download 槽时才擦。
- **INV3（可续刷）**：内部刷写持久化完整续刷上下文（源槽/镜像ID、源 CRC/版本、目标扇区位图、erase/program/verify 阶段）；**每扇区 program+readback verify 通过才标记完成**；复位后幂等重刷并对已完成扇区 reverify 再跳过；**跳转前验证完整内部镜像**。
- **INV4（全局 flash lease/lock）**：操作外部 flash（擦/写/命令模式）前取全局租约，**先排空活跃使用者**（等 LVGL/DMA2D/显示/FatFs/字体/日志静默确认 + DMA 完成），再切出内存映射；阻塞期间字体 getdata 回调 fail-safe；**命令模式写后、恢复 XIP 读前显式失效 QSPI/XIP/cache/prefetch**；Boot 内同理 `qspi_xip_enable(FALSE)`→操作→失效→重入。
- **INV5（回滚有界）**：回滚有尝试上限；无可启动镜像时进 Boot 安全模式，不无限重启。
- **INV6**：sLib 仅 M4、样片验证后启用；bring-up 不启用。
- **INV7（恢复优先于防降级）**：版本防回滚仅约束"接受新下载固件"；紧急回滚到 LKG 不受版本下限限制。
- **INV8（内部 flash 写守卫）**：所有内部 erase/program 经集中 API，硬边界禁止写 `0x08010000` 以下、option bytes、AT32 保护区。
- **INV9（safe-mode 有出路）**：启用破坏性 OTA 前 safe-mode 必须具备恢复传输（M1 起 SD 卡 raw 镜像；M4 加 BLE DFU；SWD lab 兜底）。

## A/B 角色对称提升状态机（回应 Codex R3#1/#2）
两个对称槽，元数据指针 `lkg_slot`（已知好）、`download_slot`（=非 LKG 空闲槽）、`candidate_slot`。生命周期：
`downloaded`（新固件写入 download 槽完成）→ `candidate`（该槽通过可启动性校验）→ `internal_trial`（已刷入内部、试运行）→ `confirmed`（APP 自检确认）→ **`lkg_promoted`（原子把 `lkg_slot` 指向该槽）**。
- 下载只进 `download_slot`（非 LKG）；**当前 LKG 槽全程不动**（INV2）。
- 提升后旧 LKG 槽成为新的 `download_slot`，下次下载时才擦。
- 任一阶段失败按 INV1/INV5/INV7（回滚到 `lkg_slot`）处理。

## 里程碑
- **M1 最小可用恢复**：独立 Boot + APP 移址 + 单 LKG 槽 + 头/向量 sanity/CRC32 校验 + 集中内部写 API（INV8）+ **raw-sector SD 恢复**（不依赖 FatFs，控 boot ≤64KB）。**出厂/产线必须预装至少一个已验证 LKG 镜像**（硬性，回应 R2#1）。**加 boot 大小预算/map-file gate**（回应 R3#5）。证明 boot→校验→刷写→全镜像 verify→跳转→恢复闭环。
- **M2 A/B OTA**：双对称槽、角色指针、提升状态机、Flag、版本策略、外设自检+看门狗回滚。
- **M3 字库**：外部字库 XIP + LVGL 回调 + 生成/烧录工具链；移除内置 `font_cn_16.c`。
- **M4 强化**：sLib（INV6）、BLE 通道/DFU、可观测性完善、菜单 UI。

## Approach

### 阶段 0：核实与基线
1. 读外部 flash **JEDEC ID** 确认容量与 sector/block 擦除粒度/对齐；修正常量。
2. 核实内部 flash 扇区/块粒度、`FLASH_BANK1/2_*`、**全部 SRAM 区与链接器栈范围**（供 SP 校验、Boot/sLib 对齐）。
3. 查 Artery 文档确认 **AT32F435 WDT/WWDT** 时钟/重载/窗口/复位标志；确认 AT24C02 **页大小**。
4. 实测 LVGL+App_Init 冷启动 **及外部 CRC 扫描/内部 erase·program/内部 verify/QSPI 备份 verify 的最坏耗时**，据此设看门狗窗口与各长操作喂狗里程碑。

### 阶段 1：内部分区 + APP 改造（M1，一次性受测变更）
5. 布局：Boot 64KB@`0x08000000`；APP 960KB@`0x08010000`。
6. 统一改并一起测：`X-Track.sct`（起始 `0x08010000`、size `0x000F0000`）、startup 向量、`SCB->VTOR=0x08010000`、清理硬编码 `0x08000000`、改造 `restart_to_bootloader()`；保留 RAMCODE/字体入 RAM 段。
7. sLib 延到 M4（INV6）。

### 阶段 2：Bootloader 独立工程（M1）
8. 新建 `MDK-ARM_F435_Boot/`，链接 `0x08000000`，**≤64KB（map-file gate 校验）**。含：最小时钟/GPIO、QSPI（XIP 读+命令口擦写+切换+cache 失效）、内部 flash 擦写（INV8 集中 API）、I2C+AT24C02、CRC、WDT、**raw-sector SD 块读恢复（精简 SDIO，不用 FatFs）**、跳转。无 LVGL/USB/显示。长操作按里程碑喂狗。
9. **跳转交接（回应 R1#14/R2#10/R3#8）**：校验通过→关全局中断→deinit 外设/停 SysTick/清 NVIC pending→**QSPI 置中性 disabled 态**（cache/prefetch 失效）→从 APP 向量读 MSP `__set_MSP`→`SCB->VTOR=0x08010000`→跳转。**契约：APP 启动假设 QSPI 全禁用、从复位态初始化、init 完成前不碰外部字体/资产**。

### 阶段 3：Flag / 元数据层（M2，原子防撕裂）
10. **权威 boot-state = AT24C02**；外部 QSPI `meta` 区仅静态信息（分区表副本、出厂资产、字库版本）；启动以 EEPROM 为准。
11. EEPROM 双记录页对齐（按实测页大小，记录间距远超页）；每记录 `seq+字段+crc16+commit_marker(最后单独写)`；取 commit 有效且 seq 最大者；future-seq 部分写入视为无效；处理 seq 回绕。
12. 字段：`magic/struct_ver、lkg_slot、download_slot、candidate_slot、image_state、boot_command、app_current_version、pending_valid、boot_try_count、app_confirmed、last_reset_reason、copy_ctx(源槽/ID/CRC/目标位图/阶段)、crc_fail_code、watchdog_cause`。**编译期 static_assert 记录（含全部字段+CRC+seq+commit+padding）放得进 AT24C02 保留区**（回应 R3#10）。
13. 写策略：试运行进度优先 **noinit RAM trial marker + reset-cause**；EEPROM 仅状态转换限频写。

### 阶段 4：OTA 状态机（M1 校验/M2 完整）
14. **外部分区（实测容量，固定+bounds check）**：slot0 1MB@`0x000000`、slot1 1MB@`0x100000`（**对称、角色由指针定**）、字库 3MB@`0x200000`、meta/出厂区@`0x500000`、其余预留。**最大固件 = `internal_flash_end-0x08010000`(960KB)**，构建期+启动期超限硬失败（回应 R3#3）。XIP=`0x90000000+offset`，全访问 bounds check。
15. **固件头**：`magic+struct_ver+image_type+target_hw_id+fw_version+min_boot_version+fw_length+load_addr(=0x08010000)+body_crc32+header_crc32+reserved`。
16. **可启动性校验**：magic/struct_ver/image_type/target_hw_id 匹配、min_boot_version≤当前 boot、fw_length≤960KB 且对齐、load_addr 正确、**向量[0] SP 落在实际 SRAM 栈区且 8 字节对齐**（回应 R3#9）、**向量[1] reset PC 去 Thumb 位后落在 `[0x08010000,0x08100000)`**、body/header CRC32 通过。
17. **APP 下载**：从 SD/BLE 取固件 → 经 INV4 租约擦写**到 `download_slot`（非 LKG）**（含头）→ 回读校验 → `image_state=candidate`、`pending_valid`、`boot_command=1` → 复位。
18. **Bootloader 主判定**：
    - `boot_command==1 && pending_valid`：校验候选槽（16）。失败→记 `crc_fail_code`、清标志、保持现有 APP（INV1）。通过→写 `copy_ctx`、`image_state=internal_trial`→经 INV8 擦内部→从候选槽刷入（每扇区 readback verify）→**全镜像 verify**；中途复位依 `copy_ctx` 幂等重刷+reverify（INV3）。verify 失败→回滚到 `lkg_slot`（若存在），否则 Boot 安全模式。verify 成功→`boot_command=0、boot_try_count=1、app_confirmed=0、app_current_version=新版本、清 pending`→跳转。
    - `boot_command==0`：`boot_try_count≥阈值 && !app_confirmed`→判失败→**回滚刷 `lkg_slot`**（INV7 不受版本限制；按镜像计数避免回滚到同一坏镜像）；无有效 LKG→Boot 安全模式（INV5）。否则未确认时 `boot_try_count++`→跳转。
19. **APP 运行时确认**：分阶段初始化屏/SD/QSPI/关键传感器，全部成功且进主循环→EEPROM 置 `app_confirmed=1、boot_try_count=0`，按里程碑喂狗（含长操作）。失败/超时→WDT 复位→回 Boot 回滚。首启窗口宽松。
20. **LKG 提升（执行者=APP，原子指针，回应 R3#1/#2）**：`app_confirmed && lkg_slot!=当前内部镜像所在槽` 时，APP 经 INV4 租约确保内部镜像已在某槽完整有效后，**原子把 `lkg_slot` 指向该槽**（`image_state=lkg_promoted`）。**绝不擦旧 LKG 槽来完成提升**（INV2）；旧 LKG 槽下次下载时才作为 `download_slot` 擦除。

### 阶段 5：下载/恢复通道（M1 SD raw 恢复 / M2 SD 升级 / M4 BLE）
21. SD 升级：APP 经 FatFs 读 SD 固件写 download 槽（取代 IAP.TXT）。**safe-mode 恢复（INV9）**：M1 起 Boot 用 **raw-sector SD 块读**（约定固件放 SD 固定 raw 扇区或简单格式，不在 boot 引入 FatFs，控 64KB）从 SD 恢复 LKG；M4 加 BLE DFU；SWD lab 兜底。字库写入复用 APP 侧管道（写字库区）。

### 阶段 6：可观测性（贯穿）
22. 持久化 `last_reset_reason、lkg/download/candidate slot、image_state、copy_ctx 阶段、crc_fail_code、watchdog_cause` 到 EEPROM 并经 SEGGER_RTT 输出。

### 阶段 7：升级触发 UI（M4）
23. 菜单"固件升级"入口；检测到更高版本时提示，用户确认后执行。

### 阶段 8：中文字库（M3，XBF+XIP+INV4 门控）
24. 仿 `font_bahnschrift_26.c` 新增 `font_cn_16`/`font_cn_24`；getdata 改 `return (uint8_t*)(0x90000000+字库基址+offset)`；回调对 flash 忙/命令模式 fail-safe（INV4）。
25. `ResourcePool.cpp` 注册 `IMPORT_FONT(cn_16)/(cn_24)`；核对 LVGL 版本 `lv_font_t` 兼容。
26. 移除内置 `font_cn_16.c`（17 字）及引用。

### 阶段 9：字库生成与烧录工具链（M3）
27. Python 脚本（扩展 `gen_font_text.py`）：simhei.ttf+GB2312+16/24px+4bpp → lv_font_conv/阿里工具 XBF → 转 raw 布局 → 拼接字库 bin。
28. 首次经 SD/BLE 写字库区；字库版本记于 QSPI meta 区头或 EEPROM。

### 阶段 10：验证（贯穿里程碑）
29. 编译：Boot 与 APP 分别通过；`.map` 确认 APP 起始 `0x08010000`、VTOR 生效、**Boot ≤64KB**、`fw_length>960KB` 硬失败、EEPROM 布局 static_assert 通过。
30. 闭环硬件验证（`embedded-debug-loop-setup`/RTT）：正常升级、候选槽 CRC 损坏、刷写中断后续刷+reverify+全镜像 verify、向量非法/ SP 未对齐、APP 自检失败回滚 LKG、无 LKG 首启停安全模式、版本防回滚 vs 紧急回滚、回滚死循环上限、**提升期间不擦 LKG**、OTA 期间 lease 排空 DMA/字体门控、cache 失效正确、内部写越界被 INV8 拒、safe-mode 从 SD raw 恢复。
31. 字库：随机 GB2312 字形 XIP 渲染正确、无越界、RAM 达标、flash 操作期字体 fail-safe。

## Key Decisions & Tradeoffs
- **A/B 角色对称 + LKG 指针、永不擦 LKG**（回应 R3#1/#2）：两对称槽 + `lkg/download/candidate` 指针，提升只移指针，杜绝"覆盖 LKG 期间断电变砖"。内部单 APP 区全速运行。代价：升级/回滚多一次拷贝（秒级）。
- **reliability-only OTA、无安全声明**（回应 R2#13）：按规范不做 AES/签名，显式声明仅防可靠性故障。
- **校验 = CRC32+向量/头 sanity（SP 对齐+栈边界+reset PC）+版本**；固件大小按**内部容量**限（回应 R3#3）。
- **版本与恢复分离（INV7）**。
- **第三层 = 外设自检+看门狗+EEPROM 确认**。
- **EEPROM 权威 boot-state、双记录原子提交、static_assert 布局、noinit 降写**。
- **全局 flash lease（排空+cache 失效，INV4）+ 内部写守卫（INV8）+ safe-mode 出路（INV9）**。
- **Boot 独立工程、≤64KB（gate）、raw-sector SD 恢复（不引入 FatFs，回应 R3#5）、干净 QSPI 中性交接（回应 R3#8）**。
- **外部全 raw 不做 U 盘**。
- **字库 XBF+XIP getdata + 操作期门控**。
- **先 M1 恢复闭环、出厂预装 LKG**（回应 R2#1）。

## Risks / Open Questions
1. 外部 flash 容量/擦除块未实测——阶段 0 读 JEDEC ID。
2. 看门狗窗口需 > 冷启动及各长操作耗时（阶段 0 实测）；AT32 WDT 行为待查证。
3. **Boot 64KB 预算**：含 QSPI/flash/I2C/CRC/WDT/精简 SDIO raw 恢复；若超出需 raw 恢复极简化或调 Boot/APP 边界（回应 R3#5）。
4. EEPROM 写寿命/原子性/页大小/容量：双记录+CRC+commit+noinit 降写+static_assert+实测页大小。
5. sLib 不可逆性：M4 启用，先样片验证。
6. APP 改址连锁——阶段 1 一次性受测变更。
7. 全局 flash lease 排空 DMA/阻塞 LVGL 期间的实时性影响需评估（避免长阻塞渲染、避免 OTA 写期间掉帧不可接受）。
8. LVGL 版本与 XBF 回调签名兼容——以 `font_bahnschrift_26.c` 现签名为准。
9. BLE 吞吐/可靠性/续传——本期 SD 为主、BLE 为辅（M4）。
10. **首版 LKG 源**：出厂/产线必须预装有效 LKG（硬性）；否则首版无退路（INV1 停 boot）。
11. raw-sector SD 恢复格式需与 APP 写 SD 的格式约定一致（非 FatFs 文件，约定固定扇区布局）。
12. 3 字节地址 XIP 仅覆盖 16MB（够）。

## 实施验收 gate（Codex Round 4 APPROVED 附带，须作硬性 gate 而非可选项）
- **双容量上限**：同时强制 **内部镜像容量 ≤ 960KB**（`internal_flash_end-0x08010000`）与 **外部槽 blob 容量（含头+padding）≤ 槽 1MB**；两者编译期+启动期均校验。
- **指针提升走同一原子路径**：EEPROM `lkg_slot` 指针提升必须复用与其他元数据相同的**双记录+seq+CRC+commit_marker 原子提交路径**，不得走捷径。
- **逐状态掉电测试**：对 `download → candidate → internal_trial → confirmed → lkg_promoted` 的**每个状态转换**都设计断电/复位注入测试，纳入阶段 10 闭环验证用例。

## Out of Scope
- AES/固件加密/签名、外部加密芯片（reliability-only OTA）。
- 内部真 A/B 双槽 / option byte 切换 bank。
- 手机/上位机 App 实现（仅约定 BLE 下载侧）。
- 外部 flash 继续作 USB U 盘。
- 压缩固件、BLE 断点续传（本期）。
- 全 CJK 字库、动态第三方字体上传。
- 多于 16+24px 中文字号（预留区后续追加）。
