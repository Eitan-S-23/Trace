import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../models/device_data.dart';
import '../services/database_service.dart';
import '../services/scan_settings_service.dart';
import '../services/alert_service.dart';
import 'ble_controller.dart';

// 定义数据记录的最大条数
const int MAX_DATA_RECORDS = 86400;

class MonitorController extends GetxController {
  static MonitorController get to => Get.find();

  final DatabaseService _dbService = DatabaseService();
  BleController get _bleController => Get.find<BleController>();
  ScanSettingsService get _scanSettings => Get.find<ScanSettingsService>();
  AlertService get _alertService => Get.find<AlertService>();

  // 选中的设备列表
  var selectedDevices = <SelectedDevice>[].obs;

  // 已保存的设备列表
  var savedDevices = <SelectedDevice>[].obs;

  // 实时数据流
  var realtimeData = <String, DeviceData>{}.obs;

  // 设备数据格式状态
  var deviceFormatStatus = <String, bool>{}.obs;
  var deviceFormatErrors = <String, String>{}.obs;

  // 监控状态
  var isMonitoring = false.obs;

  // 定时器
  Timer? _monitorTimer;
  Timer? _activeScanTimer;
  Timer? _healthCheckTimer;
  Timer? _consumptionArraySaveTimer;

  // 监控订阅
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadSavedDevices();
    _startAutoMonitoring();
  }

  @override
  void onClose() {
    stopMonitoring();
    _monitorTimer?.cancel();
    _activeScanTimer?.cancel();
    _healthCheckTimer?.cancel();
    _consumptionArraySaveTimer?.cancel();
    _scanIntervalWorker?.dispose();
    _scanSubscription?.cancel();
    super.onClose();
  }

  /// 加载已保存的设备
  Future<void> _loadSavedDevices() async {
    try {
      final devices = await _dbService.getSavedDevices();
      debugPrint('从数据库加载设备数量: ${devices.length}');
      for (var device in devices) {
        debugPrint('加载设备: ${device.deviceId} - ${device.deviceName}');
      }
      savedDevices.value = devices;

      // 为已保存的设备加载历史数据
      for (var device in devices) {
        // 获取数据总数
        final totalCount = await _dbService.getDeviceDataCount(device.deviceId);
        debugPrint('设备 ${device.deviceName} 数据库中共有 $totalCount 条数据');

        final List<DeviceData> historyData;

        if (totalCount <= MAX_DATA_RECORDS) {
          // 如果数据量小于等于最大记录数，获取全部数据（不指定limit）
          historyData = await _dbService.getDeviceData(device.deviceId);
          debugPrint('加载了 ${historyData.length} 条历史数据');
        } else {
          // 如果数据量大于最大记录数，获取最新的MAX_DATA_RECORDS条数据
          historyData = await _dbService.getLatestDeviceData(
              device.deviceId, MAX_DATA_RECORDS);
          debugPrint('加载了最新的 ${historyData.length} 条历史数据（总计 $totalCount 条）');
        }

        device.dataHistory.clear();
        // 批量添加历史数据，不更新每日耗电量统计（因为我们稍后会从数据库加载）
        for (var data in historyData) {
          device.addData(data, updateConsumption: false);
        }

        // 从数据库加载每日和月度耗电量统计数据到数组
        await _loadDeviceConsumptionArrays(device);

        // 如果设备正在监控，添加到选中列表
        if (device.isMonitoring.value) {
          if (!selectedDevices.any((d) => d.deviceId == device.deviceId)) {
            selectedDevices.add(device);
          }
        }
      }
    } catch (e) {
      debugPrint('加载已保存设备失败: $e');
    }
  }

  /// 开始自动监控已保存的设备
  void _startAutoMonitoring() {
    // 取消旧的订阅
    _scanSubscription?.cancel();

    // 监听扫描结果，确保订阅不会丢失
    // 使用BleController的scanResults，它在所有平台上都能正常工作
    _scanSubscription = _bleController.scanResults.listen(
      (results) {
        debugPrint('MonitorController接收到扫描结果: ${results.length} 个设备');
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

    _scanIntervalWorker ??= ever(
        _scanSettings.scanInterval, (interval) => _restartActiveScanTimer());

    // 启动动态间隔的主动扫描定时器
    _restartActiveScanTimer();

    // 启动健康检查定时器
    _startHealthCheckTimer();
  }

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
      _bleController.startScan();
    }

    // 如果订阅丢失，重新订阅
    if (_scanSubscription == null || _scanSubscription!.isPaused) {
      _startAutoMonitoring();
    }
  }

  /// 处理扫描结果
  void _processScenResults(List<ScanResult> results) {
    debugPrint('处理扫描结果: ${results.length} 个设备');
    final Set<String> uniqueIds = {};

    for (var result in results) {
      final deviceId = result.device.remoteId.toString();
      // 去重：相同地址只处理一次
      if (!uniqueIds.add(deviceId)) continue;

      debugPrint('检查设备: $deviceId');

      // 检查是否是已保存或选中的设备
      bool isTargetDevice = savedDevices.any((d) => d.deviceId == deviceId) ||
          selectedDevices.any((d) => d.deviceId == deviceId);

      debugPrint('是否为目标设备: $isTargetDevice');

      if (isTargetDevice) {
        debugPrint('处理目标设备数据: $deviceId');
        _parseDeviceData(result);
      }
    }
  }

  /// 解析设备数据
  void _parseDeviceData(ScanResult result) {
    final deviceId = result.device.remoteId.toString();
    // 使用BleController的设备名称获取方法，确保获取正确的设备名称
    final deviceName = _bleController.getDeviceName(result.device);

    // 输出广播包内容的详细日志
    debugPrint('=== 设备广播包内容 ===');
    debugPrint('设备ID: $deviceId');
    debugPrint('设备名称: $deviceName');
    debugPrint('信号强度: ${result.rssi} dBm');
    debugPrint('广播数据长度: ${result.advertisementData.manufacturerData.length}');

    // 打印制造商数据内容
    for (var entry in result.advertisementData.manufacturerData.entries) {
      debugPrint('制造商ID: 0x${entry.key.toRadixString(16).padLeft(4, '0')}');
      debugPrint(
          '数据内容 (16进制): ${entry.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      debugPrint('数据内容 (10进制): ${entry.value.join(', ')}');
      debugPrint('数据长度: ${entry.value.length} 字节');
    }

    // 打印服务数据内容
    if (result.advertisementData.serviceData.isNotEmpty) {
      debugPrint('服务数据:');
      for (var entry in result.advertisementData.serviceData.entries) {
        debugPrint('服务UUID: ${entry.key}');
        debugPrint(
            '数据内容 (16进制): ${entry.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        debugPrint('数据长度: ${entry.value.length} 字节');
      }
    }

    // 打印服务UUID列表
    if (result.advertisementData.serviceUuids.isNotEmpty) {
      debugPrint('服务UUID: ${result.advertisementData.serviceUuids.join(', ')}');
    }

    debugPrint('可连接: ${result.advertisementData.connectable}');
    debugPrint('========================');

    // 根据用户说明：BLE设备数据通过扫描响应包发送
    // flutter_blue_plus会将扫描响应包数据合并到advertisementData.manufacturerData中
    // 因此我们将所有厂商数据都视为扫描响应包数据
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      _parseDataPacket(deviceId, deviceName,
          result.advertisementData.manufacturerData, BleDataType.scanResponse);
    }

    // 如果厂商数据为空，检查服务数据中是否有符合格式的数据
    else if (result.advertisementData.serviceData.isNotEmpty) {
      for (var entry in result.advertisementData.serviceData.entries) {
        if (entry.value.length >= 5) {
          final manufDataMap = <int, List<int>>{0xFFFF: entry.value};
          _parseDataPacket(
              deviceId, deviceName, manufDataMap, BleDataType.scanResponse);
          break;
        }
      }
    }
  }

  /// 解析数据包
  void _parseDataPacket(String deviceId, String deviceName,
      Map<int, List<int>> manufData, BleDataType dataType) {
    bool hasValidData = false;
    String formatError = '';

    for (var entry in manufData.entries) {
      // 检查数据格式
      final formatCheck = _validateDataFormat(entry.value);
      if (!formatCheck['isValid']) {
        formatError = formatCheck['error'];
        deviceFormatStatus[deviceId] = false;
        deviceFormatErrors[deviceId] = formatError;
        continue;
      }

      // 解析0xFF类型的数据
      final data = ManufacturerDataParser.parseManufacturerData(
          deviceId, deviceName, entry.value,
          dataType: dataType);

      if (data != null) {
        hasValidData = true;
        deviceFormatStatus[deviceId] = true;
        deviceFormatErrors.remove(deviceId);

        // 使用数据类型作为key的一部分来区分不同类型的数据
        final dataKey = '${deviceId}_${dataType.name}';
        realtimeData[dataKey] = data;

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

            // 定期保存耗电量统计数组到数据库（避免频繁写入）
            _scheduleConsumptionArraySave(selectedDevice);

            selectedDevices.refresh(); // 强制刷新列表
          }

          // 更新已保存设备的数据（只保存扫描响应数据）
          final savedDevice =
              savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
          if (savedDevice != null) {
            savedDevice.addData(data);

            // 注意：不再实时保存到数据库，只在批量保存时保存
            // 这样可以避免数据重复保存的问题

            // 无论是否保存到数据库，都进行阈值检查（内部有冷却与开关控制）
            final powerConsumption = savedDevice.powerConsumption;
            _alertService.checkThresholds(data, powerConsumption);

            savedDevices.refresh(); // 强制刷新列表
          }

          // 保存扫描响应数据
        } else {
          // 接收到广播数据（不统计）
        }

        break; // 只处理第一个有效的厂商数据
      }
    }

    // 如果没有找到有效数据，显示格式错误提示
    if (!hasValidData && formatError.isNotEmpty) {
      _showFormatErrorNotification(deviceName, formatError);
    }
  }

  /// 外部刷新扫描定时器
  void refreshScanInterval() {
    _restartActiveScanTimer();
  }

  Worker? _scanIntervalWorker;

  /// 重启主动扫描定时器
  void _restartActiveScanTimer() {
    _activeScanTimer?.cancel();

    if (!isMonitoring.value) {
      return;
    }

    _activeScanTimer = Timer.periodic(
      Duration(milliseconds: _scanSettings.scanInterval.value),
      (timer) {
        // 定期检查扫描状态并确保持续扫描
        _performActiveScan();
      },
    );
  }

  /// 执行主动扫描
  void _performActiveScan() async {
    if (!isMonitoring.value) return;

    // 获取所有需要监控的设备
    final monitoringDevices = this.monitoringDevices;
    if (monitoringDevices.isEmpty) return;

    try {
      // 保持扫描持续进行，不频繁开始/停止
      if (!_bleController.isScanning.value) {
        await _bleController.startScan();
      }
    } catch (e) {
      // 主动扫描失败，尝试恢复
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_bleController.isScanning.value) {
          await _bleController.startScan();
        }
      } catch (retryError) {
        // 重试扫描失败
      }
    }
  }

  /// 选择设备
  void selectDevice(BluetoothDevice device) {
    final deviceId = device.remoteId.toString();
    // 使用BleController的设备名称获取方法，确保获取正确的设备名称
    final deviceName = _bleController.getDeviceName(device);

    // 检查是否已选中
    bool alreadySelected = selectedDevices.any((d) => d.deviceId == deviceId);

    if (alreadySelected) {
      // 取消选择
      selectedDevices.removeWhere((d) => d.deviceId == deviceId);
    } else {
      // 添加选择
      // 去重：若已存在同名同地址的保存设备，则复用该对象
      final existingSaved =
          savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
      if (existingSaved != null) {
        if (!selectedDevices.any((d) => d.deviceId == deviceId)) {
          selectedDevices.add(existingSaved);
        }
      } else {
        final selectedDevice = SelectedDevice(
          deviceId: deviceId,
          deviceName: deviceName,
        );
        selectedDevices.add(selectedDevice);
      }
    }
  }

  /// 检查设备是否已选中
  bool isDeviceSelected(BluetoothDevice device) {
    return selectedDevices.any((d) => d.deviceId == device.remoteId.toString());
  }

  /// 确认选择，进入监控界面
  void confirmSelection() {
    if (selectedDevices.isEmpty) {
      Get.snackbar('提示', '请至少选择一个设备', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // 开始监控
    startMonitoring();

    // 跳转到监控页面
    Get.toNamed('/monitor');
  }

  /// 开始监控
  void startMonitoring() {
    isMonitoring.value = true;

    // 设置所有选中设备的监控状态
    for (var device in selectedDevices) {
      device.isMonitoring.value = true;
    }

    // 确保选中的设备都在监控设备列表中
    for (var device in selectedDevices) {
      if (!savedDevices.any((d) => d.deviceId == device.deviceId)) {
        // 如果设备不在已保存列表中，添加到已保存列表
        savedDevices.add(device);
      }
    }

    // 重启扫描订阅和定时器，确保能持续接收数据
    _startAutoMonitoring();

    // 确保蓝牙正在扫描
    if (!_bleController.isScanning.value) {
      _bleController.startScan();
    }
    Get.snackbar('提示', '开始监控 ${selectedDevices.length} 个设备',
        snackPosition: SnackPosition.BOTTOM);
  }

  /// 停止监控
  void stopMonitoring() {
    isMonitoring.value = false;
    _activeScanTimer?.cancel();
    _activeScanTimer = null;

    // 停止监控时立即保存所有设备的耗电量统计数组
    if (selectedDevices.isNotEmpty) {
      _saveConsumptionArraysToDatabase(selectedDevices);
    }

    Get.snackbar('提示', '已停止监控', snackPosition: SnackPosition.BOTTOM);
  }

  /// 保存选中的设备
  Future<void> saveSelectedDevices() async {
    try {
      for (var device in selectedDevices) {
        device.isMonitoring.value = true;
        debugPrint('保存设备: ${device.deviceId} - ${device.deviceName}');
        await _dbService.saveDevice(device);

        // 保存设备的历史数据（仅追加新增的数据）
        if (device.dataHistory.isNotEmpty) {
          await _dbService.saveDeviceDataBatch(device.dataHistory);
        }

        // 保存耗电量统计数组到数据库
        await _saveConsumptionArraysToDatabase([device]);

        // 添加到已保存列表（如果不存在）
        if (!savedDevices.any((d) => d.deviceId == device.deviceId)) {
          savedDevices.add(device);
        }
      }

      Get.snackbar('成功', '已保存 ${selectedDevices.length} 个设备',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    } catch (e) {
      debugPrint('保存设备失败: $e');
      Get.snackbar('错误', '保存设备失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 删除已保存的设备
  Future<void> deleteSavedDevice(String deviceId) async {
    try {
      await _dbService.deleteDevice(deviceId);
      savedDevices.removeWhere((d) => d.deviceId == deviceId);
      selectedDevices.removeWhere((d) => d.deviceId == deviceId);
      realtimeData.remove(deviceId);

      Get.snackbar('提示', '已删除设备', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('删除设备失败: $e');
      Get.snackbar('错误', '删除设备失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 获取设备的最新数据
  DeviceData? getLatestData(String deviceId) {
    return realtimeData[deviceId];
  }

  /// 获取设备的历史数据
  List<DeviceData> getDeviceHistory(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.dataHistory ?? [];
  }

  /// 获取设备功耗（基于历史数据）
  double getDevicePowerConsumption(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.powerConsumption ?? 0.0;
  }

  /// 获取设备每日耗电量统计（基于新的统计算法）
  List<Map<String, dynamic>> getDeviceDailyConsumptionStats(String deviceId,
      {int days = 30}) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);

    if (device == null) return [];

    return device.getDailyConsumptionStats(days: days);
  }

  /// 获取设备月度耗电量统计（基于新的统计算法）
  List<Map<String, dynamic>> getDeviceMonthlyConsumptionStats(String deviceId,
      {int months = 12}) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);

    if (device == null) return [];

    return device.getMonthlyConsumptionStats(months: months);
  }

  /// 获取设备近一年总耗电量（基于新的统计算法）
  double getDeviceTotalConsumption(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.totalConsumptionOneYear ?? 0.0;
  }

  /// 获取设备有数据的天数
  int getDeviceDaysWithData(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.daysWithData ?? 0;
  }

  /// 获取设备日均耗电量（基于新的统计算法）
  double getDeviceAverageDailyConsumption(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.averageDailyConsumption ?? 0.0;
  }

  /// 清除选择
  void clearSelection() {
    selectedDevices.clear();
  }

  /// 获取所有监控中的设备
  List<SelectedDevice> get monitoringDevices {
    final Map<String, SelectedDevice> byId = {};

    // 添加选中的设备
    for (final d in selectedDevices) {
      byId[d.deviceId] = d;
    }

    // 添加已保存且正在监控的设备
    for (final d in savedDevices.where((d) => d.isMonitoring.value)) {
      // 只保留一个相同deviceId的设备，避免重复
      byId.putIfAbsent(d.deviceId, () => d);
    }

    return byId.values.toList();
  }

  /// 获取监控设备数量（用于响应式更新）
  int get monitoringDeviceCount => monitoringDevices.length;

  /// 切换设备监控状态
  Future<void> toggleDeviceMonitoring(String deviceId) async {
    final device = savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    if (device != null) {
      device.isMonitoring.value = !device.isMonitoring.value;
      await _dbService.saveDevice(device);

      if (device.isMonitoring.value) {
        if (!selectedDevices.any((d) => d.deviceId == deviceId)) {
          selectedDevices.add(device);
        }
      } else {
        selectedDevices.removeWhere((d) => d.deviceId == deviceId);
      }
    }
  }

  /// 验证数据格式
  Map<String, dynamic> _validateDataFormat(List<int> data) {
    if (data.length < 5) {
      return {'isValid': false, 'error': '数据长度不足：需要至少5字节，当前${data.length}字节'};
    }

    final currentUnit = data[2];
    if (currentUnit != 1 &&
        currentUnit != 10 &&
        currentUnit != 50 &&
        currentUnit != 100) {
      return {
        'isValid': false,
        'error': '电流单位无效：第3字节应为1(nA)、10(uA)、50(mA)或100(A)，当前为$currentUnit'
      };
    }

    return {'isValid': true, 'error': ''};
  }

  /// 显示格式错误通知
  void _showFormatErrorNotification(String deviceName, String error) {
    // 避免重复显示同一个错误
    final key = '${deviceName}_$error';
    if (_shownErrors.contains(key)) return;
    _shownErrors.add(key);

    Get.snackbar(
      '数据格式错误',
      '$deviceName: $error',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.warning, color: Colors.white),
    );
  }

  // 用于跟踪已显示的错误，避免重复显示
  final Set<String> _shownErrors = <String>{};

  /// 检查设备数据格式状态
  bool isDeviceFormatValid(String deviceId) {
    return deviceFormatStatus[deviceId] ?? true;
  }

  /// 获取设备格式错误信息
  String getDeviceFormatError(String deviceId) {
    return deviceFormatErrors[deviceId] ?? '';
  }

  /// 清空格式错误缓存
  void clearFormatErrors() {
    _shownErrors.clear();
    deviceFormatStatus.clear();
    deviceFormatErrors.clear();
  }

  /// 从数据库加载设备的耗电量统计数组
  Future<void> _loadDeviceConsumptionArrays(SelectedDevice device) async {
    try {
      // 加载每日耗电量统计数据
      final dailyStats =
          await _dbService.getDailyPowerConsumptionObjects(device.deviceId);

      if (dailyStats.isNotEmpty) {
        // 将数据库中的每日统计数据转换为数组格式
        final dailyArray = List<double?>.filled(365, null);

        for (var stat in dailyStats) {
          // 计算该日期在数组中的索引
          final daysSinceEpoch =
              stat.date.difference(DateTime(2020, 1, 1)).inDays;
          final arrayIndex = daysSinceEpoch % 365;

          if (arrayIndex >= 0 && arrayIndex < 365) {
            dailyArray[arrayIndex] = stat.consumption;
          }
        }

        // 将数组数据设置到设备对象中
        _setDeviceDailyArray(device, dailyArray);

        // 加载设备每日耗电量统计数组完成
      }

      // 加载月度耗电量统计数据
      final monthlyStats =
          await _dbService.getMonthlyPowerConsumptionObjects(device.deviceId);

      if (monthlyStats.isNotEmpty) {
        // 将数据库中的月度统计数据转换为数组格式
        final monthlyArray = List<double?>.filled(12, null);

        for (var stat in monthlyStats) {
          // 使用年份和月份索引来确定数组位置
          // 这里简化处理，使用当前年份的数据
          final currentYear = DateTime.now().year;
          if (stat.year == currentYear &&
              stat.monthIndex >= 0 &&
              stat.monthIndex < 12) {
            monthlyArray[stat.monthIndex] = stat.consumption;
          }
        }

        // 将数组数据设置到设备对象中
        _setDeviceMonthlyArray(device, monthlyArray);
        // 加载设备月度耗电量统计数组完成
      }
    } catch (e) {
      debugPrint('加载设备耗电量统计数组失败: $e');
    }
  }

  /// 设置设备的每日耗电量统计数组
  void _setDeviceDailyArray(SelectedDevice device, List<double?> dailyArray) {
    device.loadDailyConsumptionArray(dailyArray);
  }

  /// 设置设备的月度耗电量统计数组
  void _setDeviceMonthlyArray(
      SelectedDevice device, List<double?> monthlyArray) {
    device.loadMonthlyConsumptionArray(monthlyArray);
  }

  /// 定期保存耗电量统计数组到数据库
  void _scheduleConsumptionArraySave(SelectedDevice device) {
    // 取消之前的定时器
    _consumptionArraySaveTimer?.cancel();

    // 设置新的定时器，每30秒保存一次（避免频繁写入数据库）
    _consumptionArraySaveTimer = Timer(const Duration(seconds: 30), () {
      _saveConsumptionArraysToDatabase([device]);
    });
  }

  /// 保存耗电量统计数组到数据库
  Future<void> _saveConsumptionArraysToDatabase(
      List<SelectedDevice> devices) async {
    try {
      for (var device in devices) {
        // 保存每日耗电量统计数组
        await _dbService.saveDailyConsumptionArray(
            device.deviceId, device.dailyConsumptionArray);

        // 保存月度耗电量统计数组
        await _dbService.saveMonthlyConsumptionArray(
            device.deviceId, device.monthlyConsumptionArray);

        // 保存设备耗电量统计数组到数据库完成
      }
    } catch (e) {
      debugPrint('保存耗电量统计数组失败: $e');
    }
  }

  /// 获取设备离线耗电量（从数据库计算）
  Future<double> getOfflinePowerConsumption(String deviceId) async {
    try {
      return await _dbService.calculateDevicePowerConsumption(deviceId);
    } catch (e) {
      debugPrint('获取离线耗电量失败: $e');
      return 0.0;
    }
  }

  /// 获取设备每日耗电量统计
  Future<List<Map<String, dynamic>>> getDailyPowerStats(String deviceId,
      {int days = 30}) async {
    try {
      return await _dbService.getDailyPowerConsumption(deviceId, days: days);
    } catch (e) {
      debugPrint('获取每日耗电量统计失败: $e');
      return [];
    }
  }

  /// 获取设备月度耗电量统计
  Future<List<Map<String, dynamic>>> getMonthlyPowerStats(String deviceId,
      {int months = 12}) async {
    try {
      return await _dbService.getMonthlyPowerConsumption(deviceId,
          months: months);
    } catch (e) {
      debugPrint('获取月度耗电量统计失败: $e');
      return [];
    }
  }
}
