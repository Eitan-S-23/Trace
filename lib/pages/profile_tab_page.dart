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
                  minHeight: math.max(0, constraints.maxHeight - TraceTheme.bottomNavHeight - 28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TracePageTitle(
                      eyebrow: 'PROFILE CONSOLE',
                      title: '我的',
                      subtitle: '数据统计、应用维护和帮助入口',
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
                    SizedBox(height: compact ? 14 : 20),
                    _buildControlConsole()
                        .animate(delay: 240.ms)
                        .fadeIn(duration: 420.ms)
                        .slideY(begin: 0.12, end: 0),
                    const SizedBox(height: 20),
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
        onTap: () => Get.snackbar('提示', '设置功能开发中'),
      ),
      TraceOrbitAction(
        title: '帮助',
        subtitle: '查看使用帮助',
        code: '04',
        icon: Icons.help_outline,
        color: TraceColors.amber,
        onTap: _showHelpDialog,
      ),
    ];
  }

  Widget _buildControlConsole() {
    return TraceGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      borderRadius: 28,
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '维护控制台',
                style: TextStyle(
                  color: TraceColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '05 ACTIONS',
                style: TextStyle(
                  color: TraceColors.cyan.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.storage,
            title: '数据统计',
            subtitle: '查看设备数据统计',
            color: TraceColors.cyan,
            onTap: _showDataStatistics,
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: '应用设置',
            subtitle: '个性化设置选项',
            color: TraceColors.mint,
            onTap: () => Get.snackbar('提示', '设置功能开发中'),
          ),
          _buildUpdateMenuItem(),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            subtitle: '使用帮助和问题反馈',
            color: TraceColors.amber,
            onTap: _showHelpDialog,
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '关于应用',
            subtitle: '版本信息和开发团队',
            color: TraceColors.cyanSoft,
            onTap: _showAboutDialog,
          ),
        ],
      ),
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: color.withOpacity(0.075),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.26)),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: TraceColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TraceColors.muted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ?? Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.72), size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateMenuItem() {
    if (!Get.isRegistered<AppUpdateService>()) {
      return _buildMenuItem(
        icon: Icons.system_update_alt,
        title: '检查更新',
        subtitle: '检查 Cloudflare 增量更新',
        color: TraceColors.cyanSoft,
        onTap: _checkForUpdates,
      );
    }

    final service = AppUpdateService.to;
    return Obx(() {
      final busy = service.isChecking.value || service.isUpdating.value;
      return _buildMenuItem(
        icon: busy ? Icons.sync : Icons.system_update_alt,
        title: busy ? '正在检查更新' : '检查更新',
        subtitle: busy
            ? (service.updateStatus.value.isEmpty
                ? '正在连接更新服务器'
                : service.updateStatus.value)
            : '检查 Cloudflare 增量更新',
        color: TraceColors.cyanSoft,
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: TraceColors.cyanSoft,
                ),
              )
            : null,
        onTap: _checkForUpdates,
      );
    });
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
