import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/app_update_service.dart';
import '../services/database_service.dart';
import 'reference_design_screen.dart';
import 'trace_ui.dart';

const String _appName = 'BLE Monitor';
const MethodChannel _appUpdateChannel = MethodChannel('trace/app_update');
final Future<String> _appVersionLabelFuture = _loadAppVersionLabel();

Future<String> _loadAppVersionLabel() async {
  try {
    final result =
        await _appUpdateChannel.invokeMapMethod<String, dynamic>('getAppInfo');
    final versionName = result?['versionName']?.toString().trim() ?? '';
    if (versionName.isNotEmpty) {
      return '$_appName v$versionName';
    }
  } catch (_) {
    // Keep the profile usable on platforms without the Android update channel.
  }

  return _appName;
}

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReferenceDesignScreen(
      assetPath: 'assets/design_refs/profile_35.png',
      hotspots: [
        TraceDesignHotspot(
          left: 0.08,
          top: 0.40,
          width: 0.84,
          height: 0.075,
          onTap: () => _showDataStatistics(),
        ),
        TraceDesignHotspot(
          left: 0.08,
          top: 0.475,
          width: 0.84,
          height: 0.075,
          onTap: () {
            Get.snackbar('提示', '设置功能开发中');
          },
        ),
        TraceDesignHotspot(
          left: 0.08,
          top: 0.55,
          width: 0.84,
          height: 0.075,
          onTap: _checkForUpdates,
        ),
        TraceDesignHotspot(
          left: 0.08,
          top: 0.625,
          width: 0.84,
          height: 0.075,
          onTap: () => _showHelpDialog(),
        ),
        TraceDesignHotspot(
          left: 0.08,
          top: 0.70,
          width: 0.84,
          height: 0.075,
          onTap: () => _showAboutDialog(),
        ),
      ],
    );
  }

  Widget _buildVersionText({TextStyle? style}) {
    return FutureBuilder<String>(
      future: _appVersionLabelFuture,
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? _appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }

  void _checkForUpdates() {
    final service = Get.isRegistered<AppUpdateService>()
        ? AppUpdateService.to
        : Get.put(AppUpdateService(), permanent: true);
    unawaited(service.checkForUpdates());
  }

  void _showDataStatistics() async {
    try {
      final dbService = DatabaseService();
      final dbInfo = await dbService.getDatabaseInfo();

      Get.dialog(
        AlertDialog(
          title: const Text('数据统计'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatItem('保存的设备', '${dbInfo['deviceCount']} 个'),
              const SizedBox(height: 8),
              _buildStatItem('数据记录', '${dbInfo['dataCount']} 条'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('错误', '获取数据统计失败: $e');
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: TraceColors.cyan,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('功率计功能：'),
              Text('1. 扫描并选择BLE设备'),
              Text('2. 点击监控查看实时数据'),
              Text('3. 保存设备以便长期监控'),
              SizedBox(height: 16),
              Text('码表功能：'),
              Text('1. 连接码表设备'),
              Text('2. 查看骑行数据'),
              Text('3. OTA升级固件'),
              SizedBox(height: 16),
              Text('遥控功能：'),
              Text('1. 连接蓝牙设备'),
              Text('2. 自定义控制按钮'),
              Text('3. 发送控制指令'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('关于应用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVersionText(),
            const SizedBox(height: 8),
            const Text('智能蓝牙设备管理助手'),
            const SizedBox(height: 16),
            const Text('功能特性：'),
            const Text('• 功率计监控'),
            const Text('• 码表数据管理'),
            const Text('• 遥控设备控制'),
            const Text('• 数据可视化'),
            const Text('• OTA固件升级'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
