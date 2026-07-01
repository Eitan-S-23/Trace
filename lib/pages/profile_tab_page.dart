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
    return TracePageScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            TraceTheme.bottomNavHeight + 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TracePageTitle(
                eyebrow: 'PROFILE CONSOLE',
                title: '我的',
                subtitle: '账号信息、数据统计和应用维护集中在一个深海控制面板中。',
                trailing: TracePill(
                  icon: Icons.person,
                  label: 'USER',
                  color: TraceColors.mint,
                ),
              ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.16, end: 0),
              const SizedBox(height: 16),
              _buildIdentityStage()
                  .animate(delay: 120.ms)
                  .fadeIn(duration: 620.ms)
                  .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
              const TraceFirstViewportSpacer(consumedHeight: 538),
              _buildControlConsole()
                  .animate(delay: 220.ms)
                  .fadeIn(duration: 560.ms)
                  .slideY(begin: 0.14, end: 0),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '© 2024 BLE Monitor\n智能设备管理助手',
                  textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildIdentityStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = math.min(constraints.maxWidth, 390.0);
        final stageHeight = math.max(outerWidth * 0.92, 332.0);

        return Center(
          child: SizedBox(
            width: outerWidth,
            child: TraceGlassPanel(
              padding: const EdgeInsets.all(12),
              borderRadius: 34,
              glowColor: TraceColors.mint,
              child: SizedBox(
                height: stageHeight,
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final width = innerConstraints.maxWidth;
                    final nodeSize = math.min(width * 0.23, 82.0);
                    final hubSize = math.min(width * 0.43, 150.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: TraceOrbitPainter(progress: 0.88)),
                        ),
                        Positioned(
                          top: 16,
                          left: 18,
                          right: 18,
                          child: Row(
                            children: [
                              const TracePill(
                                icon: Icons.person,
                                label: 'LOCAL USER',
                                color: TraceColors.mint,
                              ),
                              const Spacer(),
                              Text(
                                'PROFILE',
                                style: TextStyle(
                                  color: TraceColors.cyan.withOpacity(0.58),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: (stageHeight - nodeSize) / 2,
                          child: _ProfileOrbitNode(
                            size: nodeSize,
                            icon: Icons.storage,
                            label: 'DATA',
                            color: TraceColors.cyan,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: (stageHeight - nodeSize) / 2,
                          child: _ProfileOrbitNode(
                            size: nodeSize,
                            icon: Icons.system_update_alt,
                            label: 'UPDATE',
                            color: TraceColors.amber,
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: (width - nodeSize) / 2,
                          child: _ProfileOrbitNode(
                            size: nodeSize,
                            icon: Icons.help_outline,
                            label: 'HELP',
                            color: TraceColors.rose,
                          ),
                        ),
                        Container(
                          width: hubSize,
                          height: hubSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                TraceColors.mint.withOpacity(0.3),
                                TraceColors.ocean.withOpacity(0.24),
                                TraceColors.ink.withOpacity(0.96),
                              ],
                            ),
                            border: Border.all(color: TraceColors.cyan.withOpacity(0.42)),
                            boxShadow: [
                              BoxShadow(
                                color: TraceColors.cyan.withOpacity(0.26),
                                blurRadius: 42,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person, color: TraceColors.cyan, size: 36),
                              const SizedBox(height: 8),
                              const Text(
                                '智能设备用户',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: TraceColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: hubSize - 26,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _buildVersionText(
                                    style: const TextStyle(
                                      color: TraceColors.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlConsole() {
    return TraceGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      borderRadius: 30,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
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
            onTap: () => _showDataStatistics(),
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: '应用设置',
            subtitle: '个性化设置选项',
            color: TraceColors.mint,
            onTap: () {
              Get.snackbar('提示', '设置功能开发中');
            },
          ),
          _buildUpdateMenuItem(),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            subtitle: '使用帮助和问题反馈',
            color: TraceColors.rose,
            onTap: () => _showHelpDialog(),
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: '关于应用',
            subtitle: '版本信息和开发团队',
            color: TraceColors.cyanSoft,
            onTap: () => _showAboutDialog(),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
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
    );
  }

  Widget _buildUpdateMenuItem() {
    if (!Get.isRegistered<AppUpdateService>()) {
      return _buildMenuItem(
        icon: Icons.system_update_alt,
        title: '检查更新',
        subtitle: '检查 Cloudflare 增量更新',
        color: TraceColors.amber,
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
        color: TraceColors.amber,
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: TraceColors.amber,
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

class _ProfileOrbitNode extends StatelessWidget {
  const _ProfileOrbitNode({
    required this.size,
    required this.icon,
    required this.label,
    required this.color,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF071B25).withOpacity(0.9),
        border: Border.all(color: color.withOpacity(0.42)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TraceColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
