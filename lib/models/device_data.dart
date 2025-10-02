import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// BLE数据包类型
enum BleDataType {
  advertisement, // 广播包
  scanResponse, // 扫描响应包
}

/// 设备电量数据模型
class DeviceData {
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final double current; // 电流值 (实际单位)
  final String currentUnit; // 电流单位
  final double voltage; // 电压值 (mV)
  final double power; // 功率值 (计算得出)
  final BleDataType dataType; // 数据包类型

  DeviceData({
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.current,
    required this.currentUnit,
    required this.voltage,
    required this.power,
    required this.dataType,
  });

  /// 转换为Map用于数据库存储
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'current': current,
      'currentUnit': currentUnit,
      'voltage': voltage,
      'power': power,
      'dataType': dataType.index,
    };
  }

  /// 从Map创建对象
  factory DeviceData.fromMap(Map<String, dynamic> map) {
    return DeviceData(
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      current: map['current'].toDouble(),
      currentUnit: map['currentUnit'],
      voltage: map['voltage'].toDouble(),
      power: map['power'].toDouble(),
      dataType: BleDataType.values[map['dataType'] ?? 0],
    );
  }

  @override
  String toString() {
    return 'DeviceData{deviceId: $deviceId, current: $current$currentUnit, voltage: ${voltage}mV, power: ${power}mW, time: $timestamp}';
  }
}

/// 厂商数据解析器
class ManufacturerDataParser {
  /// 解析0xFF厂商数据
  /// 格式：前2字节电流，第3字节电流单位，第4-5字节电压
  static DeviceData? parseManufacturerData(
      String deviceId, String deviceName, List<int> data,
      {BleDataType dataType = BleDataType.advertisement}) {
    try {
      if (data.length < 5) {
        return null; // 数据长度不足
      }

      // 解析电流值 (前2字节，小端序)
      int currentRaw = data[0] | (data[1] << 8);

      // 解析电流单位
      int currentUnitCode = data[2];
      String currentUnit;
      double currentMultiplier;

      switch (currentUnitCode) {
        case 1:
          currentUnit = 'nA';
          currentMultiplier = 1e-9; // 转换为A
          break;
        case 10:
          currentUnit = 'uA';
          currentMultiplier = 1e-6; // 转换为A
          break;
        case 50:
          currentUnit = 'mA';
          currentMultiplier = 1e-3; // 转换为A
          break;
        case 100:
          currentUnit = 'A';
          currentMultiplier = 1; // 已经是A
          break;
        default:
          return null; // 未知单位
      }

      // 解析电压值 (第4-5字节，小端序，单位mV)
      int voltageRaw = data[3] | (data[4] << 8);
      double voltage = voltageRaw.toDouble(); // mV

      // 计算实际电流值
      double current = currentRaw * currentMultiplier;

      // 计算功率 (P = V * I)，电压转换为V
      double power = (voltage / 1000.0) * current * 1000.0; // 转换为mW

      return DeviceData(
        deviceId: deviceId,
        deviceName: deviceName,
        timestamp: DateTime.now(),
        current: currentRaw.toDouble(), // 保持原始值用于显示
        currentUnit: currentUnit,
        voltage: voltage,
        power: power,
        dataType: dataType,
      );
    } catch (e) {
      debugPrint('解析厂商数据失败: $e');
      return null;
    }
  }

  /// 计算功率消耗 (mAh) - 使用梯形积分法提高精度
  static double calculatePowerConsumption(List<DeviceData> dataList) {
    if (dataList.length < 2) return 0.0;

    double totalConsumption = 0.0;

    for (int i = 1; i < dataList.length; i++) {
      DeviceData current = dataList[i];
      DeviceData previous = dataList[i - 1];

      // 计算时间差(小时)
      double timeDiffHours =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
              (1000.0 * 60.0 * 60.0);

      // 转换电流为mA
      double currentInMA =
          _convertToMilliAmps(current.current, current.currentUnit);
      double previousInMA =
          _convertToMilliAmps(previous.current, previous.currentUnit);

      // 使用梯形积分法计算平均电流
      double avgCurrentMA = (currentInMA + previousInMA) / 2.0;

      // 计算消耗量 (mAh)
      totalConsumption += avgCurrentMA * timeDiffHours;
    }

    return totalConsumption;
  }

  /// 转换电流为mA
  static double _convertToMilliAmps(double current, String unit) {
    switch (unit) {
      case 'nA':
        return current / 1000000.0;
      case 'uA':
        return current / 1000.0;
      case 'mA':
        return current;
      case 'A':
        return current * 1000.0;
      default:
        return 0.0;
    }
  }
}

/// 选中设备信息
class SelectedDevice {
  final String deviceId;
  final String deviceName;
  final List<DeviceData> dataHistory;
  var isMonitoring = false.obs;

  SelectedDevice({
    required this.deviceId,
    required this.deviceName,
    List<DeviceData>? dataHistory,
    bool monitoring = false,
  }) : dataHistory = dataHistory ?? [] {
    isMonitoring.value = monitoring;
  }

  /// 添加新数据（带去重功能）
  void addData(DeviceData data) {
    // 检查是否是重复数据
    if (dataHistory.isNotEmpty) {
      final latestData = dataHistory.last;

      // 如果时间间隔小于1秒且数据完全相同，则跳过
      final timeDiff =
          data.timestamp.difference(latestData.timestamp).inMilliseconds;
      if (timeDiff < 1000 && _isDataIdentical(data, latestData)) {
        debugPrint(
            '跳过重复数据: ${data.deviceName} - ${data.current}${data.currentUnit}');
        return;
      }

      // 如果时间间隔小于500毫秒，无论数据是否相同都跳过（防止过于频繁的数据）
      if (timeDiff < 500) {
        debugPrint('跳过过于频繁的数据: ${data.deviceName} - 间隔${timeDiff}ms');
        return;
      }
    }

    dataHistory.add(data);
    // 限制历史数据数量，避免内存过大
    if (dataHistory.length > 86400) {
      dataHistory.removeAt(0);
    }
  }

  /// 检查两个数据是否完全相同
  bool _isDataIdentical(DeviceData data1, DeviceData data2) {
    return data1.current == data2.current &&
        data1.currentUnit == data2.currentUnit &&
        data1.voltage == data2.voltage &&
        data1.power == data2.power;
  }

  /// 获取最新数据
  DeviceData? get latestData =>
      dataHistory.isNotEmpty ? dataHistory.last : null;

  /// 获取功耗
  double get powerConsumption =>
      ManufacturerDataParser.calculatePowerConsumption(dataHistory);

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'isMonitoring': isMonitoring.value ? 1 : 0,
    };
  }

  /// 从Map创建
  factory SelectedDevice.fromMap(Map<String, dynamic> map) {
    return SelectedDevice(
      deviceId: map['deviceId'],
      deviceName: map['deviceName'],
      monitoring: map['isMonitoring'] == 1,
    );
  }
}
