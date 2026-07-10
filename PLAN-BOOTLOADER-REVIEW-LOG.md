# Plan Review Log: AT32F435 双区 Bootloader（OTA）+ 外部 Flash 中文字库
Act 1 (grill) complete — plan locked with the user (eitan). MAX_ROUNDS=5. PLAN_FILE=PLAN-BOOTLOADER.md.

> 平台说明：Codex 在本机的 Windows read-only 沙箱无法启动子进程读文件（`CreateProcessAsUserW failed: 1920`），故 Codex 无法直接 `Read` 仓库文件。适配方案：审查基于 prompt 内联的设计/计划描述；后续轮次用 `resume` 保持同一会话记忆，并在消息中内联修订说明。Thread 1 id = `019ed06f-1456-7972-9d23-eb58ef99089d`。

## Round 1 — Codex (VERDICT: REVISE)
（基于设计描述，沙箱无法读取 PLAN 文件）

1. 首启时外部 B 区为空/无效会让"回滚"变成必然变砖。修复：B 区在通过完整头+CRC+长度+向量 sanity+提交标记前一律视为无效；只要没有任一有效外部槽，绝不擦/写内部 APP。
2. 单一内部 APP 区使升级在内部 flash 擦/写期间具破坏性。修复：bootloader 复位后必须能从有效外部槽**续刷**；在新内部镜像成功启动前，绝不让上一个"外部已知好镜像"失效。
3. APP 写 1MB B 备份时断电会留下半有效回滚目标。修复：两阶段提交——先擦/写负载、校验 CRC，最后再原子提交头/EEPROM 标志。
4. QSPI XIP 与命令模式擦写会和 LVGL 字体读取及任何访问 `0x90000000` 的 ISR/代码/数据冲突。修复：操作前静默 LVGL、关中断或门控 QSPI 使用者、退出 XIP 内存映射再擦写，之后重入 XIP 并失效缓存。
5. 若外部 flash 分区表不显式且不受保护，字库与 OTA 槽会互相损坏。修复：定义固定外部分区（A/B/字库/元数据/出厂资产）并做边界检查。
6. 仅 CRC32+版本不足以判断"可启动性"。修复：校验 magic、镜像大小、对齐、向量表 SP 范围、reset handler 范围、CRC、目标硬件 ID、镜像类型、最低兼容 bootloader 版本。
7. 若 APP 自检失败且 B 区是同样坏的/更旧不兼容镜像，回滚逻辑会死循环。修复：按镜像存启动尝试计数，只回滚到一个"不同的、已验证、元数据兼容"的镜像。
8. 版本检查会阻碍合法回滚（唯一好镜像更旧时）。修复：把 anti-rollback 策略与恢复策略分离；除非有真正签名的 anti-rollback 需求，否则显式允许紧急回滚。
9. AT24C02 元数据默认非原子，页写会跨 8 字节边界撕裂。修复：用两条页对齐元数据记录，带序列号、CRC、补码字段，最后写提交标记。
10. 若每次启动都写启动计数/自检状态，EEPROM 磨损会过度。修复：尽量把启动进度保留在 RAM，EEPROM 写仅限状态转换、限频。
11. 看门狗回滚可能在 LVGL/字体/QSPI 冷启动慢时误触发。修复：测最坏冷启动时间、首启用宽松看门狗窗口、按分阶段初始化里程碑喂狗、时序标定前不启用回滚。
12. 不可假设 AT32 看门狗与 STM32 兼容。修复：从 Artery 文档确认 AT32F435 WDT/LWWDT 时钟、重载上限、窗口行为、复位标志后再设计回滚时序。
13. 把 APP 移到 `0x08010000`，若 VTOR、链接 scatter、向量符号、flash origin、中断表、reset 交接未一起改会破坏启动。修复：把 scatter/链接、startup 向量位置、`SCB->VTOR`、镜像头偏移、bootloader 跳转序列作为一次受测变更统一改。
14. bootloader 跳转若遗留外设/SysTick/NVIC pending IRQ/MPU/cache/QSPI 状态或时钟脏会失败。修复：deinit 或将硬件置于文档化交接态、关中断、清 pending IRQ、从 APP 向量设 MSP、设 VTOR、再跳转。
15. AT32 sLib 锁是高风险不可逆步骤，bring-up 期会毁掉调试/恢复。修复：在 OTA、SWD 恢复、量产擦除策略、bootloader 更新策略、产线 provisioning 都验证前，不启用 sLib。
16. XBF 零拷贝字体在 QSPI 被擦除/重映射/休眠/命令模式时读取会硬错误。修复：让 LVGL 字体回调 fail-safe，flash 操作期间全局暂停所有字体访问。
17. 若外部 flash 更新失败只表现为"发生了回滚"，可观测性不足。修复：持久化精简的复位原因、活动槽、候选槽、拷贝偏移/阶段、CRC 失败码、看门狗原因、上次启动状态。
18. 缺少更简单安全的第一里程碑。修复：先实现"固定内部 bootloader + 一个外部黄金恢复镜像"，证明恢复路径后，再加外部 A/B 双槽与字库 XIP。

### Claude's response（Round 1 → PLAN v2）
16 条全部采纳，无拒绝项（Codex 即便未读文件，基于嵌入式 OTA 常识的批评均中肯）。映射到 PLAN v2：
- #1 → 新增 **INV1**（无有效槽绝不擦内部）+ risk#11（出厂写 A/B 或首启即备份）。
- #2 → **INV2**（新镜像确认前不失效 B）+ **INV3**（`copy_stage` 幂等续刷）。
- #3 → 阶段 4#19 两阶段提交 + `backup_valid` 最后置位。
- #4/#16 → **INV4**（flash 操作期全局暂停 LVGL/字体、回调 fail-safe）+ boot 内 XIP↔命令口切换。
- #5 → 阶段 4#13 固定分区表 + bounds check。
- #6 → 阶段 4#14/#15 固件头加 image_type/target_hw_id/min_boot_version + 向量 SP/PC 范围 sanity + 对齐。
- #7 → 阶段 4#17 按镜像计数 + 只回滚到不同已验证镜像 + **INV5** 安全模式上限。
- #8 → **INV7** anti-rollback 与恢复分离，紧急回滚不受版本下限。
- #9 → 阶段 3#10 双记录(0x00/0x40)+seq+crc16+commit marker 最后写。
- #10 → 阶段 3#12 启动进度尽量 RAM + 仅状态转换限频写。
- #11 → 阶段 0#4 实测冷启动 + 首启宽松窗口 + 里程碑喂狗 + 标定前不启用回滚。
- #12 → 阶段 0#3 从 Artery 文档确认 AT32 WDT 时钟/重载/窗口/复位标志。
- #13 → 阶段 1#6 一次性受测变更（scatter/startup/VTOR/硬编码/IAP.TXT）。
- #14 → 阶段 2#9 跳转交接序列（关中断/deinit/清 pending/set MSP/set VTOR/jump）。
- #15 → **INV6** bring-up 不启用 sLib，M4 样片验证后才用。
- #17 → 阶段 6#21 持久化 reset reason/active/candidate/copy_stage/crc_fail_code/wdt cause + RTT。
- #18 → 新增 **里程碑 M1→M4**（先证恢复闭环再加 A/B 与字库）。

## Round 2 — Codex (VERDICT: REVISE)
（resume 同会话；Codex 认可 v2 方向"all the right direction"，提出 14 条更深的产品级细化）

**Resolved in principle**：无有效外部镜像不擦内部、回滚有界、两阶段备份提交、flash 命令期 XIP 暂停、sLib 延后、APP 移址一次性变更、看门狗标定、AT24C02 双记录、分阶段里程碑——方向正确。

**Still insufficient（14 条）**：
1. 首版现场启动可能无任何外部恢复镜像。修复：出厂/产线必须预装至少一个已验证外部黄金槽；APP 创建 B 只能是开发者 fallback。
2. 仅 `copy_stage` 不足以让内部刷写可续。修复：持久化 源槽/镜像ID、源 CRC/版本、目标偏移或扇区位图、erase/program/verify 阶段；跳转前验证完整内部镜像。
3. A/B 提升语义不清（候选通过后何时 B 成新 LKG、何时可擦旧 B）。修复：显式状态机 `downloaded→candidate→internal_trial→confirmed→lkg_promoted`，旧 B 仅在新 LKG 完全验证并原子提交后才擦。
4. 固定分区表缺容量/擦除块证明。修复：明确 QSPI 型号/容量、sector/block 擦除大小、对齐、最大固件大小，`fw_length` 超槽则编译期硬失败。
5. 外部 `meta@0x500000` 与 EEPROM 元数据职责冲突。修复：选一个权威 boot-state 存储，或明确哪些字段在 EEPROM vs QSPI meta、撕裂/不一致如何裁决。
6. AT24C02 双记录需更细。修复：遵守实际页大小、commit marker 单独最后写、处理序列号回绕、部分写入的 future-seq 记录视为无效。
7. 启动计数仍可能磨损（crash loop 每次复位都增）。修复：按镜像转换限写 + 用 reset-cause + RAM/noinit trial marker 在提交 EEPROM 前判断。
8. 看门狗喂狗点要覆盖 CRC/拷贝长操作，不只冷启动。修复：外部 CRC 扫描、内部 erase/program、内部 verify、QSPI 备份 verify 期间都有界喂狗。
9. VTOR/reset 向量校验需 AT32 内存图精度。修复：SP 对所有实际 AT32F435 SRAM 区校验（非泛 STM32 范围），reset PC 去 Thumb 位后校验。
10. 跳转前"reset QSPI/cache"underspecified。修复：要么 QSPI 留中性 disabled 态由 APP 重新初始化，要么留映射 + 文档化 cache 态，二选一不混用。
11. XIP 暂停必须含 DMA 与异步读者，不只 LVGL 渲染。修复：全局外部 flash lease/lock，阻塞 LVGL、DMA2D/显示、FS/字体回调、日志、任何能碰 `0x90000000` 的 ISR。
12. safe-mode 需真正的恢复传输。修复：明确 safe-mode 如何接收新镜像（BLE DFU/串口/USB/SD/SWD lab）后再启用破坏性 OTA。
13. CRC32/版本非真实性机制。修复：若 OTA 输入可被攻击者控制则加签名，或显式标注为 reliability-only OTA、无安全声明。
14. 内部 flash 区域守卫缺失。修复：集中 flash erase/program API，硬边界禁止写 `0x08010000` 以下（boot）、option bytes、AT32 保护区。

### Claude's response（Round 2 → PLAN v3）
14 条全部采纳（#13 按项目规范取"显式标注 reliability-only OTA、无真实性/安全声明"，不加签名）。映射到 v3：
- #1 → M1/risk 出厂预装有效黄金槽为硬性要求，APP 建 B 仅开发 fallback。
- #2 → INV3 扩展为完整续刷上下文（源槽/ID/CRC/版本/目标扇区位图/阶段）+ 跳转前全镜像 verify。
- #3 → 新增 **A/B 提升状态机** `downloaded→candidate→internal_trial→confirmed→lkg_promoted`，旧 B 仅新 LKG 原子提交后擦。
- #4 → 阶段 0/4 分区表标注容量/擦除块/对齐/最大固件 + `fw_length` 超槽编译期硬失败。
- #5 → 明确 **EEPROM = 权威 boot-state**；外部 meta 区仅静态分区表/出厂资产；裁决规则写明。
- #6 → 阶段 3 AT24C02 页大小/commit-last/seq 回绕/future-seq 无效。
- #7 → noinit RAM trial marker + reset-cause，仅状态转换限频写 EEPROM。
- #8 → 阶段 0/4 看门狗喂狗里程碑覆盖 CRC 扫描/erase/program/verify/备份 verify。
- #9 → 向量校验用实际 AT32F435 SRAM 图、reset PC 去 thumb 位。
- #10 → 阶段 2 跳转交接：QSPI 留中性 disabled 态、APP 重新初始化（二选一明确）。
- #11 → INV4 升级为**全局外部 flash lease/lock**，覆盖 LVGL/DMA2D/FS/字体/日志/ISR。
- #12 → 新增 **INV9**：safe-mode 必须具备恢复传输（SD + BLE DFU + SWD lab）才允许破坏性 OTA。
- #13 → Key Decisions 显式声明 reliability-only OTA、无真实性/安全声明（符合项目规范）。
- #14 → 新增 **INV8**：集中化内部 flash 写 API + 硬边界守卫（禁写 boot/option/保护区）。

## Round 3 — Codex (VERDICT: REVISE)
（resume 同会话；Codex 认可 R2 修复"all sufficient as plan constraints"，挖出根本性 A/B 缺陷 + 9 条加固）

1. **（根本）** 固定"A=下载/B=备份"无法原子提升 LKG：A 为候选时覆盖 B 期间断电会毁唯一好镜像。修复：A/B **角色对称**，任一槽可为 LKG/候选，或加第三暂存槽；**绝不擦当前 LKG 槽来提升新的**。
2. 配套：元数据改记 `lkg_slot/candidate_slot/download_slot`，只下载到**非 LKG 的空闲槽**。
3. 固件大小守卫应按**内部 APP 容量**（`internal_flash_end-0x08010000`）而非外部槽大小；编译期+启动期拒绝超限。
4. 扇区位图续刷仍可能跳过 torn sector（位图在扇区真正持久前提交）。修复：扇区 program+readback verify 后才标记完成；续刷时对已完成扇区 reverify 再跳过。
5. safe-mode "SD golden image" 可能超 64KB boot 预算（SDIO+FatFs+QSPI+flash+EEPROM+CRC+WDT+诊断）。修复：M1 加 boot 大小预算/map gate，或定义更小的 raw-sector SD 恢复格式替代完整 FatFs。
6. 全局 flash lease 必须**排空活跃使用者**，不只阻塞新使用者。修复：切出内存映射前要求 DMA/display/FatFs/LVGL/logging 静默确认 + DMA 完成。
7. QSPI program/erase 后 cache 一致性隐式。修复：命令模式写后、恢复内存映射读前，显式失效 QSPI/XIP/cache/prefetch。
8. QSPI-disabled 交接契约需可测。修复：APP 启动假设 QSPI 全禁用、从复位态初始化、init 完成前不碰外部字体/资产。
9. SP 校验应含对齐与实际栈边界。修复：初始 SP 在链接器声明的栈 RAM 内且 8 字节对齐。
10. EEPROM 容量需编译期布局检查。修复：static_assert 每条 boot-state 记录（加续刷上下文/CRC/seq/commit/padding 后）能放进 AT24C02 保留区。

### Claude's response（Round 3 → PLAN v4）
10 条全部采纳，核心是 A/B 模型重构：
- #1/#2 → **A/B 角色对称重构**：分区改为对称 `slot0/slot1`；元数据加 `lkg_slot/candidate_slot/download_slot` 指针；下载只进非 LKG 槽；提升=移动 `lkg_slot` 指针，**永不擦 LKG**（旧 LKG 槽下次下载时才擦）；INV2 重述为"绝不擦当前 LKG 槽来提升"。提升状态机改为指针语义。
- #3 → 固件大小守卫改 `internal_flash_end-0x08010000`（960KB），编译期+启动期。
- #4 → 扇区 program+readback verify 后才标记完成；续刷 reverify。
- #5 → M1 加 boot size gate；定义 **raw-sector SD 恢复格式**（精简 SDIO 块读，不用 FatFs），避免 boot 超 64KB；记为风险/待实测。
- #6 → INV4 补"排空活跃使用者 + DMA 完成确认"再切出 XIP。
- #7 → INV4 补命令模式写后显式 cache/XIP/prefetch 失效。
- #8 → 阶段 2 交接契约：APP 假设 QSPI 全禁用、从复位初始化、init 前不碰外部资产。
- #9 → 向量校验加 SP 8 字节对齐 + 栈 RAM 边界。
- #10 → 阶段 3 EEPROM 布局 static_assert。

## Round 4 — Codex (VERDICT: APPROVED)
（resume 同会话）Round-3 点已在设计层解决：角色对称槽模型消除"覆盖 B 来提升 B"的悖论；续刷、lease 排空、raw SD 恢复、cache 失效、交接、向量校验、EEPROM 容量 gate 均具体到可实现。**无剩余阻塞。**

附带 3 条实施 gate（已并入 PLAN v4「实施验收 gate」节）：
1. 同时强制内部镜像容量与外部槽 blob 容量（含头/padding）两个上限。
2. EEPROM `lkg_slot` 指针提升走与其他元数据相同的双记录原子提交路径。
3. 对 `download→candidate→internal_trial→confirmed→lkg_promoted` 每个状态转换做掉电测试。

## 收敛结论
Act 1（grill，Claude↔eitan）锁定方向 → Act 2（review，Claude↔Codex）4 轮收敛：REVISE(16) → REVISE(14) → REVISE(10) → **APPROVED**。计划经跨模型对抗审查后判定 sound enough to implement。等用户最终签字后方可写代码。
Thread: `019ed06f-1456-7972-9d23-eb58ef99089d`。
