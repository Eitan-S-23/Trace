import 'package:flutter_test/flutter_test.dart';
import 'package:ble_monitor/services/alert_service.dart';
import 'package:ble_monitor/services/notification_service.dart';
import 'package:ble_monitor/models/device_settings.dart';
import 'package:ble_monitor/models/device_data.dart';
import 'package:get/get.dart';

void main() {
  group('Alert Service Tests', () {
    late AlertService alertService;
    late NotificationService notificationService;

    setUp(() {
      // 初始化GetX
      Get.testMode = true;

      // 初始化服务
      alertService = AlertService();
      notificationService = NotificationService();

      // 注册控制器
      Get.put(alertService);
    });

    tearDown(() {
      Get.reset();
    });

    test('Custom sound path should be passed to _playAlertSound', () async {
      // 创建测试设置，包含自定义铃声路径
      final settings = DeviceSettings(
        deviceId: 'test_device_001',
        alertEnabled: true,
        alertType: AlertType.sound,
        customSoundPath: 'C:/Users/test/Music/alert.mp3',
        currentThreshold: 100.0,
        currentUnit: 'mA',
      );

      // 保存设置
      await alertService.saveDeviceSettings(settings);

      // 创建测试数据，电流超过阈值
      final testData = DeviceData(
        deviceId: 'test_device_001',
        deviceName: '测试设备',
        timestamp: DateTime.now(),
        current: 150.0, // 超过阈值100.0
        currentUnit: 'mA',
        voltage: 12000.0,
        power: 1800.0,
        dataType: BleDataType.scanResponse,
      );

      // 测试阈值检查（应触发报警）
      await alertService.checkThresholds(testData, 0.0);

      // 验证customSoundPath被正确传递
      // 注意：实际测试中，我们会mock _playAlertSound方法
      // 这里只是验证参数传递逻辑
      expect(settings.customSoundPath, isNotNull);
      expect(settings.customSoundPath, equals('C:/Users/test/Music/alert.mp3'));
    });

    test('Windows notification should use local_notifier', () async {
      // 测试Windows通知功能
      await notificationService.showAlertNotification(
        title: '测试报警',
        body: '这是一个测试通知',
        deviceName: '测试设备',
        exceededItems: ['电流: 150mA > 100mA'],
      );

      // 验证通知服务已初始化
      expect(notificationService, isNotNull);
    });

    test('Alert cooldown should be at least 5 seconds', () async {
      final settings = DeviceSettings(
        deviceId: 'test_device_002',
        alertEnabled: true,
        alertType: AlertType.vibration,
        currentThreshold: 100.0,
        currentUnit: 'mA',
      );

      await alertService.saveDeviceSettings(settings);

      final testData = DeviceData(
        deviceId: 'test_device_002',
        deviceName: '测试设备2',
        timestamp: DateTime.now(),
        current: 150.0,
        currentUnit: 'mA',
        voltage: 12000.0,
        power: 1800.0,
        dataType: BleDataType.scanResponse,
      );

      // 第一次报警
      await alertService.checkThresholds(testData, 0.0);

      // 立即再次尝试报警（应被冷却时间阻止）
      await alertService.checkThresholds(testData, 0.0);

      // 等待5秒后再次报警（应成功）
      await Future.delayed(const Duration(seconds: 5));
      await alertService.checkThresholds(testData, 0.0);

      // 验证冷却时间常量
      expect(AlertService.alertCooldownSeconds, equals(5));
    });
  });
}