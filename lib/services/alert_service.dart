import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/device_settings.dart';
import '../models/device_data.dart';
import 'database_service.dart';

class AlertService extends GetxController {
  static AlertService get to => Get.find();

  final DatabaseService _dbService = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 存储设备设置的缓存
  final Map<String, DeviceSettings> _deviceSettingsCache = {};

  // 存储上次报警时间，避免频繁报警
  final Map<String, DateTime> _lastAlertTime = {};

  // 报警冷却时间（秒）- 减少冷却时间让报警更及时
  static const int alertCooldownSeconds = 5;

  @override
  void onInit() {
    super.onInit();
    _loadAllDeviceSettings();
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }

  /// 加载所有设备设置到缓存
  Future<void> _loadAllDeviceSettings() async {
    try {
      final settingsList = await _dbService.getAllDeviceSettings();
      for (var settings in settingsList) {
        _deviceSettingsCache[settings.deviceId] = settings;
      }
    } catch (e) {
      debugPrint('加载设备设置失败: $e');
    }
  }

  /// 获取设备设置（优先从缓存获取）
  Future<DeviceSettings> getDeviceSettings(String deviceId) async {
    if (_deviceSettingsCache.containsKey(deviceId)) {
      return _deviceSettingsCache[deviceId]!;
    }

    var settings = await _dbService.getDeviceSettings(deviceId);
    if (settings == null) {
      // 如果没有设置，创建默认设置
      settings = DeviceSettings(deviceId: deviceId);
      await _dbService.saveDeviceSettings(settings);
    }

    _deviceSettingsCache[deviceId] = settings;
    return settings;
  }

  /// 保存设备设置
  Future<void> saveDeviceSettings(DeviceSettings settings) async {
    try {
      await _dbService.saveDeviceSettings(settings);
      _deviceSettingsCache[settings.deviceId] = settings;
    } catch (e) {
      debugPrint('保存设备设置失败: $e');
      rethrow;
    }
  }

  /// 检查数据是否超出阈值并触发报警
  Future<void> checkThresholds(DeviceData data, double powerConsumption) async {
    try {
      final settings = await getDeviceSettings(data.deviceId);

      if (!settings.alertEnabled) return;

      // 检查冷却时间
      final lastAlert = _lastAlertTime[data.deviceId];
      if (lastAlert != null) {
        final timeSinceLastAlert =
            DateTime.now().difference(lastAlert).inSeconds;
        if (timeSinceLastAlert < alertCooldownSeconds) {
          return; // 还在冷却期内
        }
      }

      List<String> exceededThresholds = [];

      // 转换电流到统一单位进行比较
      final currentInTargetUnit =
          _convertCurrent(data.current, data.currentUnit, settings.currentUnit);

      // 检查电流阈值 - 确保阈值大于0才检查
      if (settings.currentThreshold > 0 &&
          currentInTargetUnit > settings.currentThreshold) {
        exceededThresholds.add(
            '电流: ${currentInTargetUnit.toStringAsFixed(2)}${settings.currentUnit} > ${settings.currentThreshold}${settings.currentUnit}');
        debugPrint(
            '电流超出阈值: ${currentInTargetUnit.toStringAsFixed(2)} > ${settings.currentThreshold}');
      }

      // 转换电压到统一单位进行比较
      final voltageInTargetUnit =
          _convertVoltage(data.voltage, 'mV', settings.voltageUnit);

      // 检查电压阈值
      if (settings.voltageThreshold > 0 &&
          voltageInTargetUnit > settings.voltageThreshold) {
        exceededThresholds.add(
            '电压: ${voltageInTargetUnit.toStringAsFixed(2)}${settings.voltageUnit} > ${settings.voltageThreshold}${settings.voltageUnit}');
        debugPrint(
            '电压超出阈值: ${voltageInTargetUnit.toStringAsFixed(2)} > ${settings.voltageThreshold}');
      }

      // 转换功率到统一单位进行比较
      final powerInTargetUnit =
          _convertPower(data.power, 'mW', settings.powerUnit);

      // 检查功率阈值
      if (settings.powerThreshold > 0 &&
          powerInTargetUnit > settings.powerThreshold) {
        exceededThresholds.add(
            '功率: ${powerInTargetUnit.toStringAsFixed(2)}${settings.powerUnit} > ${settings.powerThreshold}${settings.powerUnit}');
        debugPrint(
            '功率超出阈值: ${powerInTargetUnit.toStringAsFixed(2)} > ${settings.powerThreshold}');
      }

      // 转换耗电量到统一单位进行比较
      final powerConsumptionInTargetUnit = _convertPowerConsumption(
          powerConsumption, 'mAh', settings.powerConsumptionUnit);

      // 检查耗电量阈值
      if (settings.powerConsumptionThreshold > 0 &&
          powerConsumptionInTargetUnit > settings.powerConsumptionThreshold) {
        exceededThresholds.add(
            '耗电量: ${powerConsumptionInTargetUnit.toStringAsFixed(2)}${settings.powerConsumptionUnit} > ${settings.powerConsumptionThreshold}${settings.powerConsumptionUnit}');
        debugPrint(
            '耗电量超出阈值: ${powerConsumptionInTargetUnit.toStringAsFixed(2)} > ${settings.powerConsumptionThreshold}');
      }

      // 如果有超出阈值的项目，触发报警
      if (exceededThresholds.isNotEmpty) {
        await _triggerAlert(
            data.deviceName, exceededThresholds, settings.alertType);
        _lastAlertTime[data.deviceId] = DateTime.now();
      }
    } catch (e) {
      debugPrint('检查阈值时出错: $e');
    }
  }

  /// 触发报警
  Future<void> _triggerAlert(String deviceName, List<String> exceededItems,
      AlertType alertType) async {
    final message = '设备 $deviceName 异常:\n${exceededItems.join('\n')}';

    // 显示应用内通知
    Get.snackbar(
      '⚠️ 异常用电量报警',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFFF6B6B),
      colorText: Colors.white,
      duration: const Duration(seconds: 8), // 延长显示时间
      isDismissible: true,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      showProgressIndicator: true,
      progressIndicatorBackgroundColor: Colors.white24,
      progressIndicatorValueColor:
          const AlwaysStoppedAnimation<Color>(Colors.white),
    );

    // 显示系统对话框（更醒目）
    _showAlertDialog(deviceName, exceededItems);

    debugPrint('报警已触发: $message');

    // 根据设置触发震动和/或声音
    switch (alertType) {
      case AlertType.vibration:
        await _triggerVibration();
        break;
      case AlertType.sound:
        await _playAlertSound();
        break;
      case AlertType.both:
        await Future.wait([
          _triggerVibration(),
          _playAlertSound(),
        ]);
        break;
    }
  }

  /// 触发震动
  Future<void> _triggerVibration() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        // 更强烈的震动模式：连续三次震动
        await Vibration.vibrate(
            pattern: [0, 300, 200, 400, 200, 500, 200, 300]);
        debugPrint('报警震动已触发');
      } else {
        debugPrint('设备不支持震动');
      }
    } catch (e) {
      debugPrint('震动失败: $e');
    }
  }

  /// 播放报警声音
  Future<void> _playAlertSound() async {
    try {
      // 播放多次系统警告声音以增强警示效果
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
      }
      debugPrint('报警声音已播放');
    } catch (e) {
      debugPrint('播放声音失败: $e');
      // 如果系统声音失败，尝试使用audioplayers
      try {
        await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
      } catch (e2) {
        debugPrint('使用audioplayers播放失败: $e2');
      }
    }
  }

  /// 显示报警对话框
  void _showAlertDialog(String deviceName, List<String> exceededItems) {
    if (Get.context != null) {
      Get.dialog(
        AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
          title: const Text(
            '⚠️ 设备异常报警',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设备：$deviceName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '异常项目：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...exceededItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $item',
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('确定'),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                // 可以跳转到设备详情页面
                Get.toNamed('/device-detail');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('查看详情'),
            ),
          ],
        ),
        barrierDismissible: false, // 不允许点击外部关闭
      );
    }
  }

  /// 电流单位转换
  double _convertCurrent(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // 先转换为基准单位 (A)
    double valueInAmps;
    switch (fromUnit) {
      case 'nA':
        valueInAmps = value * 1e-9;
        break;
      case 'uA':
        valueInAmps = value * 1e-6;
        break;
      case 'mA':
        valueInAmps = value * 1e-3;
        break;
      case 'A':
        valueInAmps = value;
        break;
      default:
        return value; // 未知单位，不转换
    }

    // 转换为目标单位
    switch (toUnit) {
      case 'nA':
        return valueInAmps / 1e-9;
      case 'uA':
        return valueInAmps / 1e-6;
      case 'mA':
        return valueInAmps / 1e-3;
      case 'A':
        return valueInAmps;
      default:
        return value; // 未知单位，不转换
    }
  }

  /// 电压单位转换
  double _convertVoltage(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // 先转换为基准单位 (V)
    double valueInVolts;
    switch (fromUnit) {
      case 'mV':
        valueInVolts = value / 1000.0;
        break;
      case 'V':
        valueInVolts = value;
        break;
      default:
        return value; // 未知单位，不转换
    }

    // 转换为目标单位
    switch (toUnit) {
      case 'mV':
        return valueInVolts * 1000.0;
      case 'V':
        return valueInVolts;
      default:
        return value; // 未知单位，不转换
    }
  }

  /// 功率单位转换
  double _convertPower(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // 先转换为基准单位 (W)
    double valueInWatts;
    switch (fromUnit) {
      case 'mW':
        valueInWatts = value / 1000.0;
        break;
      case 'W':
        valueInWatts = value;
        break;
      default:
        return value; // 未知单位，不转换
    }

    // 转换为目标单位
    switch (toUnit) {
      case 'mW':
        return valueInWatts * 1000.0;
      case 'W':
        return valueInWatts;
      default:
        return value; // 未知单位，不转换
    }
  }

  /// 耗电量单位转换
  double _convertPowerConsumption(
      double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    // 先转换为基准单位 (Ah)
    double valueInAh;
    switch (fromUnit) {
      case 'mAh':
        valueInAh = value / 1000.0;
        break;
      case 'Ah':
        valueInAh = value;
        break;
      default:
        return value; // 未知单位，不转换
    }

    // 转换为目标单位
    switch (toUnit) {
      case 'mAh':
        return valueInAh * 1000.0;
      case 'Ah':
        return valueInAh;
      default:
        return value; // 未知单位，不转换
    }
  }
}
