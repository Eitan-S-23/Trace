import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
      _flutterLocalNotificationsPlugin;

  // 震动模式常量
  static List<int> get vibrationPattern => [0, 300, 200, 400, 200, 500];

  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: LinuxInitializationSettings(defaultActionName: 'Open notification'),
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 处理通知点击事件
        _handleNotificationTap(response);
      },
    );

    // 请求权限
    await _requestPermissions();

    _isInitialized = true;
  }

  /// 请求通知权限
  Future<void> _requestPermissions() async {
    if (kIsWeb) return; // Web平台不需要特殊权限处理

    // Android 13+ 需要特殊的权限处理
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// 显示报警通知
  Future<void> showAlertNotification({
    required String title,
    required String body,
    String? deviceName,
    List<String>? exceededItems,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'alert_channel',
      '设备报警',
      channelDescription: '功率计设备异常报警通知',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
      fullScreenIntent: true, // 全屏显示
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    // 构建通知内容
    String notificationBody = body;
    if (exceededItems != null && exceededItems.isNotEmpty) {
      notificationBody += '\n\n异常项目:';
      for (var item in exceededItems) {
        notificationBody += '\n• $item';
      }
    }

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // 唯一ID
      title,
      notificationBody,
      notificationDetails,
    );
  }

  /// 显示设备异常通知（后台专用）
  Future<void> showDeviceAlertNotification({
    required String deviceName,
    required List<String> exceededItems,
  }) async {
    final title = '⚠️ 设备异常报警';
    final body = '设备 $deviceName 检测到异常用电情况';

    await showAlertNotification(
      title: title,
      body: body,
      deviceName: deviceName,
      exceededItems: exceededItems,
    );
  }

  /// 处理通知点击事件
  void _handleNotificationTap(NotificationResponse response) {
    // 可以在这里添加点击通知后的逻辑，比如跳转到特定页面
    debugPrint('通知被点击: ${response.payload}');
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 取消特定通知
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}
