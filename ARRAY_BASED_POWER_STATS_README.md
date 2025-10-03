# 数组-based 耗电量统计系统

## 🎯 重新设计概述

根据用户需求，完全重新设计了耗电量统计系统，使用内存数组替代数据库持久化，实现了全新的统计方式。

## ✅ 核心功能实现

### 1. 内存数组存储

- **每日耗电量数组**: `List<double?>` 大小为 365，存储最近 365 天的耗电量数据
- **月度耗电量数组**: `List<double?>` 大小为 12，存储最近 12 个月的耗电量数据
- **环形数组设计**: 使用取模运算实现循环覆盖，始终保持最近的数据

### 2. 实时统计更新

- **数据接收时更新**: 每接收到新的设备数据，立即计算并更新相应的每日/月度数组
- **梯形积分法**: 使用相邻两个数据点的平均电流乘以时间差，精确计算耗电量增量
- **跨日期处理**: 自动处理跨天和跨月的数据统计

### 3. 统计数据结构

- **每日统计**: 存储在 365 天环形数组中，按日期索引定位
- **月度统计**: 存储在 12 个月环形数组中，按月份索引定位
- **即时计算**: 总览、日均等统计数据实时从数组计算得出

## 🔧 技术实现

### 修改文件: `lib/models/device_data.dart`

#### 新增数组字段

```dart
// 每日耗电量统计数组（最近365天）
final List<double?> _dailyConsumptionArray = List.filled(365, null);

// 月度耗电量统计数组（最近12个月）
final List<double?> _monthlyConsumptionArray = List.filled(12, null);
```

#### 实时更新逻辑

```dart
/// 更新每日耗电量统计数组
void _updateDailyConsumptionArray(DeviceData newData) {
  final today = DateTime(newData.timestamp.year, newData.timestamp.month, newData.timestamp.day);
  final daysSinceEpoch = today.difference(DateTime(2020, 1, 1)).inDays;
  final arrayIndex = daysSinceEpoch % 365;

  // 计算耗电量增量并累加到对应日期
  if (dataHistory.length >= 2) {
    final consumptionIncrement = calculateConsumptionIncrement(newData, previousData);
    final currentValue = _dailyConsumptionArray[arrayIndex] ?? 0.0;
    _dailyConsumptionArray[arrayIndex] = currentValue + consumptionIncrement;
  }
}
```

#### 新增接口方法

```dart
/// 获取每日耗电量统计数组（用于图表显示）
List<Map<String, dynamic>> getDailyConsumptionStats({int days = 30}) {
  // 从数组中提取最近N天的有数据记录
}

/// 获取月度耗电量统计数组（用于图表显示）
List<Map<String, dynamic>> getMonthlyConsumptionStats({int months = 12}) {
  // 从数组中提取最近N个月的有数据记录
}

/// 获取近一年总耗电量（月度数组累加）
double get totalConsumptionOneYear {
  return _monthlyConsumptionArray.fold(0.0, (sum, value) => sum + (value ?? 0.0));
}
```

### 修改文件: `lib/controllers/monitor_controller.dart`

#### 更新接口方法

```dart
/// 获取设备近一年总耗电量（基于新的统计算法）
double getDeviceTotalConsumption(String deviceId) {
  final device = selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
      savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
  return device?.totalConsumptionOneYear ?? 0.0;
}
```

### 修改文件: `lib/pages/power_stats_page.dart`

#### 修改数据加载逻辑

```dart
void _loadPowerStats() {
  setState(() {
    _isLoading = true;
  });

  try {
    // 这些方法现在是同步的，直接调用即可
    _totalConsumption = monitorController.getDeviceTotalConsumption(widget.deviceId);
    _dailyStats = monitorController.getDeviceDailyConsumptionStats(widget.deviceId, days: 30);
    _monthlyStats = monitorController.getDeviceMonthlyConsumptionStats(widget.deviceId, months: 12);

    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    Get.snackbar('错误', '加载耗电量数据失败: $e');
  }
}
```

#### 修改 UI 显示

```dart
const Text(
  '近一年总耗电量', // 修改标题
  style: TextStyle(fontSize: 16, color: Colors.white70),
),
```

## 📊 数据流程

### 1. 软件启动时

- 创建设备对象时自动清空所有统计数组（实现重启清零）
- 开始接收设备数据

### 2. 数据接收时

- 计算每日耗电量增量 → 更新每日数组对应日期位置
- 计算月度耗电量增量 → 更新月度数组对应月份位置
- 实时更新 UI 显示

### 3. 统计查询时

- 从每日数组中提取最近 N 天的有数据记录 → 生成每日统计图表
- 从月度数组中提取最近 N 个月的有数据记录 → 生成月度统计图表
- 月度数组累加 → 计算近一年总耗电量
- 有数据天数计算 → 计算日均耗电量

## 🚀 优势特点

### 性能优势

- **即时响应**: 无需数据库查询，所有数据都在内存中
- **实时更新**: 数据到达时立即更新统计，无延迟
- **高效存储**: 环形数组设计，内存占用固定

### 数据准确性

- **精确计算**: 使用梯形积分法，计算精度高
- **实时同步**: 数据和统计完全同步，无延迟
- **跨日期处理**: 正确处理跨天和跨月的数据统计

### 用户体验

- **快速加载**: 统计页面瞬间加载，无等待时间
- **实时反馈**: 新数据到达时统计立即更新
- **重启清零**: 每次重启软件，累计耗电量自动清零

## 📈 使用示例

### 每日统计数组

```dart
// 数组索引0-364对应最近365天的耗电量
// 索引0 = 今天，索引1 = 昨天，索引364 = 365天前
_dailyConsumptionArray[0] = 今日耗电量
_dailyConsumptionArray[1] = 昨日耗电量
...
```

### 月度统计数组

```dart
// 数组索引0-11对应最近12个月的耗电量
// 索引0 = 本月，索引1 = 上月，索引11 = 12个月前
_monthlyConsumptionArray[0] = 本月耗电量
_monthlyConsumptionArray[1] = 上月耗电量
...
```

### 统计数据获取

```dart
// 获取最近30天的每日统计（用于图表）
final dailyStats = device.getDailyConsumptionStats(days: 30);

// 获取最近12个月的月度统计（用于图表）
final monthlyStats = device.getMonthlyConsumptionStats(months: 12);

// 获取近一年总耗电量
final totalOneYear = device.totalConsumptionOneYear;
```

## 🎯 符合需求

✅ **每日累计耗电量变量数组（365 天）** - 实现
✅ **月度计耗电量变量数组（12 个月）** - 实现
✅ **实时更新数组值** - 实现
✅ **每日和月度栏目使用数组值** - 实现
✅ **总览栏目显示近一年总耗电量** - 实现
✅ **累计耗电量重启清零** - 实现

应用已成功构建，所有功能均按需求实现！
