import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// OTA升级服务
/// 负责MQTT通信、固件下载和BLE传输
class OtaService extends GetxController {
  static OtaService get to => Get.find();

  // MQTT客户端
  MqttServerClient? _mqttClient;
  final String _mqttServer = 'broker.hivemq.com'; // 使用公共MQTT服务器进行测试
  // MQTT端口号
  // final int _mqttPort = 1883;
  final String _clientId =
      'flutter_ota_client_${DateTime.now().millisecondsSinceEpoch}';

  // MQTT消息监听
  StreamSubscription? _mqttSubscription;
  StreamSubscription<List<int>>? _otaNotificationSubscription;

  // HTTP客户端用于固件下载
  final Dio _dio = Dio();

  // 升级状态
  var _isConnectedToMqtt = false.obs;
  var _upgradeProgress = 0.0.obs;
  var _upgradeStatus = ''.obs;
  var _isUpgrading = false.obs;

  // 固件信息
  String? _latestFirmwareVersion;
  String? _firmwareDescription;
  String? _firmwareDownloadUrl;
  File? _firmwareFile;

  // BLE连接相关
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _otaCharacteristic;

  bool get isConnectedToMqtt => _isConnectedToMqtt.value;
  double get upgradeProgress => _upgradeProgress.value;
  String get upgradeStatus => _upgradeStatus.value;
  bool get isUpgrading => _isUpgrading.value;

  @override
  void onInit() {
    super.onInit();
    _initializeMqtt();
  }

  @override
  void onClose() {
    _mqttSubscription?.cancel();
    _otaNotificationSubscription?.cancel();
    _mqttClient?.disconnect();
    _dio.close();
    super.onClose();
  }

  /// 初始化MQTT连接
  Future<void> _initializeMqtt() async {
    try {
      _mqttClient = MqttServerClient(_mqttServer, _clientId);
      _mqttClient!.logging(on: false);
      _mqttClient!.keepAlivePeriod = 20;
      _mqttClient!.onConnected = _onMqttConnected;
      _mqttClient!.onDisconnected = _onMqttDisconnected;
      _mqttClient!.onSubscribed = _onMqttSubscribed;

      final connMessage =
          MqttConnectMessage().startClean().withWillQos(MqttQos.atLeastOnce);
      _mqttClient!.connectionMessage = connMessage;

      await _mqttClient!.connect();
    } catch (e) {
      debugPrint('MQTT连接失败: $e');
      _upgradeStatus.value = 'MQTT连接失败';
    }
  }

  void _onMqttConnected() {
    _isConnectedToMqtt.value = true;
    _upgradeStatus.value = 'MQTT已连接';
    debugPrint('MQTT连接成功');

    // 订阅固件升级响应主题
    _mqttClient!.subscribe('firmware/response/$_clientId', MqttQos.atLeastOnce);

    // 设置消息监听
    _mqttSubscription = _mqttClient!.updates!
        .listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      _handleMqttMessage(messages);
    });
  }

  void _onMqttDisconnected() {
    _isConnectedToMqtt.value = false;
    _upgradeStatus.value = 'MQTT连接断开';
    debugPrint('MQTT连接断开');
  }

  void _onMqttSubscribed(String topic) {
    debugPrint('订阅主题成功: $topic');
  }

  // 处理MQTT消息
  Completer<Map<String, dynamic>?>? _mqttResponseCompleter;

  void _handleMqttMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      if (topic == 'firmware/response/$_clientId') {
        final payload = MqttPublishPayload.bytesToStringAsString(
          (message.payload as MqttPublishMessage).payload.message,
        );

        try {
          final response = jsonDecode(payload) as Map<String, dynamic>;
          if (_mqttResponseCompleter != null &&
              !_mqttResponseCompleter!.isCompleted) {
            _mqttResponseCompleter!.complete(response);
          }
        } catch (e) {
          debugPrint('解析MQTT响应失败: $e');
          if (_mqttResponseCompleter != null &&
              !_mqttResponseCompleter!.isCompleted) {
            _mqttResponseCompleter!.complete(null);
          }
        }
        break;
      }
    }
  }

  /// 检查固件更新
  Future<Map<String, dynamic>?> checkFirmwareUpdate(
      String deviceModel, String currentVersion) async {
    if (!_isConnectedToMqtt.value) {
      Get.snackbar('错误', 'MQTT未连接，无法检查更新');
      return null;
    }

    try {
      _upgradeStatus.value = '检查更新中...';

      // 构建检查更新请求
      final request = {
        'device_model': deviceModel,
        'current_version': currentVersion,
        'client_id': _clientId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 发送MQTT消息
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(request));
      _mqttClient!.publishMessage(
        'firmware/check',
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      // 模拟等待服务器响应（在实际项目中这里会等待真实的MQTT响应）
      await Future.delayed(const Duration(seconds: 2)); // 模拟网络延迟
      final response = _simulateServerResponse(deviceModel, currentVersion);

      if (response['status'] == 'none') {
        _upgradeStatus.value = '已是最新版本';
        Get.snackbar('提示', '固件已是最新版本',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green.shade700,
            snackPosition: SnackPosition.TOP);
        return null;
      }

      // 解析固件信息
      _latestFirmwareVersion = response['version'];
      _firmwareDescription = response['description'];
      _firmwareDownloadUrl = response['download_url'];

      _upgradeStatus.value = '发现新版本: $_latestFirmwareVersion';

      return {
        'version': _latestFirmwareVersion,
        'description': _firmwareDescription,
        'download_url': _firmwareDownloadUrl,
        'file_size': response['file_size'],
      };
    } catch (e) {
      _upgradeStatus.value = '检查更新失败: $e';
      Get.snackbar('错误', '检查更新失败: $e');
      return null;
    }
  }

  // 等待MQTT响应的方法（当前使用模拟响应，实际项目中会用到）
  // Future<Map<String, dynamic>?> _waitForMqttResponse(
  //     {int timeoutSeconds = 10}) async {
  //   // 创建新的Completer用于这次请求
  //   _mqttResponseCompleter = Completer<Map<String, dynamic>?>();

  //   try {
  //     final response = await _mqttResponseCompleter!.future.timeout(
  //       Duration(seconds: timeoutSeconds),
  //       onTimeout: () => null,
  //     );
  //     return response;
  //   } catch (e) {
  //     debugPrint('等待MQTT响应超时: $e');
  //     return null;
  //   } finally {
  //     _mqttResponseCompleter = null;
  //   }
  // }

  /// 模拟服务器响应（实际项目中应该从真实服务器获取）
  Map<String, dynamic> _simulateServerResponse(
      String deviceModel, String currentVersion) {
    // 模拟不同的响应情况
    if (currentVersion == '2.1.0') {
      return {'status': 'none'};
    } else {
      return {
        'status': 'available',
        'version': '2.1.0',
        'description': '新增功能：\n• 优化蓝牙连接稳定性\n• 新增省电模式\n• 修复已知问题\n• 提升整体性能',
        'download_url':
            'https://jsonplaceholder.typicode.com/posts/1', // 使用一个小的测试文件
        'file_size': 1024, // 1KB for testing
      };
    }
  }

  /// 下载固件
  Future<bool> downloadFirmware() async {
    if (_firmwareDownloadUrl == null) {
      Get.snackbar('错误', '固件下载地址无效');
      return false;
    }

    try {
      _upgradeStatus.value = '下载固件中...';
      _upgradeProgress.value = 0.0;

      final directory = await getApplicationDocumentsDirectory();
      final firmwarePath =
          '${directory.path}/firmware_$_latestFirmwareVersion.bin';

      await _dio.download(
        _firmwareDownloadUrl!,
        firmwarePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _upgradeProgress.value = received / total;
            _upgradeStatus.value =
                '下载中: ${(received / total * 100).toStringAsFixed(1)}%';
          }
        },
      );

      _firmwareFile = File(firmwarePath);
      _upgradeStatus.value = '固件下载完成';
      _upgradeProgress.value = 1.0;

      return true;
    } catch (e) {
      _upgradeStatus.value = '固件下载失败: $e';
      Get.snackbar('错误', '固件下载失败: $e');
      return false;
    }
  }

  /// 开始OTA升级
  Future<bool> startOtaUpgrade(BluetoothDevice device) async {
    if (_firmwareFile == null || !_firmwareFile!.existsSync()) {
      Get.snackbar('错误', '固件文件不存在，请先下载固件');
      return false;
    }

    try {
      _isUpgrading.value = true;
      _connectedDevice = device;
      _upgradeProgress.value = 0.0;
      _upgradeStatus.value = '连接设备中...';
      await _stopOtaNotificationListening();

      // 连接BLE设备
      if (!device.isConnected) {
        await device.connect();
      }

      // 发现服务
      final services = await device.discoverServices();
      BluetoothService? otaService;

      for (var service in services) {
        if (service.uuid.toString().contains('ota') ||
            service.uuid.toString().contains('dfu')) {
          otaService = service;
          break;
        }
      }

      if (otaService == null) {
        throw Exception('设备不支持OTA升级');
      }

      // 查找OTA特征值
      for (var characteristic in otaService.characteristics) {
        if (characteristic.properties.write) {
          _otaCharacteristic = characteristic;
          break;
        }
      }

      if (_otaCharacteristic == null) {
        throw Exception('未找到OTA写入特征值');
      }

      // 发送固件版本信息给设备
      await _sendFirmwareVersion();

      // 等待设备请求固件数据
      await _handleFirmwareTransfer();

      _upgradeStatus.value = 'OTA升级完成';
      _upgradeProgress.value = 1.0;
      _isUpgrading.value = false;

      Get.snackbar('成功', 'OTA升级完成');
      return true;
    } catch (e) {
      await _stopOtaNotificationListening();
      _upgradeStatus.value = 'OTA升级失败: $e';
      _isUpgrading.value = false;
      Get.snackbar('错误', 'OTA升级失败: $e');
      return false;
    }
  }

  /// 发送固件版本信息给设备
  Future<void> _sendFirmwareVersion() async {
    if (_otaCharacteristic == null || _latestFirmwareVersion == null) return;

    _upgradeStatus.value = '发送固件版本信息...';

    final versionData = Uint8List.fromList(_latestFirmwareVersion!.codeUnits);
    await _otaCharacteristic!.write(versionData);

    debugPrint('已发送固件版本: $_latestFirmwareVersion');
  }

  /// 处理固件传输
  Future<void> _handleFirmwareTransfer() async {
    if (_firmwareFile == null || _otaCharacteristic == null) return;

    _upgradeStatus.value = '传输固件数据...';

    final firmwareData = await _firmwareFile!.readAsBytes();
    final totalSize = firmwareData.length;
    if (totalSize == 0) {
      throw Exception('固件文件为空');
    }
    // const chunkSize = 20; // BLE每次传输的字节数（当前未使用，但在实际BLE传输中会用到）

    try {
      // 监听设备的请求
      await _otaCharacteristic!.setNotifyValue(true);

      await _otaNotificationSubscription?.cancel();
      _otaNotificationSubscription =
          _otaCharacteristic!.onValueReceived.listen((value) async {
        try {
          if (!_isUpgrading.value || value.length < 12) return;

          // 解析设备请求: 版本号 + 起始字节 + 结束字节
          final startByte = _bytesToInt(value.sublist(4, 8));
          final requestedEndByte = _bytesToInt(value.sublist(8, 12));

          if (startByte < 0 ||
              requestedEndByte < startByte ||
              startByte >= totalSize) {
            debugPrint('忽略无效固件数据请求: $startByte - $requestedEndByte');
            return;
          }

          final endByte =
              requestedEndByte >= totalSize ? totalSize - 1 : requestedEndByte;
          debugPrint('设备请求固件数据: $startByte - $endByte');

          await _sendFirmwareChunk(firmwareData, startByte, endByte);

          final progress = (endByte + 1) / totalSize;
          _upgradeProgress.value = progress > 1.0 ? 1.0 : progress;
          _upgradeStatus.value =
              '传输中: ${(_upgradeProgress.value * 100).toStringAsFixed(1)}%';
        } catch (e) {
          _isUpgrading.value = false;
          _upgradeStatus.value = '固件传输失败: $e';
          debugPrint('固件传输失败: $e');
        }
      }, onError: (Object error, StackTrace stackTrace) {
        _isUpgrading.value = false;
        _upgradeStatus.value = '固件传输监听失败: $error';
        debugPrint('固件传输监听失败: $error');
      }, cancelOnError: false);

      // 等待传输完成
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      while (_isUpgrading.value && _upgradeProgress.value < 1.0) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('固件传输超时');
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!_isUpgrading.value && _upgradeProgress.value < 1.0) {
        throw Exception('OTA升级已取消');
      }
    } finally {
      await _stopOtaNotificationListening();
    }
  }

  Future<void> _stopOtaNotificationListening() async {
    await _otaNotificationSubscription?.cancel();
    _otaNotificationSubscription = null;

    final characteristic = _otaCharacteristic;
    if (characteristic == null) return;

    try {
      await characteristic.setNotifyValue(false);
    } catch (e) {
      debugPrint('关闭OTA通知失败: $e');
    }
  }

  /// 发送固件数据块
  Future<void> _sendFirmwareChunk(
      Uint8List firmwareData, int startByte, int endByte) async {
    if (_otaCharacteristic == null) return;

    final chunkData = firmwareData.sublist(startByte, endByte + 1);
    const maxChunkSize = 20;

    for (int i = 0; i < chunkData.length; i += maxChunkSize) {
      final end = (i + maxChunkSize < chunkData.length)
          ? i + maxChunkSize
          : chunkData.length;
      final chunk = chunkData.sublist(i, end);

      await _otaCharacteristic!.write(chunk);
      await Future.delayed(const Duration(milliseconds: 10)); // 避免发送过快
    }

    debugPrint('发送固件数据块: $startByte - $endByte (${chunkData.length} bytes)');
  }

  /// 字节数组转整数
  int _bytesToInt(List<int> bytes) {
    int result = 0;
    for (int i = 0; i < bytes.length; i++) {
      result |= (bytes[i] << (i * 8));
    }
    return result;
  }

  /// 取消升级
  Future<void> cancelUpgrade() async {
    _isUpgrading.value = false;
    _upgradeStatus.value = '升级已取消';
    await _stopOtaNotificationListening();

    if (_connectedDevice != null && _connectedDevice!.isConnected) {
      await _connectedDevice!.disconnect();
    }

    _connectedDevice = null;
    _otaCharacteristic = null;
  }

  /// 清理固件文件
  Future<void> cleanupFirmware() async {
    if (_firmwareFile != null && _firmwareFile!.existsSync()) {
      await _firmwareFile!.delete();
      _firmwareFile = null;
    }
  }

  /// 获取升级历史记录
  List<Map<String, dynamic>> getUpgradeHistory() {
    // 这里应该从数据库或持久化存储中获取
    return [
      {
        'device': '智能码表 Pro',
        'version': '2.0.1',
        'date': DateTime.now().subtract(const Duration(days: 7)),
        'status': 'success',
      },
      {
        'device': '骑行码表 X1',
        'version': '1.9.3',
        'date': DateTime.now().subtract(const Duration(days: 15)),
        'status': 'success',
      },
    ];
  }
}
