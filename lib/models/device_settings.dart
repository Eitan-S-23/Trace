/// 报警类型
enum AlertType {
  vibration, // 震动
  sound, // 铃声
  both, // 震动+铃声
}

/// 设备阈值设置模型
class DeviceSettings {
  final String deviceId;
  final double currentThreshold;
  final double voltageThreshold;
  final double powerThreshold;
  final double powerConsumptionThreshold;
  final String currentUnit;
  final String voltageUnit;
  final String powerUnit;
  final String powerConsumptionUnit;
  final bool alertEnabled;
  final AlertType alertType;

  DeviceSettings({
    required this.deviceId,
    this.currentThreshold = 1000.0,
    this.voltageThreshold = 24.0,
    this.powerThreshold = 100.0,
    this.powerConsumptionThreshold = 1000.0,
    this.currentUnit = 'mA',
    this.voltageUnit = 'V',
    this.powerUnit = 'W',
    this.powerConsumptionUnit = 'mAh',
    this.alertEnabled = true,
    this.alertType = AlertType.vibration,
  });

  /// 转换为Map用于数据库存储
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'currentThreshold': currentThreshold,
      'voltageThreshold': voltageThreshold,
      'powerThreshold': powerThreshold,
      'powerConsumptionThreshold': powerConsumptionThreshold,
      'currentUnit': currentUnit,
      'voltageUnit': voltageUnit,
      'powerUnit': powerUnit,
      'powerConsumptionUnit': powerConsumptionUnit,
      'alertEnabled': alertEnabled ? 1 : 0,
      'alertType': alertType.index,
    };
  }

  /// 从Map创建对象
  factory DeviceSettings.fromMap(Map<String, dynamic> map) {
    return DeviceSettings(
      deviceId: map['deviceId'],
      currentThreshold: map['currentThreshold']?.toDouble() ?? 1000.0,
      voltageThreshold: map['voltageThreshold']?.toDouble() ?? 24.0,
      powerThreshold: map['powerThreshold']?.toDouble() ?? 100.0,
      powerConsumptionThreshold:
          map['powerConsumptionThreshold']?.toDouble() ?? 1000.0,
      currentUnit: map['currentUnit'] ?? 'mA',
      voltageUnit: map['voltageUnit'] ?? 'V',
      powerUnit: map['powerUnit'] ?? 'W',
      powerConsumptionUnit: map['powerConsumptionUnit'] ?? 'mAh',
      alertEnabled: (map['alertEnabled'] ?? 1) == 1,
      alertType: AlertType.values[map['alertType'] ?? 0],
    );
  }

  /// 复制并修改部分属性
  DeviceSettings copyWith({
    String? deviceId,
    double? currentThreshold,
    double? voltageThreshold,
    double? powerThreshold,
    double? powerConsumptionThreshold,
    String? currentUnit,
    String? voltageUnit,
    String? powerUnit,
    String? powerConsumptionUnit,
    bool? alertEnabled,
    AlertType? alertType,
  }) {
    return DeviceSettings(
      deviceId: deviceId ?? this.deviceId,
      currentThreshold: currentThreshold ?? this.currentThreshold,
      voltageThreshold: voltageThreshold ?? this.voltageThreshold,
      powerThreshold: powerThreshold ?? this.powerThreshold,
      powerConsumptionThreshold:
          powerConsumptionThreshold ?? this.powerConsumptionThreshold,
      currentUnit: currentUnit ?? this.currentUnit,
      voltageUnit: voltageUnit ?? this.voltageUnit,
      powerUnit: powerUnit ?? this.powerUnit,
      powerConsumptionUnit: powerConsumptionUnit ?? this.powerConsumptionUnit,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      alertType: alertType ?? this.alertType,
    );
  }

  @override
  String toString() {
    return 'DeviceSettings{deviceId: $deviceId, currentThreshold: $currentThreshold$currentUnit, voltageThreshold: $voltageThreshold$voltageUnit, powerThreshold: $powerThreshold$powerUnit, alertEnabled: $alertEnabled}';
  }
}
