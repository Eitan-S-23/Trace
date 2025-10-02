import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

// Windows蓝牙支持
// import 'package:win_ble/win_ble.dart' if (dart.library.js) 'dart:html';

/// 跨平台蓝牙服务
/// 为不同平台提供统一的蓝牙接口
class BluetoothService extends GetxController {
  static BluetoothService get to => Get.find();

  // 蓝牙适配器状态
  var adapterState = BluetoothAdapterState.unknown.obs;

  // 扫描状态
  var isScanning = false.obs;

  // 发现的设备列表
  var discoveredDevices = <BluetoothDevice>[].obs;

  // 连接的设备列表
  var connectedDevices = <BluetoothDevice>[].obs;

  // 设备扫描结果数据
  var scanResults = <ScanResult>[].obs;

  // 平台特定的控制器
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterSubscription;

  // Windows特定的WinBle实例
  // dynamic _winBle; // 目前未使用

  @override
  void onInit() {
    super.onInit();
    initBluetooth();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();
    super.onClose();
  }

  /// 初始化蓝牙
  Future<void> initBluetooth() async {
    try {
      if (Platform.isWindows) {
        await _initWindowsBluetooth();
      } else {
        await _initMobileBluetooth();
      }
    } catch (e) {
      debugPrint('初始化蓝牙失败: $e');
      Get.snackbar('错误', '初始化蓝牙失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 初始化Windows蓝牙
  Future<void> _initWindowsBluetooth() async {
    try {
      // Windows平台暂时使用模拟状态
      adapterState.value = BluetoothAdapterState.on;
      debugPrint('Windows蓝牙状态: 模拟启用');
      Get.snackbar('提示', 'Windows平台蓝牙功能正在开发中',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('Windows蓝牙初始化失败: $e');
      adapterState.value = BluetoothAdapterState.unavailable;
    }
  }

  /// 初始化移动端蓝牙
  Future<void> _initMobileBluetooth() async {
    // 监听蓝牙适配器状态
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      adapterState.value = state;
      if (state != BluetoothAdapterState.on) {
        discoveredDevices.clear();
        scanResults.clear();
        isScanning.value = false;
      }
    });

    // 获取当前状态
    adapterState.value = await FlutterBluePlus.adapterState.first;

    // 获取已连接的设备
    await updateConnectedDevices();
  }

  /// 开始扫描设备
  Future<void> startScan({Duration? timeout}) async {
    if (isScanning.value) {
      debugPrint('扫描已在进行中');
      return;
    }

    try {
      if (Platform.isWindows) {
        await _startWindowsScan(timeout);
      } else {
        await _startMobileScan(timeout);
      }
    } catch (e) {
      debugPrint('开始扫描失败: $e');
      Get.snackbar('错误', '开始扫描失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Windows蓝牙扫描
  Future<void> _startWindowsScan(Duration? timeout) async {
    isScanning.value = true;
    discoveredDevices.clear();
    scanResults.clear();

    try {
      debugPrint('Windows蓝牙扫描已启动');

      // 尝试使用FlutterBluePlus进行扫描（某些Windows环境可能支持）
      try {
        if (timeout != null) {
          await FlutterBluePlus.startScan(timeout: timeout);
        } else {
          await FlutterBluePlus.startScan();
        }

        // 监听扫描结果
        _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          scanResults.value = results;

          // 更新设备列表
          Set<String> deviceIds = {};
          List<BluetoothDevice> devices = [];

          for (var result in results) {
            if (!deviceIds.contains(result.device.remoteId.str)) {
              deviceIds.add(result.device.remoteId.str);
              devices.add(result.device);
            }
          }

          discoveredDevices.value = devices;
        });

        debugPrint('Windows蓝牙扫描正常启动');
      } catch (e) {
        // 如果FlutterBluePlus在Windows上不工作，则提供模拟功能
        debugPrint('FlutterBluePlus在Windows上不可用，使用模拟模式: $e');
        Get.snackbar('提示', 'Windows平台蓝牙功能受限，已创建测试设备进行演示',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3));

        // Windows平台暂时不创建模拟设备
        debugPrint('Windows平台蓝牙功能受限，建议使用Android设备');

        // 模拟扫描超时
        if (timeout != null) {
          Timer(timeout, () => stopScan());
        }
      }
    } catch (e) {
      isScanning.value = false;
      throw Exception('Windows蓝牙扫描启动失败: $e');
    }
  }

  /// 创建模拟设备用于Windows测试
  // Future<void> _createSimulatedDevices() async {
  //   await Future.delayed(const Duration(seconds: 2));
  //   try {
  //     debugPrint('Windows平台暂时不创建模拟设备，建议使用真实设备测试');
  //   } catch (e) {
  //     debugPrint('Windows蓝牙初始化失败: $e');
  //   }
  // }

  /// 移动端蓝牙扫描
  Future<void> _startMobileScan(Duration? timeout) async {
    if (adapterState.value != BluetoothAdapterState.on) {
      throw Exception('蓝牙未开启');
    }

    isScanning.value = true;
    discoveredDevices.clear();
    scanResults.clear();

    // 启动扫描（保持持续扫描，不设置超时）
    await FlutterBluePlus.startScan();

    // 监听扫描结果
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      scanResults.value = results;

      // 更新设备列表 - 仅保留名称+地址完全相同的唯一项
      final Map<String, BluetoothDevice> deviceMap = {};
      for (final r in results) {
        final key = '${r.device.platformName}_${r.device.remoteId}';
        deviceMap.putIfAbsent(key, () => r.device);
      }
      discoveredDevices.value = deviceMap.values.toList();
    });
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (!isScanning.value) return;

    try {
      if (Platform.isWindows) {
        // Windows平台模拟停止
        debugPrint('Windows蓝牙扫描已停止（模拟）');
      } else {
        await FlutterBluePlus.stopScan();
      }

      _scanSubscription?.cancel();
      isScanning.value = false;
      debugPrint('蓝牙扫描已停止');
    } catch (e) {
      debugPrint('停止扫描失败: $e');
    }
  }

  /// 连接设备
  Future<void> connectDevice(BluetoothDevice device) async {
    try {
      if (Platform.isWindows) {
        await _connectWindowsDevice(device);
      } else {
        await _connectMobileDevice(device);
      }
    } catch (e) {
      debugPrint('连接设备失败: $e');
      Get.snackbar('错误', '连接设备失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Windows设备连接
  Future<void> _connectWindowsDevice(BluetoothDevice device) async {
    try {
      // Windows平台模拟连接
      debugPrint('Windows设备连接成功（模拟）: ${device.platformName}');
      Get.snackbar('提示', 'Windows平台设备连接功能正在开发中',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      throw Exception('Windows设备连接失败: $e');
    }
  }

  /// 移动端设备连接
  Future<void> _connectMobileDevice(BluetoothDevice device) async {
    await device.connect();
    await updateConnectedDevices();

    debugPrint('移动端设备连接成功: ${device.platformName}');
    Get.snackbar('成功', '设备连接成功', snackPosition: SnackPosition.BOTTOM);
  }

  /// 断开设备连接
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      if (Platform.isWindows) {
        // Windows平台模拟断开
        debugPrint('Windows设备断开连接（模拟）: ${device.platformName}');
      } else {
        await device.disconnect();
      }

      connectedDevices.remove(device);
      debugPrint('设备断开连接: ${device.platformName}');
    } catch (e) {
      debugPrint('断开设备连接失败: $e');
    }
  }

  /// 更新已连接设备列表
  Future<void> updateConnectedDevices() async {
    try {
      if (Platform.isWindows) {
        // Windows暂时使用本地列表
        // 这里可以根据win_ble的API获取已连接设备
      } else {
        connectedDevices.value = FlutterBluePlus.connectedDevices;
      }
    } catch (e) {
      debugPrint('更新已连接设备列表失败: $e');
    }
  }

  /// 获取扫描结果
  ScanResult? getScanResult(BluetoothDevice device) {
    return scanResults.firstWhereOrNull(
      (result) => result.device.remoteId == device.remoteId,
    );
  }

  /// 检查设备是否已连接
  bool isDeviceConnected(BluetoothDevice device) {
    return connectedDevices.any((d) => d.remoteId == device.remoteId);
  }

  /// 启用蓝牙（仅移动端）
  Future<void> turnOnBluetooth() async {
    if (Platform.isWindows) {
      Get.snackbar('提示', '请在系统设置中手动启用蓝牙', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      debugPrint('启用蓝牙失败: $e');
      Get.snackbar('错误', '启用蓝牙失败，请手动开启', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 获取平台信息
  String getPlatformInfo() {
    if (Platform.isWindows) {
      return 'Windows (WinBLE)';
    } else if (Platform.isAndroid) {
      return 'Android (FlutterBluePlus)';
    } else if (Platform.isIOS) {
      return 'iOS (FlutterBluePlus)';
    } else {
      return '未知平台';
    }
  }
}
