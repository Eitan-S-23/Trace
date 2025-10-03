import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

// Windows蓝牙支持 - 条件性导入
import 'package:win_ble/win_ble.dart';

// 抽象蓝牙适配器接口
abstract class BluetoothAdapter {
  Future<void> init();
  Future<void> startScan({Duration? timeout});
  Future<void> stopScan();
  Future<void> connect(String deviceAddress);
  Future<void> disconnect(String deviceAddress);
  Future<List<dynamic>> getConnectedDevices();
  Future<BluetoothAdapterState> getAdapterState();
  Stream<BluetoothAdapterState> get adapterStateChanged;
  Stream<List<dynamic>> get scanResults;
  Stream<String> get connectionStateChanged;

  // WinBle特有的方法
  Future<void> pair(String deviceAddress);
  Future<void> unPair(String deviceAddress);
  Future<bool> canPair(String deviceAddress);
  Future<bool> isPaired(String deviceAddress);
  Future<List<dynamic>> discoverServices(String deviceAddress);
  Future<List<dynamic>> discoverCharacteristics(
      String deviceAddress, String serviceId);
  Future<List<int>> readCharacteristic(
      String deviceAddress, String serviceId, String characteristicId);
  Future<void> writeCharacteristic(String deviceAddress, String serviceId,
      String characteristicId, List<int> data,
      {bool writeWithResponse = false});
  Future<void> subscribeToCharacteristic(
      String deviceAddress, String serviceId, String characteristicId);
  Future<void> unSubscribeFromCharacteristic(
      String deviceAddress, String serviceId, String characteristicId);
}

// FlutterBluePlus适配器（用于移动端）
class FlutterBluePlusAdapter implements BluetoothAdapter {
  @override
  Future<void> init() async {
    // FlutterBluePlus不需要显式初始化
  }

  @override
  Future<void> startScan({Duration? timeout}) async {
    if (timeout != null) {
      await FlutterBluePlus.startScan(timeout: timeout);
    } else {
      await FlutterBluePlus.startScan();
    }
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(String deviceId) async {
    // 这里需要根据deviceId找到对应的设备并连接
    // 暂时简化处理
  }

  @override
  Future<void> disconnect(String deviceId) async {
    // 这里需要根据deviceId找到对应的设备并断开连接
    // 暂时简化处理
  }

  @override
  Future<List<dynamic>> getConnectedDevices() async {
    return FlutterBluePlus.connectedDevices;
  }

  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    return FlutterBluePlus.adapterState.first;
  }

  @override
  Stream<BluetoothAdapterState> get adapterStateChanged =>
      FlutterBluePlus.adapterState;

  @override
  Stream<List<dynamic>> get scanResults =>
      FlutterBluePlus.scanResults.map((results) => results);

  @override
  Stream<String> get connectionStateChanged =>
      const Stream.empty(); // FlutterBluePlus使用不同的机制

  // WinBle特有的方法 - FlutterBluePlus不支持这些功能
  @override
  Future<void> pair(String deviceAddress) async {
    throw UnsupportedError('FlutterBluePlus does not support pairing');
  }

  @override
  Future<void> unPair(String deviceAddress) async {
    throw UnsupportedError('FlutterBluePlus does not support unpairing');
  }

  @override
  Future<bool> canPair(String deviceAddress) async {
    throw UnsupportedError('FlutterBluePlus does not support pairing check');
  }

  @override
  Future<bool> isPaired(String deviceAddress) async {
    throw UnsupportedError('FlutterBluePlus does not support pairing check');
  }

  @override
  Future<List<dynamic>> discoverServices(String deviceAddress) async {
    throw UnsupportedError(
        'FlutterBluePlus service discovery not implemented in adapter');
  }

  @override
  Future<List<dynamic>> discoverCharacteristics(
      String deviceAddress, String serviceId) async {
    throw UnsupportedError(
        'FlutterBluePlus characteristic discovery not implemented in adapter');
  }

  @override
  Future<List<int>> readCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    throw UnsupportedError(
        'FlutterBluePlus characteristic read not implemented in adapter');
  }

  @override
  Future<void> writeCharacteristic(String deviceAddress, String serviceId,
      String characteristicId, List<int> data,
      {bool writeWithResponse = false}) async {
    throw UnsupportedError(
        'FlutterBluePlus characteristic write not implemented in adapter');
  }

  @override
  Future<void> subscribeToCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    throw UnsupportedError(
        'FlutterBluePlus characteristic subscription not implemented in adapter');
  }

  @override
  Future<void> unSubscribeFromCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    throw UnsupportedError(
        'FlutterBluePlus characteristic unsubscription not implemented in adapter');
  }
}

// WinBle适配器（用于Windows）
class WinBleAdapter implements BluetoothAdapter {
  StreamSubscription? _scanSubscription;
  final Map<String, StreamSubscription> _deviceConnectionSubscriptions = {};

  @override
  Future<void> init() async {
    try {
      // 对于Flutter项目，BleServer.exe应该在应用根目录
      // 确保使用正确的路径格式
      await WinBle.initialize(serverPath: 'BLEServer.exe');
      debugPrint('WinBle适配器初始化完成');
    } catch (e) {
      debugPrint('WinBle初始化失败: $e');
      // 如果初始化失败，可能是因为服务器文件不存在
      // 尝试使用windows文件夹下的文件
      try {
        await WinBle.initialize(serverPath: 'windows/BLEServer.exe');
        debugPrint('WinBle适配器初始化完成（使用windows路径）');
      } catch (e2) {
        debugPrint('WinBle初始化失败（两种路径都失败）: $e2');
        debugPrint('WinBle服务器文件可能不存在，将继续运行但蓝牙功能可能受限');
      }
    }
  }

  @override
  Future<void> startScan({Duration? timeout}) async {
    try {
      debugPrint('WinBle开始扫描设备...');
      WinBle.startScanning();
      debugPrint('WinBle扫描开始');

      // 处理扫描超时
      if (timeout != null) {
        Timer(timeout, () => stopScan());
      }
    } catch (e) {
      debugPrint('WinBle扫描启动失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      WinBle.stopScanning();
      _scanSubscription?.cancel();
      debugPrint('WinBle扫描停止');
    } catch (e) {
      debugPrint('WinBle扫描停止失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> connect(String deviceAddress) async {
    try {
      await WinBle.connect(deviceAddress);
      debugPrint('WinBle连接设备: $deviceAddress');

      // 监听连接状态变化
      final connectionStream = WinBle.connectionStreamOf(deviceAddress);
      _deviceConnectionSubscriptions[deviceAddress] =
          connectionStream.listen((isConnected) {
        debugPrint('设备 $deviceAddress 连接状态: ${isConnected ? "已连接" : "已断开"}');
        // 这里可以触发连接状态变化的事件
      });
    } catch (e) {
      debugPrint('WinBle连接设备失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String deviceAddress) async {
    try {
      await WinBle.disconnect(deviceAddress);
      _deviceConnectionSubscriptions[deviceAddress]?.cancel();
      _deviceConnectionSubscriptions.remove(deviceAddress);
      debugPrint('WinBle断开设备: $deviceAddress');
    } catch (e) {
      debugPrint('WinBle断开设备失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getConnectedDevices() async {
    try {
      // WinBle没有直接获取已连接设备的方法，这里返回空列表
      // 实际使用中需要维护一个已连接设备列表
      return [];
    } catch (e) {
      debugPrint('WinBle获取已连接设备失败: $e');
      rethrow;
    }
  }

  @override
  Future<BluetoothAdapterState> getAdapterState() async {
    try {
      await WinBle.getBluetoothState();
      // 简化处理：假设状态为on
      return BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('WinBle获取适配器状态失败: $e');
      rethrow;
    }
  }

  @override
  Stream<BluetoothAdapterState> get adapterStateChanged =>
      Stream.value(BluetoothAdapterState.on);

  @override
  Stream<List<dynamic>> get scanResults {
    debugPrint('WinBleAdapter scanResults stream created');
    return WinBle.scanStream.map((device) {
      debugPrint('WinBleAdapter接收到设备: ${device.toString()}');
      return [device];
    });
  }

  @override
  Stream<String> get connectionStateChanged =>
      const Stream.empty(); // 使用设备特定的连接流

  // 实现WinBle特有的方法
  @override
  Future<void> pair(String deviceAddress) async {
    try {
      await WinBle.pair(deviceAddress);
      debugPrint('WinBle配对设备: $deviceAddress');
    } catch (e) {
      debugPrint('WinBle配对设备失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> unPair(String deviceAddress) async {
    try {
      await WinBle.unPair(deviceAddress);
      debugPrint('WinBle取消配对设备: $deviceAddress');
    } catch (e) {
      debugPrint('WinBle取消配对设备失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> canPair(String deviceAddress) async {
    try {
      return await WinBle.canPair(deviceAddress);
    } catch (e) {
      debugPrint('WinBle检查配对能力失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPaired(String deviceAddress) async {
    try {
      return await WinBle.isPaired(deviceAddress);
    } catch (e) {
      debugPrint('WinBle检查配对状态失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> discoverServices(String deviceAddress) async {
    try {
      return await WinBle.discoverServices(deviceAddress);
    } catch (e) {
      debugPrint('WinBle发现服务失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> discoverCharacteristics(
      String deviceAddress, String serviceId) async {
    try {
      return await WinBle.discoverCharacteristics(
          address: deviceAddress, serviceId: serviceId);
    } catch (e) {
      debugPrint('WinBle发现特征失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<int>> readCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    try {
      return await WinBle.read(
          address: deviceAddress,
          serviceId: serviceId,
          characteristicId: characteristicId);
    } catch (e) {
      debugPrint('WinBle读取特征失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> writeCharacteristic(String deviceAddress, String serviceId,
      String characteristicId, List<int> data,
      {bool writeWithResponse = false}) async {
    try {
      await WinBle.write(
        address: deviceAddress,
        service: serviceId,
        characteristic: characteristicId,
        data: Uint8List.fromList(data),
        writeWithResponse: writeWithResponse,
      );
    } catch (e) {
      debugPrint('WinBle写入特征失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> subscribeToCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    try {
      await WinBle.subscribeToCharacteristic(
        address: deviceAddress,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );
    } catch (e) {
      debugPrint('WinBle订阅特征失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> unSubscribeFromCharacteristic(
      String deviceAddress, String serviceId, String characteristicId) async {
    try {
      await WinBle.unSubscribeFromCharacteristic(
        address: deviceAddress,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );
    } catch (e) {
      debugPrint('WinBle取消订阅特征失败: $e');
      rethrow;
    }
  }
}

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
  final Map<String, StreamSubscription> _deviceConnectionSubscriptions = {};

  // 蓝牙适配器实例
  late BluetoothAdapter _adapter;

  @override
  void onInit() {
    super.onInit();
    initBluetooth();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _adapterSubscription?.cancel();

    // 清理所有设备连接订阅
    for (var subscription in _deviceConnectionSubscriptions.values) {
      subscription.cancel();
    }
    _deviceConnectionSubscriptions.clear();

    super.onClose();
  }

  /// 初始化蓝牙
  Future<void> initBluetooth() async {
    try {
      // 根据平台选择适配器
      if (Platform.isWindows) {
        _adapter = WinBleAdapter();
      } else {
        _adapter = FlutterBluePlusAdapter();
      }

      // 初始化适配器
      await _adapter.init();

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
      // 检查蓝牙适配器状态
      final adapterStateResult = await _adapter.getAdapterState();
      adapterState.value = adapterStateResult;

      debugPrint('Windows蓝牙状态: $adapterStateResult');

      // 监听适配器状态变化
      _adapterSubscription = _adapter.adapterStateChanged.listen((state) {
        adapterState.value = state;
      });
    } catch (e) {
      debugPrint('Windows蓝牙初始化失败: $e');
      adapterState.value = BluetoothAdapterState.unavailable;
      Get.snackbar('错误', 'Windows蓝牙初始化失败: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 初始化移动端蓝牙
  Future<void> _initMobileBluetooth() async {
    // 监听蓝牙适配器状态
    _adapterSubscription = _adapter.adapterStateChanged.listen((state) {
      adapterState.value = state;
      if (state != BluetoothAdapterState.on) {
        discoveredDevices.clear();
        scanResults.clear();
        isScanning.value = false;
      }
    });

    // 获取当前状态
    final currentState = await _adapter.getAdapterState();
    adapterState.value = currentState;

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
      await _startScan(timeout);
    } catch (e) {
      debugPrint('开始扫描失败: $e');
      Get.snackbar('错误', '开始扫描失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 通用蓝牙扫描（适用于所有平台）
  Future<void> _startScan(Duration? timeout) async {
    isScanning.value = true;
    // 不要清空设备列表，让设备累计
    // discoveredDevices.clear();
    // scanResults.clear();

    try {
      debugPrint('${Platform.isWindows ? "Windows" : "Mobile"}蓝牙扫描已启动');

      // 使用适配器进行扫描
      await _adapter.startScan(timeout: timeout);

      // 监听扫描结果
      _scanSubscription = _adapter.scanResults.listen((results) {
        if (Platform.isWindows) {
          debugPrint('Windows平台处理扫描结果，设备数量: ${results.length}');

          // Windows平台：win_ble返回设备流，需要累计设备而不是清空
          for (var device in results) {
            debugPrint('处理设备: ${device.toString()}');
            try {
              // 安全地访问BleDevice属性，避免类型错误
              String deviceAddress = '';
              String deviceName = '未知设备';
              int rssi = -50;
              bool isConnectable = false; // 添加可连接状态
              List<String> serviceUuidStrings = []; // 服务UUID字符串列表
              Map<int, List<int>> manufacturerData = {}; // 制造商数据

              // 打印原始设备对象信息，便于调试
              debugPrint('===== Windows BLE设备原始数据 =====');
              debugPrint('设备对象类型: ${device.runtimeType}');
              debugPrint('设备对象字符串: $device');

              try {
                // 安全地处理address属性
                if (device.address != null) {
                  deviceAddress = device.address.toString();
                } else {
                  deviceAddress = device.toString();
                }
                debugPrint('设备地址: $deviceAddress');

                // 安全地处理name属性 - 优先使用name，如果为空或null则保持"未知设备"
                if (device.name != null && device.name.toString().isNotEmpty) {
                  deviceName = device.name.toString();
                  debugPrint('从device.name获取到设备名称: $deviceName');
                } else {
                  debugPrint('device.name为空或null，设备名称保持默认: $deviceName');
                }

                // 安全地处理rssi属性，确保是int类型
                if (device.rssi != null) {
                  if (device.rssi is int) {
                    rssi = device.rssi as int;
                  } else if (device.rssi is String) {
                    try {
                      rssi = int.parse(device.rssi.toString());
                    } catch (e) {
                      debugPrint('RSSI字符串转换失败: ${device.rssi}');
                      rssi = -50;
                    }
                  } else {
                    rssi = -50;
                  }
                }

                // 安全地处理服务UUID
                try {
                  if (device.serviceUuids != null) {
                    if (device.serviceUuids is List) {
                      serviceUuidStrings = device.serviceUuids
                          .map((uuid) => uuid.toString())
                          .toList();
                    }
                  }
                } catch (e) {
                  debugPrint('服务UUID获取失败: $e');
                }

                // 安全地处理制造商数据
                try {
                  debugPrint('===== 开始获取制造商数据 =====');
                  debugPrint('设备对象类型: ${device.runtimeType}');

                  // 打印设备对象的完整结构
                  debugPrint('设备对象详细信息:');
                  try {
                    // 尝试打印所有可能的属性
                    var commonProps = [
                      'address',
                      'name',
                      'rssi',
                      'manufacturerData',
                      'advertisementData',
                      'advertisingData',
                      'manufData',
                      'advData',
                      'data',
                      'serviceUuids',
                      'connectable'
                    ];
                    for (var prop in commonProps) {
                      try {
                        var value = _getProperty(device, prop);
                        if (value != null) {
                          debugPrint('  $prop: $value (${value?.runtimeType})');
                          // 如果是制造商数据，尝试打印具体内容
                          if (prop.contains('manufacturer') || prop.contains('adv') || prop.contains('data')) {
                            if (value is Map) {
                              debugPrint('    Map内容:');
                              value.forEach((k, v) {
                                debugPrint('      键: $k, 值: $v');
                                if (v is List) {
                                  final hexStr = v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                                  debugPrint('      16进制: $hexStr');
                                }
                              });
                            } else if (value is List) {
                              final hexStr = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                              debugPrint('    List内容(16进制): $hexStr');
                              debugPrint('    List内容(10进制): $value');
                            }
                          }
                        }
                      } catch (e) {
                        // 静默忽略访问失败的属性
                      }
                    }
                  } catch (e) {
                    debugPrint('打印设备属性失败: $e');
                  }

                  // 尝试多种方式获取制造商数据
                  List<String> triedProps = [];

                  // 方法1: 直接属性访问
                  var props = [
                    'manufacturerData',
                    'advertisementData',
                    'advertisingData',
                    'manufData',
                    'advData',
                    'data'
                  ];

                  for (var prop in props) {
                    triedProps.add(prop);
                    try {
                      var value = _getProperty(device, prop);
                      if (value != null) {
                        debugPrint(
                            '找到属性 $prop: $value (类型: ${value.runtimeType})');
                        if (_extractManufacturerData(value, manufacturerData)) {
                          debugPrint(
                              '成功从 $prop 提取制造商数据，长度: ${manufacturerData.length}');
                          break;
                        }
                      }
                    } catch (e) {
                      debugPrint('访问属性 $prop 失败: $e');
                    }
                  }

                  debugPrint('尝试的属性: $triedProps');
                  debugPrint('最终制造商数据长度: ${manufacturerData.length}');

                  // 如果还是没有找到制造商数据，尝试其他可能的位置
                  if (manufacturerData.isEmpty) {
                    debugPrint('尝试从其他可能的位置获取制造商数据...');

                    // 尝试从advertisementData的嵌套结构中获取
                    try {
                      var advData = _getProperty(device, 'advertisementData');
                      if (advData != null && advData is Map) {
                        debugPrint('advertisementData结构: $advData');
                        if (advData.containsKey('manufacturerData')) {
                          var manufData = advData['manufacturerData'];
                          if (manufData != null) {
                            debugPrint(
                                '从advertisementData.manufacturerData获取: $manufData');
                            if (_extractManufacturerData(
                                manufData, manufacturerData)) {
                              debugPrint(
                                  '成功从advertisementData.manufacturerData提取制造商数据，长度: ${manufacturerData.length}');
                            }
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('从advertisementData获取制造商数据失败: $e');
                    }
                  }
                } catch (e) {
                  debugPrint('制造商数据获取失败: $e');
                }

                // 判断设备是否可连接
                isConnectable = _isDeviceLikelyConnectable(
                    device, serviceUuidStrings, manufacturerData);

                debugPrint(
                    '设备信息: 地址=$deviceAddress, 名称=$deviceName, RSSI=$rssi, 可连接=$isConnectable');
                debugPrint('制造商数据长度: ${manufacturerData.length}');
                debugPrint('服务UUID数量: ${serviceUuidStrings.length}');
              } catch (e) {
                debugPrint('设备属性访问错误: $e');
                // 设备属性访问错误，使用默认值
              }

              // 检查设备是否已存在
              final existingResultIndex = scanResults.indexWhere(
                  (result) => result.device.remoteId.str == deviceAddress);

              if (existingResultIndex >= 0) {
                // 更新现有设备的信号强度和时间戳
                final updatedResults = List<ScanResult>.from(scanResults);

                // 获取现有设备的名称，如果新扫描到的名称不为空则更新
                String finalDeviceName = deviceName;
                if (finalDeviceName == '未知设备' || finalDeviceName.isEmpty) {
                  // 尝试保持之前的名称
                  final existingName = updatedResults[existingResultIndex].advertisementData.advName;
                  if (existingName != null && existingName.isNotEmpty && existingName != '未知设备') {
                    finalDeviceName = existingName;
                    debugPrint('保持现有设备名称: $finalDeviceName');
                  }
                } else {
                  debugPrint('更新设备名称为: $finalDeviceName');
                }

                // 如果设备名称发生了变化，也更新设备名称
                final updatedDevice = BluetoothDevice(
                  remoteId: updatedResults[existingResultIndex].device.remoteId,
                );
                // 创建更新后的advertisementData，保持可连接状态和服务UUID
                final updatedAdvData = AdvertisementData(
                  advName: finalDeviceName, // 使用最终的设备名称
                  txPowerLevel: updatedResults[existingResultIndex]
                      .advertisementData
                      .txPowerLevel,
                  appearance: updatedResults[existingResultIndex]
                      .advertisementData
                      .appearance,
                  connectable: isConnectable, // 更新可连接状态
                  manufacturerData: manufacturerData.isNotEmpty
                      ? manufacturerData
                      : updatedResults[existingResultIndex]
                          .advertisementData
                          .manufacturerData,
                  serviceData: updatedResults[existingResultIndex]
                      .advertisementData
                      .serviceData,
                  serviceUuids: [], // 暂时使用空列表，避免类型错误
                );

                updatedResults[existingResultIndex] = ScanResult(
                  device: updatedDevice,
                  advertisementData: updatedAdvData,
                  rssi: rssi,
                  timeStamp: DateTime.now(),
                );
                scanResults.value = updatedResults;

                debugPrint('更新设备 $deviceAddress，最终名称: $finalDeviceName');
              } else {
                // 创建新的ScanResult对象并添加到列表
                final newResults = List<ScanResult>.from(scanResults);
                final bluetoothDevice = BluetoothDevice(
                  remoteId: DeviceIdentifier(deviceAddress),
                );

                final scanResult = ScanResult(
                  device: bluetoothDevice,
                  advertisementData: AdvertisementData(
                    advName: deviceName,
                    txPowerLevel: null,
                    appearance: 0,
                    connectable: isConnectable, // 使用实际的可连接状态
                    manufacturerData: manufacturerData,
                    serviceData: {},
                    serviceUuids: [], // 暂时使用空列表，避免类型错误
                  ),
                  rssi: rssi,
                  timeStamp: DateTime.now(),
                );

                newResults.add(scanResult);
                scanResults.value = newResults;

                debugPrint('新增设备 $deviceAddress，名称: $deviceName');
              }
            } catch (e) {
              // 转换设备失败
            }
          }

          // 更新发现的设备列表（从scanResults中提取）
          final deviceList =
              scanResults.map((result) => result.device).toList();
          discoveredDevices.value = deviceList;
        } else {
          // 移动端：flutter_blue_plus直接返回ScanResult列表
          if (results is List<ScanResult>) {
            scanResults.value = results;
            discoveredDevices.value =
                results.map((result) => result.device).toList();
          }
        }
      });

      debugPrint('${Platform.isWindows ? "Windows" : "Mobile"}蓝牙扫描正常启动');

      // 处理扫描超时
      if (timeout != null) {
        Timer(timeout, () => stopScan());
      }
    } catch (e) {
      isScanning.value = false;
      debugPrint('${Platform.isWindows ? "Windows" : "Mobile"}蓝牙扫描启动失败: $e');
      Get.snackbar(
          '错误', '${Platform.isWindows ? "Windows" : "Mobile"}蓝牙扫描启动失败: $e',
          snackPosition: SnackPosition.BOTTOM);
      throw Exception(
          '${Platform.isWindows ? "Windows" : "Mobile"}蓝牙扫描启动失败: $e');
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

  /// 停止扫描
  Future<void> stopScan() async {
    if (!isScanning.value) return;

    try {
      await _adapter.stopScan();

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
        // Windows平台：使用win_ble的连接方式
        await _adapter.connect(device.remoteId.str);

        // 监听连接状态变化
        final connectionStream = WinBle.connectionStreamOf(device.remoteId.str);
        _deviceConnectionSubscriptions[device.remoteId.str] =
            connectionStream.listen((isConnected) {
          if (isConnected) {
            if (!connectedDevices.contains(device)) {
              connectedDevices.add(device);
            }
            Get.snackbar('成功', '设备连接成功', snackPosition: SnackPosition.BOTTOM);
          } else {
            connectedDevices.remove(device);
          }
        });
      } else {
        // 移动端：使用flutter_blue_plus的连接方式
        await device.connect(timeout: const Duration(seconds: 10));
        if (!connectedDevices.contains(device)) {
          connectedDevices.add(device);
        }
        Get.snackbar('成功', '设备连接成功', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('连接设备失败: $e');
      Get.snackbar('错误', '连接设备失败: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 断开设备连接
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      if (Platform.isWindows) {
        // Windows平台：断开连接并清理订阅
        await _adapter.disconnect(device.remoteId.str);
        _deviceConnectionSubscriptions[device.remoteId.str]?.cancel();
        _deviceConnectionSubscriptions.remove(device.remoteId.str);
      } else {
        // 移动端：断开连接
        await device.disconnect();
      }

      connectedDevices.remove(device);
    } catch (e) {
      // 断开设备连接失败
    }
  }

  /// 更新已连接设备列表
  Future<void> updateConnectedDevices() async {
    try {
      await _adapter.getConnectedDevices();
      // 注意：这里需要将适配器的设备列表转换为BluetoothDevice格式
      // connectedDevices.value = connectedDevicesResult.map((device) => _convertFromAdapterDevice(device)).toList();
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

  /// 启用蓝牙
  Future<void> turnOnBluetooth() async {
    if (Platform.isWindows) {
      Get.snackbar('提示', '请在系统设置中手动启用蓝牙', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      if (Platform.isAndroid) {
        // 对于移动端适配器，这里需要特殊处理
        // 因为FlutterBluePlus.turnOn()不是适配器方法的一部分
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

  // 辅助方法：安全获取对象属性
  dynamic _getProperty(dynamic object, String propertyName) {
    try {
      // 对于win_ble的BleDevice对象，尝试直接属性访问
      switch (propertyName) {
        case 'address':
          return object.address;
        case 'name':
          return object.name;
        case 'rssi':
          return object.rssi;
        case 'manufacturerData':
          return object.manufacturerData;
        case 'advertisementData':
          // win_ble可能将广播数据存储在不同的属性中
          if (object.advertisementData != null) {
            return object.advertisementData;
          } else if (object.manufData != null) {
            return object.manufData;
          } else if (object.data != null) {
            return object.data;
          }
          return null;
        case 'serviceUuids':
          return object.serviceUuids;
        case 'connectable':
          return object.connectable;
        default:
          // 尝试动态访问
          try {
            return object.getField(propertyName);
          } catch (e) {
            // 如果getField失败，尝试其他方法
            return null;
          }
      }
    } catch (e) {
      // 尝试通过点号访问嵌套属性
      if (propertyName.contains('.')) {
        var parts = propertyName.split('.');
        var current = object;
        for (var part in parts) {
          if (current == null) break;
          try {
            current = _getProperty(current, part);
          } catch (e) {
            return null;
          }
        }
        return current;
      }
      return null;
    }
  }

  // 辅助方法：从各种数据结构中提取制造商数据
  bool _extractManufacturerData(
      dynamic value, Map<int, List<int>> manufacturerData) {
    try {
      if (value == null) return false;

      debugPrint('尝试提取制造商数据，输入类型: ${value.runtimeType}');

      if (value is Map) {
        // 如果是Map，寻找manufacturerData键
        if (value.containsKey('manufacturerData') &&
            value['manufacturerData'] != null) {
          var manufData = value['manufacturerData'];
          if (manufData is Map) {
            manufacturerData.addAll(Map<int, List<int>>.from(manufData));
            return true;
          }
        }
        // 直接作为制造商数据
        manufacturerData.addAll(Map<int, List<int>>.from(value));
        return true;
      } else if (value is List) {
        // 如果是List，转为Map格式
        manufacturerData[0xFFFF] = value.cast<int>();
        return true;
      }

      debugPrint('无法从该类型提取制造商数据: ${value.runtimeType}');
      return false;
    } catch (e) {
      debugPrint('提取制造商数据失败: $e');
      return false;
    }
  }

  // 辅助方法：判断设备是否可能是可连接的
  bool _isDeviceLikelyConnectable(dynamic device,
      List<String> serviceUuidStrings, Map<int, List<int>> manufacturerData) {
    try {
      // 首先检查是否有明确的connectable属性
      if (device.connectable is bool) {
        return device.connectable as bool;
      }

      // 检查设备是否有服务UUID（可连接设备通常有服务UUID）
      if (serviceUuidStrings.isNotEmpty) {
        return true;
      }

      // 检查制造商数据（可连接设备通常有制造商数据）
      if (manufacturerData.isNotEmpty) {
        return true;
      }

      // 检查设备名称（信标通常没有具体名称或名称很短）
      if (device.name != null && device.name.toString().isNotEmpty) {
        final name = device.name.toString().toLowerCase();
        // 如果设备名称看起来像是一个具体的设备名称而不是随机字符串，则可能是可连接设备
        if (!name.contains('beacon') &&
            !name.contains('ibeacon') &&
            name.length > 3) {
          return true;
        }
      }

      // 检查设备类型（某些设备类型明确表示不可连接）
      if (device.deviceType != null) {
        final deviceType = device.deviceType.toString().toLowerCase();
        if (deviceType.contains('beacon') ||
            deviceType.contains('advertiser')) {
          return false;
        }
      }

      // 对于大多数BLE设备，如果没有明确的不可连接标志，我们假设它是可连接的
      // 这是因为许多BLE设备在广播时没有明确标识自己是否可连接
      return true;
    } catch (e) {
      return true; // 默认认为是可连接的，避免误判
    }
  }
}
