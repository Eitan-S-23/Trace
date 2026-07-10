# AT32F435 USB MSC + QSPI Flash 卡死问题调试指南

## 目录
- [问题概述](#问题概述)
- [调试工具与方法](#调试工具与方法)
- [调试过程](#调试过程)
  - [问题1: USB初始化时卡死](#问题1-usb初始化时卡死)
  - [问题2: USB MSC格式化时卡死](#问题2-usb-msc格式化时卡死)
  - [问题3: USB热拔插后需要重新格式化](#问题3-usb热拔插后需要重新格式化)
- [经验总结](#经验总结)

---

## 问题概述

**硬件平台**: AT32F435RGT7 (ARM Cortex-M4)
**功能需求**: 实现USB MSC (Mass Storage Class)，使用外部W25Q128 QSPI Flash (16MB) 作为存储介质
**主要问题**:
1. USB初始化时程序卡死
2. USB MSC格式化时程序卡死
3. USB热拔插后文件系统数据丢失，需要重新格式化

**硬件约束**: PA9引脚未连接USB VBUS（无硬件VBUS检测能力）

---

## 调试工具与方法

### 1. ARM Cortex-M4 关键寄存器

#### xPSR (Program Status Register)
- **地址**: CPU核心寄存器
- **关键字段**: IPSR (Exception Number) - 位 [8:0]
- **用途**: 识别当前正在执行的异常/中断

```
xPSR 格式:
[31:27] N, Z, C, V, Q flags
[26:10] Reserved
[9]     ICI/IT
[8:0]   IPSR - Exception Number (异常编号)
```

**异常编号到IRQ的转换**:
```c
IRQ_Number = Exception_Number - 16
```

#### LR (Link Register)
- **用途**: 识别异常返回类型
- **关键值**:
  - `0xFFFFFFF9`: 返回到Handler模式，使用MSP
  - `0xFFFFFFFD`: 返回到Thread模式，使用MSP
  - `0xFFFFFFF1`: 返回到Thread模式，使用PSP

#### NVIC ISPR (Interrupt Set-Pending Register)
- **地址**: `0xE000E200` (ISPR0), `0xE000E204` (ISPR1), ...
- **用途**: 查看哪个中断正在挂起（pending）
- **读取方法**: 在调试器中查看内存 `0xE000E200`

```
每个位对应一个IRQ:
Bit 0 = IRQ 0
Bit 1 = IRQ 1
...
Bit 31 = IRQ 31
```

### 2. 调试步骤流程图

```
程序卡死
    ↓
查看PC指针 → 是否在 startup.s:428 (B .)
    ↓ 是
进入默认中断处理函数 (Weak Handler)
    ↓
读取 xPSR 寄存器
    ↓
提取 IPSR 字段 (位[8:0])
    ↓
计算 IRQ = IPSR - 16
    ↓
查找 startup.s 向量表 → 定位中断源
    ↓
检查该中断处理函数是否正确链接
```

---

## 调试过程

### 问题1: USB初始化时卡死

#### 现象
```
程序执行到 Usb_Init() 后卡死
调试器显示PC = startup_at32f435_437.s:428
```

**startup.s:428** 代码:
```assembly
Default_Handler PROC
                EXPORT  EDMA_Stream1_IRQHandler        [WEAK]
                EXPORT  OTGFS1_IRQHandler              [WEAK]
                ; ... 其他弱符号

EDMA_Stream1_IRQHandler
OTGFS1_IRQHandler
                ; ... 其他处理函数
                B       .                ; 无限循环 ← 卡死在这里
                ENDP
```

#### 调试步骤1: 检查NVIC挂起寄存器

**操作**: 在调试器中查看内存地址 `0xE000E200`

**第一次读取结果**:
```
0xE000E200: 00 00 00 00 20 00 00 00
```

**分析**:
- ISPR1 (0xE000E204) = 0x20 = `0b00100000`
- Bit 5 = 1 → IRQ 37 挂起
- 查找向量表: IRQ 37 = USART1_IRQHandler

**问题定位**:
- PA9 在代码中被配置为 `OTG_PIN_VBUS` (USB VBUS检测)
- 但硬件上PA9未连接VBUS，而是用于USART1_TX
- 导致USART1意外触发中断

**解决方案**:
```c
// usb_conf.h
#define USB_VBUS_IGNORE  // PA9 not connected to VBUS, must ignore VBUS detection
```

#### 调试步骤2: 再次卡死，ISPR全0

**第二次读取结果**:
```
0xE000E200: 00 00 00 00 00 00 00 00
```

**问题**: ISPR全0，说明中断已进入处理，但处理函数未正确执行

#### 调试步骤3: 读取xPSR和LR寄存器

**读取结果**:
```
xPSR = 0x81000053
LR   = 0xFFFFFFF9
```

**xPSR分析**:
```
0x81000053 = 0b1000 0001 0000 0000 0000 0101 0011
             │└─┬─┘│                    └──┬──┘
             │  │  │                       │
             N  Z  C,V flags              IPSR = 0x53
```

**计算Exception Number**:
```
IPSR = 0x53 = 83 (十进制)
IRQ_Number = 83 - 16 = 67
```

**查找startup.s向量表**:
```assembly
; Line 125 in startup.s
DCD     OTGFS1_IRQHandler         ; IRQ 67 (Exception 83)
```

**LR分析**:
```
LR = 0xFFFFFFF9
→ 异常返回到Handler模式，使用MSP
→ 说明是在主程序（非中断嵌套）中触发的USB中断
```

**问题定位**: OTGFS1_IRQHandler 被调用，但跳转到了默认的弱处理函数

#### 调试步骤4: 检查符号链接

**查看链接器符号表**:
```
HAL_USB.cpp 中定义:
void OTG_IRQ_HANDLER(void) { ... }

编译后符号:
_Z15OTG_IRQ_HANDLERv    // C++ name mangling!
```

**startup.s 需要的符号**:
```
OTGFS1_IRQHandler      // C linkage
```

**根本原因**: **C++名称修饰 (Name Mangling)**
- HAL_USB.cpp 是C++文件
- 未使用 `extern "C"`，编译器应用了名称修饰
- 链接器找不到 `OTGFS1_IRQHandler` 符号
- 使用弱符号的默认处理函数（死循环）

#### 解决方案1: 修复USB中断处理函数链接

**HAL_USB.cpp**:
```cpp
// 添加 extern "C" 声明
extern "C" void OTG_IRQ_HANDLER(void)
{
  usbd_irq_handler(&otg_core_struct);
}

extern "C" void usb_gpio_config(void) { ... }
extern "C" void usb_clock48m_select(usb_clk48_s clk_s) { ... }
```

**UsbMsc.h**:
```c
#ifdef __cplusplus
extern "C" {
#endif

void OTG_IRQ_HANDLER(void);
void usb_gpio_config(void);
void usb_clock48m_select(usb_clk48_s clk_s);
// ... 其他函数声明

#ifdef __cplusplus
}
#endif
```

**测试结果**: ✅ USB初始化不再卡死，电脑能识别U盘

---

### 问题2: USB MSC格式化时卡死

#### 现象
```
USB初始化正常，电脑识别为U盘
格式化U盘时，程序卡死
调试发现卡在: while(qspi_dma_transfer_done == 0);
```

#### 调试步骤1: 检查QSPI DMA中断处理函数

**问题发现**: qspi_cmd_en25qh128a.cpp 是C++文件

```cpp
// 缺少 extern "C"
void EDMA_Stream1_IRQHandler(void)
{
  // ... 中断处理代码
}
```

**解决方案**: 添加 `extern "C"`
```cpp
extern "C" void EDMA_Stream1_IRQHandler(void)
{
  // ... 中断处理代码
}
```

**测试结果**: ❌ 仍然卡死

#### 调试步骤2: 断点调试中断处理函数

**用户反馈**:
> "断点调试发现EDMA_Stream1_IRQHandler函数是触发了的，且程序在qspi_data_write函数的while(qspi_dma_transfer_done == 0)循环与EDMA_Stream1_IRQHandler函数中反复循环执行"

**分析**:
- 中断确实触发
- 但主循环仍然无法退出
- 说明 `qspi_dma_transfer_done` 未被正确设置

#### 调试步骤3: 分析中断处理函数逻辑

**原始代码**:
```cpp
void EDMA_Stream1_IRQHandler(void)
{
  /* half transfer complete */
  if(edma_flag_get(EDMA_HDT1_FLAG) != RESET)
  {
    edma_flag_clear(EDMA_HDT1_FLAG);
    qspi_current_buffer = 1 - qspi_current_buffer;
    // ⚠️ 没有设置 qspi_dma_transfer_done = 1
  }

  /* full transfer complete */
  if(edma_flag_get(EDMA_FDT1_FLAG) != RESET)
  {
    edma_flag_clear(EDMA_FDT1_FLAG);
    qspi_dma_transfer_done = 1;  // ✅ 只有这里设置标志
  }
}
```

**问题分析**:
- **半传输中断** (EDMA_HDT_INT) 在传输50%时触发
- 半传输中断处理只清除标志，不设置完成标志
- 如果半传输中断一直触发，完整传输中断可能无法处理

**解决方案2: 禁用半传输中断**
```cpp
void qspi_edma_init(void)
{
  // ...

  /* enable edma transfer complete and error interrupts (disable half transfer) */
  edma_interrupt_enable(QSPI_EDMA_STREAM, EDMA_FDT_INT, TRUE);
  edma_interrupt_enable(QSPI_EDMA_STREAM, EDMA_HDT_INT, FALSE);  // 禁用半传输中断
  edma_interrupt_enable(QSPI_EDMA_STREAM, EDMA_DTERR_INT, TRUE);
}
```

**测试结果**: ❌ 仍然卡死

#### 调试步骤4: 检查DMA配置顺序

**发现问题**: DMA参数在流禁用之前配置

**错误代码**:
```cpp
/* 错误顺序 */
edma_data_number_set(QSPI_EDMA_STREAM, chunk);           // 1. 先配置参数
edma_memory_addr_set(QSPI_EDMA_STREAM, addr, EDMA_MEMORY_0);
edma_stream_enable(QSPI_EDMA_STREAM, FALSE);             // 2. 后禁用流
```

**问题**:
- DMA控制器在启用状态下被重新配置 → 未定义行为
- 参数可能无法正确写入硬件寄存器

**解决方案3: 修正DMA配置顺序**
```cpp
/* 正确顺序 */
/* STEP 1: Disable EDMA stream before reconfiguration */
edma_stream_enable(QSPI_EDMA_STREAM, FALSE);

/* STEP 2: Wait for stream to be fully disabled (check EN bit) */
while(QSPI_EDMA_STREAM->ctrl & 0x01);

/* STEP 3: Configure DMA parameters while stream is disabled */
edma_data_number_set(QSPI_EDMA_STREAM, chunk);
edma_memory_addr_set(QSPI_EDMA_STREAM, (uint32_t)current_buffer, EDMA_MEMORY_0);

/* STEP 4: Clear all EDMA flags before starting transfer */
edma_flag_clear(EDMA_FDT1_FLAG);
edma_flag_clear(EDMA_HDT1_FLAG);
edma_flag_clear(EDMA_DTERR1_FLAG);

/* STEP 5: Set QSPI DMA threshold */
qspi_dma_tx_threshold_set(QSPI1, QSPI_DMA_FIFO_THOD_WORD08);

/* STEP 6: Clear transfer done flag */
qspi_dma_transfer_done = 0;

/* STEP 7: Enable QSPI DMA */
qspi_dma_enable(QSPI1, TRUE);

/* STEP 8: Enable EDMA stream to start transfer */
edma_stream_enable(QSPI_EDMA_STREAM, TRUE);
```

**测试结果**: ❌ 仍然卡死

#### 调试步骤5: 添加调试计数器

**添加调试变量**:
```cpp
/* Debug: track interrupt trigger count */
static volatile uint32_t edma_irq_count = 0;   // 总中断次数
static volatile uint32_t edma_fdt_count = 0;   // 完整传输次数
static volatile uint32_t edma_hdt_count = 0;   // 半传输次数
static volatile uint32_t edma_err_count = 0;   // 错误次数

extern "C" void EDMA_Stream1_IRQHandler(void)
{
  edma_irq_count++;

  if(edma_flag_get(EDMA_HDT1_FLAG) != RESET) {
    edma_hdt_count++;
    // ...
  }

  if(edma_flag_get(EDMA_FDT1_FLAG) != RESET) {
    edma_fdt_count++;
    // ...
  }

  if(edma_flag_get(EDMA_DTERR1_FLAG) != RESET) {
    edma_err_count++;
    // ...
  }
}
```

**调试结果（用户反馈）**:
```
edma_irq_count = 0x100 (256次)
edma_fdt_count = 0x100 (256次)

QSPI独立测试日志:
Sector 0-15: 全部PASS
Success rate: 100%
```

**关键发现**:
- ✅ QSPI DMA功能完全正常（独立测试100%通过）
- ✅ 已成功完成256次DMA传输
- ❌ 但在USB MSC格式化时仍然卡死
- **结论**: 问题不在QSPI，而在USB调用场景

#### 调试步骤6: 分析中断优先级

**当前优先级配置**:
```cpp
// HAL_USB.cpp
nvic_irq_enable(OTG_IRQ, 1, 0);           // USB优先级 = 1 (高)

// qspi_cmd_en25qh128a.cpp
nvic_irq_enable(EDMA_Stream1_IRQn, 2, 0); // EDMA优先级 = 2 (低)
```

**死锁场景分析**:

```
时间线:
T1: USB中断触发 (优先级1)
    ↓
T2: USB中断处理函数执行
    ↓
T3: 在USB中断上下文中调用 qspi_data_write()
    ↓
T4: qspi_data_write() 启动DMA传输
    ↓
T5: 进入等待循环: while(qspi_dma_transfer_done == 0);
    ↓
T6: DMA硬件完成传输
    ↓
T7: EDMA中断请求产生 (优先级2)
    ↓
T8: ❌ EDMA中断无法抢占正在执行的USB中断 (优先级更低)
    ↓
T9: USB中断继续在while循环中等待
    ↓
T10: EDMA中断继续挂起，无法执行
    ↓
    **死锁**: USB等待EDMA设置标志，EDMA等待USB退出
```

**ARM Cortex-M4 中断优先级规则**:
```
数字越小，优先级越高
高优先级中断可以抢占低优先级中断
低优先级中断无法抢占高优先级中断
```

**为什么独立测试成功？**
- 独立测试在**主循环（Thread模式）**中执行
- 没有中断嵌套，EDMA中断可以正常触发
- USB MSC在**USB中断上下文（Handler模式）**中调用
- 触发中断优先级死锁

#### 解决方案4: 调整中断优先级 ✅

**修改**:
```cpp
// qspi_cmd_en25qh128a.cpp
/* enable edma stream1 nvic interrupt - priority 0 (HIGHEST) */
nvic_irq_enable(EDMA_Stream1_IRQn, 0, 0);  // 优先级改为0
```

**修复后优先级**:
```
优先级 0: EDMA_Stream1  (QSPI DMA) ← 最高，可抢占其他中断
优先级 1: OTGFS1       (USB)
优先级 2+: 其他外设中断
```

**修复后执行流程**:
```
T1-T5: 同上，USB中断中调用qspi_data_write()，进入等待
       ↓
T6:    DMA硬件完成传输
       ↓
T7:    EDMA中断请求产生 (优先级0)
       ↓
T8:    ✅ EDMA中断抢占USB中断（优先级更高）
       ↓
T9:    执行 EDMA_Stream1_IRQHandler
       ↓
T10:   设置 qspi_dma_transfer_done = 1
       ↓
T11:   EDMA中断返回，恢复USB中断执行
       ↓
T12:   while(qspi_dma_transfer_done == 0) 退出
       ↓
T13:   USB处理继续
```

**测试结果**: ✅ **问题完全解决！USB MSC格式化正常工作**

---

### 问题3: USB热拔插后需要重新格式化

#### 现象
```
✅ U盘可以正常格式化并读写文件
❌ 每次重新插拔USB后，U盘都需要重新格式化
❌ 之前写入的文件系统数据丢失
```

**预期行为**: 格式化一次后，后续热拔插应保持文件系统数据

#### 调试步骤1: 检查Flash是否为非易失性存储

**验证**:
- W25Q128是SPI NOR Flash → **非易失性存储**
- 断电后数据应该保持
- 问题不应该在硬件层面

**结论**: 问题在软件实现

#### 调试步骤2: 分析Flash写入逻辑

**检查msc_diskio.cpp中的写入函数**:

**原始代码问题** (msc_diskio.cpp:127-157):
```cpp
usb_sts_type msc_disk_write(uint8_t lun, uint64_t addr, uint8_t *buf, uint32_t len)
{
  // 退出XIP模式
  qspi_xip_enable(QSPI1, FALSE);

  // 计算受影响的扇区
  sector_start = (uint32_t)addr / QSPI_FLASH_SECTOR_SIZE;
  sector_end = ((uint32_t)addr + len - 1) / QSPI_FLASH_SECTOR_SIZE;

  // 擦除所有受影响的扇区
  for(i = sector_start; i <= sector_end; i++) {
    qspi_erase(i * QSPI_FLASH_SECTOR_SIZE);  // 擦除4KB扇区
  }

  // 只写入新数据
  qspi_data_write((uint32_t)addr, len, buf);  // 可能只有512字节

  // 重新进入XIP模式
  en25qh128a_qspi_xip_init();
}
```

#### 调试步骤3: 识别问题根源

**关键参数**:
```
Flash扇区大小: 4KB (4096字节)
USB块大小:     512字节
```

**问题分析**:

USB文件系统通常以512字节块为单位更新数据，但Flash擦除最小单位是4KB扇区。

**错误流程示例**:
```
时间T1: 写入地址0x000，长度512字节（FAT表第一部分）
  → 擦除扇区0 (0x000-0xFFF，4KB)
  → 写入0x000-0x1FF (512字节)
  → ✅ 0x000-0x1FF = FAT数据
  → ⚠️  0x200-0xFFF = 0xFF (擦除后的默认值)

时间T2: 写入地址0x200，长度512字节（FAT表第二部分）
  → 再次擦除扇区0 (0x000-0xFFF，4KB)  ❌
  → 写入0x200-0x3FF (512字节)
  → ❌ 0x000-0x1FF = 0xFF (T1写入的数据被擦除！)
  → ✅ 0x200-0x3FF = 新数据
  → ⚠️  0x400-0xFFF = 0xFF

时间T3: 写入地址0x400，长度512字节（目录项）
  → 再次擦除扇区0 (0x000-0xFFF，4KB)  ❌
  → 写入0x400-0x5FF (512字节)
  → ❌ 0x000-0x3FF = 0xFF (T1和T2的数据全部丢失！)
  → ✅ 0x400-0x5FF = 新数据
  → ⚠️  0x600-0xFFF = 0xFF
```

**根本原因**:
- 每次写入都擦除整个扇区，但只写入部分数据
- 同一扇区中先前写入的文件系统元数据被破坏
- 导致FAT表、目录项等关键数据丢失
- 文件系统损坏，需要重新格式化

#### 解决方案: 实现读-改-写 (Read-Modify-Write) ✅

**正确的Flash写入流程**:
```
对于每个受影响的扇区:
  1. 读取整个扇区（4KB）到缓冲区
  2. 修改缓冲区中需要更新的部分
  3. 擦除扇区
  4. 写回整个扇区（4KB）
```

**修复后的代码** (msc_diskio.cpp:127-178):
```cpp
usb_sts_type msc_disk_write(uint8_t lun, uint64_t addr, uint8_t *buf, uint32_t len)
{
  static uint8_t sector_buffer[QSPI_FLASH_SECTOR_SIZE];  // 4KB缓冲区
  uint32_t sector_addr;
  uint32_t offset_in_sector;
  uint32_t bytes_to_write;
  uint32_t total_written = 0;

  if(lun == 0)
  {
    qspi_xip_enable(QSPI1, FALSE);

    /* 按扇区处理，使用读-改-写策略 */
    while(total_written < len)
    {
      /* 计算当前扇区地址和偏移 */
      sector_addr = ((uint32_t)addr + total_written) & ~(QSPI_FLASH_SECTOR_SIZE - 1);
      offset_in_sector = ((uint32_t)addr + total_written) % QSPI_FLASH_SECTOR_SIZE;
      bytes_to_write = QSPI_FLASH_SECTOR_SIZE - offset_in_sector;

      if(bytes_to_write > (len - total_written))
        bytes_to_write = len - total_written;

      /* Step 1: 通过XIP读取整个扇区 */
      en25qh128a_qspi_xip_init();
      memcpy(sector_buffer, (uint8_t *)(QSPI1_MEM_BASE + sector_addr), QSPI_FLASH_SECTOR_SIZE);
      qspi_xip_enable(QSPI1, FALSE);

      /* Step 2: 在缓冲区中修改需要更新的部分 */
      memcpy(sector_buffer + offset_in_sector, buf + total_written, bytes_to_write);

      /* Step 3: 擦除扇区 */
      qspi_erase(sector_addr);

      /* Step 4: 写回整个修改后的扇区 */
      qspi_data_write(sector_addr, QSPI_FLASH_SECTOR_SIZE, sector_buffer);

      total_written += bytes_to_write;
    }

    en25qh128a_qspi_xip_init();
    return USB_OK;
  }

  return USB_FAIL;
}
```

**修复后的写入流程**:
```
时间T1: 写入地址0x000，长度512字节
  → 读取扇区0 (0x000-0xFFF) 到缓冲区
  → 修改缓冲区[0x000-0x1FF]
  → 擦除扇区0
  → 写回完整扇区 (4KB)
  → ✅ 整个扇区数据完整

时间T2: 写入地址0x200，长度512字节
  → 读取扇区0 (包含T1写入的数据) 到缓冲区  ✅
  → 修改缓冲区[0x200-0x3FF]
  → 擦除扇区0
  → 写回完整扇区 (4KB)
  → ✅ T1的数据保留，T2的数据写入

时间T3: 写入地址0x400，长度512字节
  → 读取扇区0 (包含T1和T2的数据) 到缓冲区  ✅
  → 修改缓冲区[0x400-0x5FF]
  → 擦除扇区0
  → 写回完整扇区 (4KB)
  → ✅ T1、T2、T3的数据全部保留
```

**关键改进**:
1. ✅ 每次写入前先读取整个扇区
2. ✅ 在RAM缓冲区中修改数据
3. ✅ 写回完整的4KB扇区
4. ✅ 保护同一扇区中的其他数据不被破坏
5. ✅ 文件系统元数据正确持久化

**测试结果**: ✅ **热拔插后数据保持，无需重新格式化**

---

## 经验总结

### 1. 调试方法总结

#### 程序卡死在默认中断处理函数时的调试流程

```
┌─────────────────────────┐
│  程序卡死在 B . 死循环   │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  读取 xPSR 寄存器        │
│  提取 IPSR[8:0]          │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  计算 IRQ = IPSR - 16    │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  查找 startup.s 向量表   │
│  定位中断源               │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  检查中断处理函数是否:    │
│  1. 正确声明 extern "C"  │
│  2. 符号名称匹配         │
│  3. 正确链接到向量表     │
└─────────────────────────┘
```

#### 中断优先级死锁的识别特征

✅ **识别方法**:
1. 中断确实在触发（断点能进入ISR）
2. 主循环仍然卡在等待标志
3. 独立测试正常，在其他中断上下文调用时失败
4. 等待的中断优先级低于调用者中断优先级

⚠️ **危险模式**: 在中断处理函数中等待另一个中断设置标志

### 2. C++嵌入式开发注意事项

#### extern "C" 使用规则

| 场景 | 是否需要 extern "C" |
|------|-------------------|
| 中断处理函数 | ✅ 必须 |
| 被C代码调用的C++函数 | ✅ 必须 |
| 被汇编代码引用的符号 | ✅ 必须 |
| C++类成员函数 | ❌ 不需要 |
| 仅在C++内部使用的函数 | ❌ 不需要 |

**正确模式**:

**头文件** (.h):
```c
#ifdef __cplusplus
extern "C" {
#endif

void IRQ_Handler(void);
void callback_function(void);

#ifdef __cplusplus
}
#endif
```

**实现文件** (.cpp):
```cpp
extern "C" void IRQ_Handler(void)
{
    // 中断处理代码
}

extern "C" void callback_function(void)
{
    // C接口函数
}
```

### 3. DMA编程顺序

**标准DMA配置流程**:
```cpp
// 1. 禁用DMA流
DMA_Stream->CR &= ~DMA_SxCR_EN;

// 2. 等待流完全禁用
while(DMA_Stream->CR & DMA_SxCR_EN);

// 3. 配置DMA参数
DMA_Stream->NDTR = size;
DMA_Stream->M0AR = buffer_addr;
DMA_Stream->PAR = peripheral_addr;

// 4. 清除所有标志
DMA_LIFCR/HIFCR = clear_all_flags;

// 5. 配置外设DMA请求

// 6. 使能DMA流
DMA_Stream->CR |= DMA_SxCR_EN;
```

### 4. 中断优先级设计原则

#### 优先级分配策略

```
优先级 0-1:   时间关键型中断 (DMA完成、ADC采样)
优先级 2-4:   通信外设 (USB, UART, SPI)
优先级 5-7:   低速外设 (GPIO, 定时器)
优先级 8-15:  后台任务
```

#### 死锁预防规则

❌ **禁止模式**:
```cpp
void High_Priority_IRQ(void)  // 优先级高
{
    start_dma();
    while(!dma_done);  // ❌ 等待低优先级中断设置标志 → 死锁
}

void Low_Priority_DMA_IRQ(void)  // 优先级低
{
    dma_done = 1;  // 无法抢占高优先级中断 → 永远不执行
}
```

✅ **正确模式1**: 调整优先级
```cpp
// DMA中断优先级 > 调用者优先级
nvic_irq_enable(DMA_IRQ, 0, 0);    // DMA最高优先级
nvic_irq_enable(USB_IRQ, 1, 0);    // USB次高优先级
```

✅ **正确模式2**: 使用状态机
```cpp
void High_Priority_IRQ(void)
{
    start_dma();
    state = WAITING_DMA;  // 设置状态，返回
}

void Low_Priority_DMA_IRQ(void)
{
    dma_done = 1;
    state = DMA_COMPLETE;
}

void main_loop(void)
{
    if(state == DMA_COMPLETE) {
        // 处理完成事件
    }
}
```

### 5. 常用调试寄存器速查

| 寄存器 | 地址 | 用途 | 如何使用 |
|--------|------|------|----------|
| **xPSR** | CPU寄存器 | 获取当前异常号 | 在调试器查看，提取IPSR字段 |
| **LR** | CPU寄存器 | 异常返回类型 | 检查是否嵌套中断 |
| **PC** | CPU寄存器 | 当前执行地址 | 定位卡死位置 |
| **ISPR0-7** | 0xE000E200+ | 中断挂起状态 | 查看哪些中断pending |
| **IABR0-7** | 0xE000E300+ | 中断激活状态 | 查看哪些中断正在执行 |
| **IPR0-59** | 0xE000E400+ | 中断优先级 | 检查优先级配置 |

### 6. 本项目修复清单

- [x] 添加 USB_VBUS_IGNORE (PA9硬件约束)
- [x] USB中断处理函数添加 extern "C"
- [x] QSPI EDMA中断处理函数添加 extern "C"
- [x] 禁用EDMA半传输中断
- [x] 修正DMA配置顺序（先禁用再配置）
- [x] 调整EDMA中断优先级为最高 (0 > USB的1)
- [x] 添加调试计数器方便问题定位
- [x] 实现Flash读-改-写避免数据丢失

### 7. 相关文件清单

| 文件 | 修改内容 | 行号 |
|------|---------|------|
| `usb_conf.h` | 定义 USB_VBUS_IGNORE | 198 |
| `HAL_USB.cpp` | 所有USB函数添加 extern "C" | 56, 148, 211, 223, 233, 244 |
| `UsbMsc.h` | 函数声明添加 extern "C" 块 | 33-74 |
| `qspi_cmd_en25qh128a.cpp` | EDMA中断处理添加 extern "C" | 165 |
| `qspi_cmd_en25qh128a.cpp` | 禁用半传输中断 | 153 |
| `qspi_cmd_en25qh128a.cpp` | 修正DMA配置顺序 | 320-345, 369-394 |
| `qspi_cmd_en25qh128a.cpp` | 调整EDMA优先级为0 | 157 |
| `qspi_cmd_en25qh128a.cpp` | 添加调试计数器 | 46-50, 168-215 |
| `msc_diskio.cpp` | 实现读-改-写逻辑 | 127-178 |

---

## 参考资料

1. **ARM Cortex-M4 Technical Reference Manual**
   - xPSR寄存器详细说明
   - 异常模型和中断优先级

2. **AT32F435/437 Reference Manual**
   - EDMA (Enhanced DMA) 编程
   - USB OTG控制器配置

3. **C++ ABI for ARM**
   - 名称修饰规则
   - extern "C" 链接规范

---

**文档版本**: 1.0
**最后更新**: 2025-12-20
**作者**: Claude Code调试会话记录
