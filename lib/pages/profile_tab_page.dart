import 'dart:async';

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
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            TraceTheme.bottomNavHeight + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的',
                    style: TextStyle(
                      color: TraceColors.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Color(0x6624F6DE), blurRadius: 18),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const _ProfileAvatar(),
                ],
              ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.14, end: 0),
              const SizedBox(height: 22),
              _ProfilePanel(
                versionHeader: _buildVersionText(
                  style: const TextStyle(
                    color: TraceColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                actions: _buildActions(),
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 520.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 24),
              const _ProfileFooter()
                  .animate(delay: 220.ms)
                  .fadeIn(duration: 480.ms),
            ],
          ),
        ),
      ),
    );
  }

  List<_ProfileAction> _buildActions() {
    return [
      _ProfileAction(
        label: '数据统计',
        icon: Icons.bar_chart,
        onTap: _showDataStatistics,
      ),
      _ProfileAction(
        label: '应用设置',
        icon: Icons.settings,
        onTap: _showSettingsDialog,
      ),
      _ProfileAction(
        label: '检查更新',
        icon: Icons.autorenew,
        onTap: _checkForUpdates,
      ),
      _ProfileAction(
        label: '帮助与反馈',
        icon: Icons.chat_bubble_outline,
        onTap: _showHelpDialog,
      ),
      _ProfileAction(
        label: '关于应用',
        icon: Icons.info_outline,
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
          icon: Icons.bar_chart,
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
        title: '帮助与反馈',
        icon: Icons.chat_bubble_outline,
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

class _ProfileAction {
  const _ProfileAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// 右上角发光头像与身份标签
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                TraceColors.cyan.withOpacity(0.22),
                const Color(0xFF06202A).withOpacity(0.95),
              ],
            ),
            border: Border.all(color: TraceColors.cyan.withOpacity(0.85), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: TraceColors.cyan.withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TraceColors.cyan.withOpacity(0.25)),
            ),
            child: const Icon(Icons.person, color: TraceColors.cyan, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '智能设备用户',
          style: TextStyle(
            color: TraceColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// 中央功能面板：版本头 + 2+3 圆形功能网格
class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.versionHeader,
    required this.actions,
  }) : assert(actions.length == 5);

  final Widget versionHeader;
  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
          decoration: BoxDecoration(
            color: const Color(0xFF071B25).withOpacity(0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TraceColors.cyan.withOpacity(0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: TraceColors.cyan.withOpacity(0.12),
                blurRadius: 34,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: TraceColors.cyan,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: TraceColors.cyan.withOpacity(0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: versionHeader),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final action in actions.sublist(0, 2))
                    TraceGlowNode(
                      size: 88,
                      icon: action.icon,
                      label: action.label,
                      labelWidth: 110,
                      onTap: action.onTap,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final action in actions.sublist(2))
                    TraceGlowNode(
                      size: 72,
                      icon: action.icon,
                      label: action.label,
                      labelWidth: 92,
                      onTap: action.onTap,
                    ),
                ],
              ),
            ],
          ),
        ),
        // 面板顶部中央发光饰线
        Positioned(
          top: -1,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 130,
              height: 2.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    TraceColors.cyan.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: TraceColors.cyan.withOpacity(0.55),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 面板下方标语与装饰
class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildFadeLine(reverse: false)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'BLE Monitor 智能设备管理助手',
                style: TextStyle(
                  color: TraceColors.muted.withOpacity(0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(child: _buildFadeLine(reverse: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final opacity in [0.25, 0.8, 0.25])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TraceColors.cyan.withOpacity(opacity),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFadeLine({required bool reverse}) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.transparent,
            TraceColors.cyan.withOpacity(0.45),
          ],
        ),
      ),
    );
  }
}
