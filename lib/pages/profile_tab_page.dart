import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../services/app_update_service.dart';
import '../services/database_service.dart';
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
    final actions = _buildOrbitActions();

    return TracePageScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stageWidth = math.min(constraints.maxWidth - 42, 392.0);
            final compact = constraints.maxHeight < 720;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                compact ? 18 : 24,
                22,
                TraceTheme.bottomNavHeight + 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    constraints.maxHeight - TraceTheme.bottomNavHeight - 28,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TracePageTitle(
                      eyebrow: 'PROFILE CONSOLE',
                      title: '我的',
                      subtitle: '数据、更新、设置、帮助和关于集中在圆形控制台内',
                      trailing: TracePill(
                        icon: Icons.person,
                        label: 'USER',
                      ),
                    ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.14, end: 0),
                    SizedBox(height: compact ? 16 : 24),
                    Center(
                      child: SizedBox(
                        width: stageWidth,
                        child: TraceRadialConsole(
                          centerTitle: '我的中心',
                          centerSubtitle: 'LOCAL USER',
                          centerIcon: Icons.person,
                          badgeLabel: 'PROFILE',
                          footerLabel: 'SERVICE',
                          primaryColor: TraceColors.cyan,
                          actions: actions,
                        ),
                      ),
                    )
                        .animate(delay: 110.ms)
                        .fadeIn(duration: 520.ms)
                        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
                    SizedBox(height: compact ? 18 : 26),
                    Center(
                      child: _buildVersionText(
                        style: TextStyle(
                          fontSize: 12,
                          color: TraceColors.muted.withOpacity(0.72),
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<TraceOrbitAction> _buildOrbitActions() {
    return [
      TraceOrbitAction(
        title: '数据',
        subtitle: '查看设备数据统计',
        code: '01',
        icon: Icons.storage,
        color: TraceColors.cyan,
        onTap: _showDataStatistics,
      ),
      TraceOrbitAction(
        title: '更新',
        subtitle: '检查应用更新',
        code: '02',
        icon: Icons.system_update_alt,
        color: TraceColors.cyanSoft,
        onTap: _checkForUpdates,
      ),
      TraceOrbitAction(
        title: '设置',
        subtitle: '个性化选项',
        code: '03',
        icon: Icons.settings,
        color: TraceColors.mint,
        onTap: _showSettingsDialog,
      ),
      TraceOrbitAction(
        title: '帮助',
        subtitle: '查看使用帮助',
        code: '04',
        icon: Icons.help_outline,
        color: TraceColors.amber,
        onTap: _showHelpDialog,
      ),
      TraceOrbitAction(
        title: '关于',
        subtitle: '版本与应用信息',
        code: '05',
        icon: Icons.info_outline,
        color: TraceColors.rose,
        onTap: _showAboutDialog,
      ),
    ];
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

  void _showSettingsDialog() {
    _showTraceDialog(
      TraceDialog(
        title: '应用设置',
        icon: Icons.settings,
        color: TraceColors.mint,
        message: '设置功能开发中。当前版本先保留入口，后续会接入个性化配置。',
        actions: [
          TraceDialogAction(
            label: '知道了',
            isPrimary: true,
            color: TraceColors.mint,
            onPressed: TraceDialog.close,
          ),
        ],
      ),
    );
  }

  void _showDataStatistics() async {
    try {
      final dbService = DatabaseService();
      final dbInfo = await dbService.getDatabaseInfo();

      _showTraceDialog(
        TraceDialog(
          title: '数据统计',
          icon: Icons.storage,
          color: TraceColors.cyan,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem('保存的设备', '${dbInfo['deviceCount']} 个'),
              const SizedBox(height: 10),
              _buildStatItem('数据记录', '${dbInfo['dataCount']} 条'),
            ],
          ),
          actions: [
            TraceDialogAction(
              label: '确定',
              isPrimary: true,
              onPressed: TraceDialog.close,
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
            fontWeight: FontWeight.w900,
            color: TraceColors.cyan,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    _showTraceDialog(
      TraceDialog(
        title: '使用帮助',
        icon: Icons.help_outline,
        color: TraceColors.amber,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('功率计功能：'),
            Text('1. 扫描并选择 BLE 设备'),
            Text('2. 点击监控查看实时数据'),
            Text('3. 保存设备以便长期监控'),
            SizedBox(height: 16),
            Text('码表功能：'),
            Text('1. 连接码表设备'),
            Text('2. 查看骑行数据'),
            Text('3. OTA 升级固件'),
            SizedBox(height: 16),
            Text('遥控功能：'),
            Text('1. 连接蓝牙设备'),
            Text('2. 自定义控制按钮'),
            Text('3. 发送控制指令'),
          ],
        ),
        actions: [
          TraceDialogAction(
            label: '确定',
            isPrimary: true,
            color: TraceColors.amber,
            onPressed: TraceDialog.close,
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    _showTraceDialog(
      TraceDialog(
        title: '关于应用',
        icon: Icons.info_outline,
        color: TraceColors.rose,
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
            const Text('• OTA 固件升级'),
          ],
        ),
        actions: [
          TraceDialogAction(
            label: '确定',
            isPrimary: true,
            color: TraceColors.rose,
            onPressed: TraceDialog.close,
          ),
        ],
      ),
    );
  }

  void _showTraceDialog(TraceDialog dialog) {
    Get.dialog<void>(
      dialog,
      barrierColor: Colors.black.withOpacity(0.62),
    );
  }
}
