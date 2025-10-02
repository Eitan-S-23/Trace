# 功率计功能问题修复说明

## 修复日期

2025 年 10 月 2 日

## 问题概述

本次修复解决了功率计功能的三个关键问题：

### 问题 1：程序不能连续接收解析监控中的设备数据

**症状**：接收数个数据后就不能再接收，前端不显示新数据，需要关闭软件重新启动才能再接收数个数据

**根本原因**：

1. 扫描可能被意外停止或中断
2. 扫描订阅可能丢失或被取消
3. 定时器可能失效

### 问题 2：实时监控与设备监控图表界面不能实时更新

**症状**：电流、电压、功率、耗电量及最后更新信息不更新，需要退出该界面再重新进入才会刷新

**根本原因**：

1. 响应式数据更新后没有触发 UI 刷新
2. GetX 的观察者没有检测到数据变化

### 问题 3：耗电量统计图表类型转换错误

**症状**：每日和月度耗电量趋势图表显示红色背景和错误提示 "type 'int' is not a subtype of type 'double'"

**根本原因**：
数据库返回的 consumption 值是 int 类型，但 FlChart 的 FlSpot 需要 double 类型

---

## 修复详情

### 修复 1：优化扫描逻辑，确保持续接收数据

#### 文件：`lib/controllers/monitor_controller.dart`

**修改 1：改进主动扫描机制**

- 位置：`_performActiveScan()` 方法
- 改进内容：
  - 强制重启扫描以确保能持续接收数据
  - 添加扫描失败后的自动重试机制
  - 增强日志输出，便于调试

```dart
/// 执行主动扫描
void _performActiveScan() async {
  if (!isMonitoring.value) return;

  // 获取所有需要监控的设备
  final monitoringDevices = [
    ...selectedDevices,
    ...savedDevices.where((d) => d.isMonitoring.value)
  ];
  if (monitoringDevices.isEmpty) return;

  try {
    // 强制重启扫描以确保能持续接收数据
    if (_bleController.isScanning.value) {
      await _bleController.stopScan();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await _bleController.startScan();
    debugPrint('执行主动扫描监控 - 监控设备数: ${monitoringDevices.length}');
  } catch (e) {
    debugPrint('主动扫描失败: $e');
    // 扫描失败后，尝试恢复
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_bleController.isScanning.value) {
        await _bleController.startScan();
      }
    } catch (retryError) {
      debugPrint('重试扫描失败: $retryError');
    }
  }
}
```

**修改 2：增强扫描订阅的健壮性**

- 位置：`_startAutoMonitoring()` 方法
- 改进内容：
  - 添加错误处理和自动重连机制
  - 设置 `cancelOnError: false` 防止订阅被意外取消
  - 在错误时自动重新订阅

```dart
/// 开始自动监控已保存的设备
void _startAutoMonitoring() {
  // 取消旧的订阅
  _scanSubscription?.cancel();

  // 监听扫描结果，确保订阅不会丢失
  _scanSubscription = FlutterBluePlus.scanResults.listen(
    (results) {
      _processScenResults(results);
    },
    onError: (error) {
      debugPrint('扫描结果监听错误: $error');
      // 错误后重新订阅
      Future.delayed(const Duration(seconds: 1), () {
        _startAutoMonitoring();
      });
    },
    cancelOnError: false, // 出错时不取消订阅
  );

  // 启动动态间隔的主动扫描定时器
  _startActiveScanTimer();

  // 启动健康检查定时器
  _startHealthCheckTimer();
}
```

**修改 3：添加扫描健康检查机制**

- 新增：`_startHealthCheckTimer()` 和 `_checkScanHealth()` 方法
- 功能：
  - 每 5 秒检查一次扫描状态
  - 如果扫描意外停止，自动重新启动
  - 如果订阅丢失，自动重新订阅

```dart
/// 启动健康检查定时器
void _startHealthCheckTimer() {
  _healthCheckTimer?.cancel();

  // 每5秒检查一次扫描状态
  _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    _checkScanHealth();
  });
}

/// 检查扫描健康状态
void _checkScanHealth() {
  // 如果正在监控但扫描已停止，尝试重新启动
  if (isMonitoring.value && !_bleController.isScanning.value) {
    debugPrint('检测到扫描已停止，尝试重新启动...');
    _bleController.startScan();
  }

  // 如果订阅丢失，重新订阅
  if (_scanSubscription == null || _scanSubscription!.isPaused) {
    debugPrint('检测到扫描订阅丢失，重新订阅...');
    _startAutoMonitoring();
  }
}
```

**修改 4：改进监控启动逻辑**

- 位置：`startMonitoring()` 方法
- 改进内容：
  - 在启动监控时重新初始化扫描订阅和定时器
  - 确保所有监控组件都处于活跃状态

```dart
/// 开始监控
void startMonitoring() {
  isMonitoring.value = true;

  // 重启扫描订阅和定时器，确保能持续接收数据
  _startAutoMonitoring();

  // 确保蓝牙正在扫描
  if (!_bleController.isScanning.value) {
    _bleController.startScan();
  }

  debugPrint('开始监控 ${selectedDevices.length} 个设备');
  Get.snackbar('提示', '开始监控 ${selectedDevices.length} 个设备',
      snackPosition: SnackPosition.BOTTOM);
}
```

---

### 修复 2：确保 UI 实时更新

#### 文件：`lib/controllers/monitor_controller.dart`

**修改：强制触发响应式更新**

- 位置：数据解析处理部分
- 改进内容：
  - 使用 `.refresh()` 方法强制刷新响应式列表
  - 确保 GetX 的观察者能检测到数据变化
  - 增强日志输出

```dart
// 只统计扫描响应包的数据
if (dataType == BleDataType.scanResponse) {
  // 强制触发UI更新
  realtimeData[deviceId] = data;
  realtimeData.refresh(); // 确保 Obx 监听器能检测到变化

  // 更新选中设备的数据（只保存扫描响应数据）
  final selectedDevice =
      selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
  if (selectedDevice != null) {
    selectedDevice.addData(data);
    selectedDevices.refresh(); // 强制刷新列表
  }

  // 更新已保存设备的数据（只保存扫描响应数据）
  final savedDevice =
      savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
  if (savedDevice != null) {
    final originalLength = savedDevice.dataHistory.length;
    savedDevice.addData(data);

    // 只有当数据实际被添加时才保存到数据库并检查阈值
    if (savedDevice.dataHistory.length > originalLength) {
      _dbService.saveDeviceData(data);

      // 检查阈值并触发报警
      final powerConsumption = savedDevice.powerConsumption;
      _alertService.checkThresholds(data, powerConsumption);
    }

    savedDevices.refresh(); // 强制刷新列表
  }

  debugPrint(
      '保存扫描响应数据: $deviceName - ${data.current}${data.currentUnit}, ${data.voltage}mV, 功率: ${data.power}mW');
}
```

**工作原理**：

- GetX 的响应式系统依赖于对象引用的变化来触发 UI 更新
- 使用 `.refresh()` 方法可以强制通知所有观察者
- 这确保了即使对象内容改变但引用不变时，UI 也能更新

---

### 修复 3：修复类型转换错误

#### 文件：`lib/pages/power_stats_page.dart`

**修改位置及内容**：

1. **每日图表数据转换** (第 424 行)

```dart
// 修复前
return FlSpot(index.toDouble(), data['consumption']);

// 修复后
return FlSpot(index.toDouble(), (data['consumption'] as num).toDouble());
```

2. **月度图表数据转换** (第 520 行)

```dart
// 修复前
return FlSpot(index.toDouble(), data['consumption']);

// 修复后
return FlSpot(index.toDouble(), (data['consumption'] as num).toDouble());
```

3. **每日排行榜排序** (第 601 行)

```dart
// 修复前
..sort((a, b) =>
    (b['consumption'] as double).compareTo(a['consumption'] as double));

// 修复后
..sort((a, b) =>
    (b['consumption'] as num).toDouble().compareTo((a['consumption'] as num).toDouble()));
```

4. **每日排行榜显示** (第 645 行)

```dart
// 修复前
'${(data['consumption'] as double).toStringAsFixed(2)} mAh'

// 修复后
'${(data['consumption'] as num).toDouble().toStringAsFixed(2)} mAh'
```

5. **月度排行榜排序** (第 661 行)

```dart
// 修复前
..sort((a, b) =>
    (b['consumption'] as double).compareTo(a['consumption'] as double));

// 修复后
..sort((a, b) =>
    (b['consumption'] as num).toDouble().compareTo((a['consumption'] as num).toDouble()));
```

6. **月度排行榜显示** (第 705 行)

```dart
// 修复前
'${(data['consumption'] as double).toStringAsFixed(2)} mAh'

// 修复后
'${(data['consumption'] as num).toDouble().toStringAsFixed(2)} mAh'
```

7. **最近耗电量计算** (第 723 行)

```dart
// 修复前
return recentStats.fold<double>(
    0.0, (sum, data) => sum + (data['consumption'] as double));

// 修复后
return recentStats.fold<double>(
    0.0, (sum, data) => sum + (data['consumption'] as num).toDouble());
```

8. **平均每日耗电量计算** (第 730 行)

```dart
// 修复前
final total = _dailyStats.fold<double>(
    0.0, (sum, data) => sum + (data['consumption'] as double));

// 修复后
final total = _dailyStats.fold<double>(
    0.0, (sum, data) => sum + (data['consumption'] as num).toDouble());
```

**为什么使用 `as num` 而不是 `as double`？**

- SQLite 数据库可能返回 `int` 或 `double` 类型
- `num` 是 `int` 和 `double` 的父类
- 使用 `as num` 可以安全处理两种类型
- 然后调用 `.toDouble()` 转换为 `double`

---

## 测试建议

### 测试场景 1：连续数据接收

1. 启动应用并开始监控设备
2. 观察数据接收情况，应该能持续接收数据
3. 让应用运行较长时间（如 30 分钟以上）
4. 验证数据仍在持续更新，没有中断

### 测试场景 2：实时 UI 更新

1. 进入"实时监控"界面
2. 观察电流、电压、功率、耗电量数据
3. 数据应该实时更新，无需退出重进
4. 进入"设备监控图表"界面
5. 图表应该实时显示最新数据

### 测试场景 3：耗电量统计

1. 进入"耗电量统计"界面
2. 切换到"每日"标签
3. 图表应该正常显示，背景为白色（不是红色）
4. 切换到"月度"标签
5. 图表应该正常显示，背景为白色（不是红色）
6. 查看排行榜，应该正常显示数据

### 测试场景 4：异常恢复

1. 监控过程中手动关闭蓝牙
2. 重新打开蓝牙
3. 系统应该自动恢复扫描并继续接收数据
4. 验证健康检查机制是否正常工作

---

## 技术改进总结

### 健壮性提升

1. **自动恢复机制**：扫描失败或订阅丢失时自动恢复
2. **健康检查**：定期检查系统状态，及时发现并修复问题
3. **错误处理**：完善的错误捕获和处理机制

### 响应性提升

1. **强制刷新**：确保 UI 能检测到数据变化
2. **实时更新**：数据更新立即反映到 UI
3. **类型安全**：修复类型转换错误，避免运行时错误

### 可维护性提升

1. **详细日志**：添加调试日志，便于问题定位
2. **清晰逻辑**：改进代码结构，提高可读性
3. **注释说明**：添加必要的注释，说明关键逻辑

---

## 预期效果

修复后，功率计功能应该达到以下效果：

1. ✅ **持续稳定接收数据**

   - 数据接收不会中断
   - 无需重启应用即可持续监控
   - 长时间运行稳定可靠

2. ✅ **UI 实时更新**

   - 实时监控数据即时显示
   - 设备监控图表实时刷新
   - 无需手动退出重进即可看到最新数据

3. ✅ **图表正常显示**

   - 每日耗电量趋势图正常显示
   - 月度耗电量趋势图正常显示
   - 无类型转换错误
   - 图表背景正常（白色）

4. ✅ **系统稳定性**
   - 自动恢复异常状态
   - 健康检查确保系统正常运行
   - 完善的错误处理机制

---

## 注意事项

1. **蓝牙权限**：确保应用有足够的蓝牙权限
2. **后台运行**：某些设备可能限制后台扫描
3. **性能考虑**：长时间运行可能消耗较多电量
4. **数据库维护**：定期清理旧数据，避免数据库过大

---

## 联系方式

如有问题或建议，请反馈给开发团队。
