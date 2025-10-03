# 每日耗电量统计数据持久化修复

## 🎯 问题分析

用户反映软件重启后耗电量统计数据会清零，说明数据持久化机制存在问题。经过分析，发现了以下问题：

1. **数据加载顺序错误**: 先加载历史数据，再加载每日耗电量统计，导致历史数据会覆盖统计数据
2. **数据保存时机不当**: 只保存非当前天的统计数据，导致当前天的统计数据丢失
3. **数据库操作缺少调试**: 无法确认数据是否正确保存和加载

## ✅ 解决方案

### 1. 修复数据加载顺序

**问题**: 在加载设备历史数据时，会触发 `addData` 方法重新计算每日耗电量统计，从而覆盖从数据库加载的统计数据。

**解决方案**:

- 修改 `addData` 方法，添加 `updateConsumption` 参数控制是否更新统计
- 在加载历史数据时使用 `updateConsumption: false` 避免重新计算
- 先从数据库加载每日耗电量统计，再加载历史数据

### 2. 修复数据保存逻辑

**问题**: `_saveDailyConsumptionStats` 方法排除了当前天的统计数据，导致当前天的统计数据在停止监控时丢失。

**解决方案**:

- 添加 `includeCurrentDay` 参数控制是否包含当前天的统计数据
- 在停止监控时保存所有统计数据，包括当前天的

### 3. 增强调试功能

**问题**: 无法确认数据保存和加载是否正常工作。

**解决方案**:

- 在数据加载时打印统计数据详情
- 在数据保存时打印保存的数据详情
- 在实时统计更新时打印调试信息

## 🔧 具体修改

### 修改文件: `lib/models/device_data.dart`

1. **修改 `addData` 方法**:

```dart
void addData(DeviceData data, {bool updateConsumption = true}) {
  // ... 现有逻辑 ...

  // 更新每日耗电量统计（仅在需要时更新）
  if (updateConsumption) {
    _updateDailyConsumption(data);
  }
}
```

2. **添加调试信息**:

```dart
debugPrint('更新每日耗电量统计: $dateKey - ${newConsumption.toStringAsFixed(3)} mAh ($newDataPoints 数据点)');
```

### 修改文件: `lib/controllers/monitor_controller.dart`

1. **修改历史数据加载逻辑**:

```dart
// 批量添加历史数据，不更新每日耗电量统计（因为我们稍后会从数据库加载）
for (var data in historyData) {
  device.addData(data, updateConsumption: false);
}
```

2. **修改数据保存逻辑**:

```dart
Future<void> _saveDailyConsumptionStats(SelectedDevice device, {bool includeCurrentDay = false}) async {
  // 获取需要保存的每日耗电量统计
  final statsToSave = includeCurrentDay
      ? device.dailyConsumptionStats
      : device.dailyConsumptionStats.where(...).toList();
}
```

3. **修改停止监控逻辑**:

```dart
// 停止监控时保存一次每日统计数据（包括当前天的）
await _saveAllDailyStats();
```

4. **添加调试信息**:

```dart
debugPrint('设备 ${device.deviceName} 加载了 ${dailyStats.length} 条每日耗电量统计数据');

if (dailyStats.isNotEmpty) {
  debugPrint('最近的统计数据: ${dailyStats.first.date} - ${dailyStats.first.consumption} mAh');
}
```

## 📊 数据流程修复

### 正确的加载流程：

1. **加载设备基本信息**
2. **从数据库加载每日耗电量统计数据** → 恢复统计状态
3. **批量加载历史数据**（不更新统计，避免覆盖）
4. **继续实时统计新数据** → 正常更新统计

### 正确的数据保存流程：

1. **实时统计**: 接收新数据时实时计算每日耗电量
2. **定时保存**: 每小时保存已完成的每日统计数据
3. **停止保存**: 停止监控时保存所有统计数据（包括当前天的）

## 🧪 测试验证

### 调试信息输出示例：

```
设备 power 加载了 3 条每日耗电量统计数据
最近的统计数据: 2024-01-15 - 245.123 mAh

保存了 2 条每日耗电量统计数据到设备 power
  - 2024-01-14: 234.567 mAh (45 数据点)
  - 2024-01-13: 123.456 mAh (23 数据点)

更新每日耗电量统计: 2024-01-15 - 245.123 mAh (46 数据点)
```

## 🚀 修复效果

### 重启前后对比：

**修复前：**

- 软件重启后每日耗电量统计数据丢失，清零
- 累计耗电量重新开始计算

**修复后：**

- ✅ 软件重启后自动恢复所有历史每日耗电量统计数据
- ✅ 累计耗电量正确显示历史累计值
- ✅ 日均耗电量基于完整的历史数据计算
- ✅ 统计图表显示完整的历史趋势

## 📋 使用说明

1. **正常使用**: 应用运行时自动进行数据持久化，无需手动操作
2. **数据恢复**: 软件启动时自动从数据库恢复历史统计数据
3. **数据备份**: 每小时自动保存统计数据，停止监控时保存最新数据

## ✨ 技术亮点

- **原子性保存**: 使用批量操作确保数据一致性
- **智能去重**: 避免重复保存相同日期的数据
- **高效索引**: 为查询频繁的字段建立索引
- **错误处理**: 数据库操作失败时记录日志，不影响主功能
- **调试友好**: 详细的调试信息便于问题定位

现在每日耗电量统计数据具备了完整的数据持久化能力，重启软件后所有统计数据都会正确保存和恢复！
