import 'package:flutter_test/flutter_test.dart';
import '../lib/models/device_data.dart';

void main() {
  group('ManufacturerDataParser 测试', () {
    test('正确解析7字节厂商数据', () {
      // 模拟数据：
      // 设备ID: 0x1234 (小端序: 0x34, 0x12)
      // 电流: 500 (小端序: 0xF4, 0x01)
      // 电流单位: 50 (mA)
      // 电压: 3700 (小端序: 0x74, 0x0E)
      final testData = [
        0x34, 0x12, // 设备ID: 0x1234
        0xF4, 0x01, // 电流: 500
        50,         // 电流单位: mA
        0x74, 0x0E, // 电压: 3700 mV
      ];

      final result = ManufacturerDataParser.parseManufacturerData(
        'test_device_id',
        'Test Device',
        testData,
      );

      expect(result, isNotNull);
      expect(result!.current, 500.0); // 原始值500，单位mA
      expect(result.currentUnit, 'mA');
      expect(result.voltage, 3700.0); // 3700 mV
      expect(result.power, closeTo(1850.0, 0.1)); // P = 3.7V * 0.5A = 1.85W = 1850mW
    });

    test('正确解析不同电流单位', () {
      // 测试nA单位
      final nanoData = [
        0x00, 0x00, // 设备ID
        0x64, 0x00, // 电流: 100
        1,          // 电流单位: nA
        0xE8, 0x03, // 电压: 1000 mV
      ];

      var result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', nanoData);
      expect(result, isNotNull);
      expect(result!.current, 100.0); // 原始值100，单位nA
      expect(result.currentUnit, 'nA');

      // 测试uA单位
      final microData = [
        0x00, 0x00, // 设备ID
        0xE8, 0x03, // 电流: 1000
        10,         // 电流单位: uA
        0xE8, 0x03, // 电压: 1000 mV
      ];

      result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', microData);
      expect(result, isNotNull);
      expect(result!.current, 1000.0); // 原始值1000，单位uA
      expect(result.currentUnit, 'uA');

      // 测试A单位
      final ampereData = [
        0x00, 0x00, // 设备ID
        0x02, 0x00, // 电流: 2
        100,        // 电流单位: A
        0xE8, 0x03, // 电压: 1000 mV
      ];

      result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', ampereData);
      expect(result, isNotNull);
      expect(result!.current, 2.0); // 原始值2，单位A
      expect(result.currentUnit, 'A');
    });

    test('处理高位字节正确', () {
      // 测试电流高位字节
      final highCurrentData = [
        0x00, 0x00, // 设备ID
        0xFF, 0xFF, // 电流: 65535 (最大值)
        50,         // 电流单位: mA
        0x00, 0x10, // 电压: 4096 mV
      ];

      var result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', highCurrentData);
      expect(result, isNotNull);
      expect(result!.current, 65535.0); // 原始值65535，单位mA

      // 测试电压高位字节
      final highVoltageData = [
        0x00, 0x00, // 设备ID
        0x64, 0x00, // 电流: 100
        50,         // 电流单位: mA
        0xFF, 0xFF, // 电压: 65535 mV (最大值)
      ];

      result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', highVoltageData);
      expect(result, isNotNull);
      expect(result!.voltage, 65535.0); // 65535 mV
    });

    test('拒绝长度不足的数据', () {
      // 只有6字节，应该返回null
      final shortData = [0x00, 0x00, 0x64, 0x00, 50, 0xE8];

      final result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', shortData);
      expect(result, isNull);
    });

    test('拒绝无效的电流单位', () {
      // 无效的电流单位: 99
      final invalidUnitData = [
        0x00, 0x00, // 设备ID
        0x64, 0x00, // 电流: 100
        99,         // 无效的电流单位
        0xE8, 0x03, // 电压: 1000 mV
      ];

      final result = ManufacturerDataParser.parseManufacturerData(
        'test', 'Test', invalidUnitData);
      expect(result, isNull);
    });
  });
}