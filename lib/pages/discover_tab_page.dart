import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'trace_ui.dart';

class DiscoverTabPage extends StatelessWidget {
  const DiscoverTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions();

    return TracePageScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stageWidth = math.min(constraints.maxWidth - 8, 430.0);
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
                      eyebrow: 'DISCOVERY RADAR',
                      title: '发现',
                      subtitle: '查看现有蓝牙能力、使用指南和更新说明',
                      trailing: TracePill(
                        icon: Icons.travel_explore,
                        label: 'GUIDE',
                      ),
                    ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.14, end: 0),
                    SizedBox(height: compact ? 16 : 24),
                    Center(
                      child: SizedBox(
                        width: stageWidth,
                        child: TraceRadialConsole(
                          centerTitle: '发现雷达',
                          centerSubtitle: 'LOCAL GUIDE',
                          centerIcon: Icons.travel_explore,
                          badgeLabel: 'DISCOVER',
                          footerLabel: 'LOCAL',
                          primaryColor: TraceColors.mint,
                          actions: actions,
                        ),
                      ),
                    )
                        .animate(delay: 110.ms)
                        .fadeIn(duration: 520.ms)
                        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<TraceOrbitAction> _buildActions() {
    return [
      TraceOrbitAction(
        title: '功率指南',
        subtitle: '功率计监控流程',
        code: '01',
        icon: Icons.electric_meter,
        color: TraceColors.cyan,
        onTap: () => _showGuideDialog(
          '功率计使用指南',
          const [
            '从设备页进入功率计。',
            '扫描并选择 BLE 设备。',
            '进入监控后可保存设备，便于长期查看。',
          ],
        ),
      ),
      TraceOrbitAction(
        title: '码表入门',
        subtitle: '骑行数据与 OTA',
        code: '02',
        icon: Icons.speed,
        color: TraceColors.cyanSoft,
        onTap: () => _showGuideDialog(
          '码表入门',
          const [
            '从设备页进入码表。',
            '连接码表设备后查看实时骑行数据。',
            '需要升级时在码表功能内执行 OTA。',
          ],
        ),
      ),
      TraceOrbitAction(
        title: '遥控教程',
        subtitle: '蓝牙指令控制',
        code: '03',
        icon: Icons.settings_remote,
        color: TraceColors.mint,
        onTap: () => _showGuideDialog(
          '遥控教程',
          const [
            '从设备页进入遥控。',
            '连接蓝牙设备后配置控制按钮。',
            '点击按钮发送对应控制指令。',
          ],
        ),
      ),
      TraceOrbitAction(
        title: '更新说明',
        subtitle: '应用版本维护',
        code: '04',
        icon: Icons.system_update_alt,
        color: TraceColors.amber,
        onTap: () => _showGuideDialog(
          '更新说明',
          const [
            '检查更新入口位于“我的”页面。',
            '更新服务只负责应用版本维护。',
            '发现页只展示现有功能说明。',
          ],
        ),
      ),
    ];
  }

  static void _showGuideDialog(String title, List<String> lines) {
    Get.dialog<void>(
      TraceDialog(
        title: title,
        icon: Icons.travel_explore,
        color: TraceColors.mint,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              Text('${i + 1}. ${lines[i]}'),
              if (i != lines.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          TraceDialogAction(
            label: '确定',
            isPrimary: true,
            color: TraceColors.mint,
            onPressed: TraceDialog.close,
          ),
        ],
      ),
      barrierColor: Colors.black.withOpacity(0.62),
    );
  }
}
