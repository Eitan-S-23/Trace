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
    _scanSubscription?.cancel();
    super.onClose();
  }

  /// 加载已保存的设备
  Future<void> _loadSavedDevices() async {
    try {
      final devices = await _dbService.getSavedDevices();
      savedDevices.value = devices;

      // 为已保存的设备加载历史数据
      for (var device in devices) {
        // 获取数据总数
        final totalCount = await _dbService.getDeviceDataCount(device.deviceId);
        final List<DeviceData> historyData;

        if (totalCount <= MAX_DATA_RECORDS) {
          // 如果数据量小于等于最大记录数，获取全部数据（明确指定limit为总数量）
          historyData = await _dbService.getDeviceData(device.deviceId,
              limit: totalCount > 0 ? totalCount : null);
        } else {
          // 如果数据量大于最大记录数，获取最新的MAX_DATA_RECORDS条数据
          historyData = await _dbService.getLatestDeviceData(
              device.deviceId, MAX_DATA_RECORDS);
        }

        device.dataHistory.clear();
        device.dataHistory.addAll(historyData);

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

  /// 处理扫描结果
  void _processScenResults(List<ScanResult> results) {
    for (var result in results) {
      final deviceId = result.device.remoteId.toString();

      // 检查是否是已保存或选中的设备
      bool isTargetDevice = savedDevices.any((d) => d.deviceId == deviceId) ||
          selectedDevices.any((d) => d.deviceId == deviceId);

      if (isTargetDevice) {
        _parseDeviceData(result);
      }
    }
  }

  /// 解析设备数据
  void _parseDeviceData(ScanResult result) {
    final deviceId = result.device.remoteId.toString();
    final deviceName = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : '未知设备';

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
        debugPrint('设备$deviceName数据格式错误: $formatError');
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
        } else {
          debugPrint(
              '接收到广播数据（不统计）: $deviceName - ${data.current}${data.currentUnit}, ${data.voltage}mV');
        }

        break; // 只处理第一个有效的厂商数据
      }
    }

    // 如果没有找到有效数据，显示格式错误提示
    if (!hasValidData && formatError.isNotEmpty) {
      _showFormatErrorNotification(deviceName, formatError);
    }
  }

  /// 启动主动扫描定时器
  void _startActiveScanTimer() {
    _activeScanTimer?.cancel();

    // 监听扫描间隔变化并重新启动定时器
    ever(_scanSettings.scanInterval, (interval) {
      _restartActiveScanTimer();
    });

    _restartActiveScanTimer();
  }

  /// 重启主动扫描定时器
  void _restartActiveScanTimer() {
    _activeScanTimer?.cancel();
    _activeScanTimer = Timer.periodic(
        Duration(milliseconds: _scanSettings.scanInterval.value), (timer) {
      _performActiveScan();
    });
  }

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
        // 短暂延迟后重新启动
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

  /// 选择设备
  void selectDevice(BluetoothDevice device) {
    final deviceId = device.remoteId.toString();
    final deviceName =
        device.platformName.isNotEmpty ? device.platformName : '未知设备';

    // 检查是否已选中
    bool alreadySelected = selectedDevices.any((d) => d.deviceId == deviceId);

    if (alreadySelected) {
      // 取消选择
      selectedDevices.removeWhere((d) => d.deviceId == deviceId);
    } else {
      // 添加选择
      final selectedDevice = SelectedDevice(
        deviceId: deviceId,
        deviceName: deviceName,
      );
      selectedDevices.add(selectedDevice);
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

  /// 停止监控
  void stopMonitoring() {
    isMonitoring.value = false;
    _activeScanTimer?.cancel();
    Get.snackbar('提示', '已停止监控', snackPosition: SnackPosition.BOTTOM);
  }

  /// 保存选中的设备
  Future<void> saveSelectedDevices() async {
    try {
      for (var device in selectedDevices) {
        device.isMonitoring.value = true;
        await _dbService.saveDevice(device);

        // 保存设备的历史数据
        if (device.dataHistory.isNotEmpty) {
          await _dbService.saveDeviceDataBatch(device.dataHistory);
        }

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

  /// 获取设备功耗
  double getDevicePowerConsumption(String deviceId) {
    final device =
        selectedDevices.firstWhereOrNull((d) => d.deviceId == deviceId) ??
            savedDevices.firstWhereOrNull((d) => d.deviceId == deviceId);
    return device?.powerConsumption ?? 0.0;
  }

  /// 清除选择
  void clearSelection() {
    selectedDevices.clear();
  }

  /// 获取所有监控中的设备
  List<SelectedDevice> get monitoringDevices {
    return [
      ...selectedDevices,
      ...savedDevices.where((d) => d.isMonitoring.value)
    ];
  }

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
