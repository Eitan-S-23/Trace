import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'power_meter_page.dart';
import 'remote_control_page.dart';
import 'speedometer_page.dart';
import 'trace_ui.dart';

class DeviceTabPage extends StatelessWidget {
  const DeviceTabPage({super.key});

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
                      eyebrow: 'DEVICE CORE',
                      title: '设备',
                      subtitle: '连接、监控、控制您的蓝牙设备',
                      trailing: TracePill(
                        icon: Icons.settings_input_antenna,
                        label: 'BLE',
                      ),
                    ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.14, end: 0),
                    SizedBox(height: compact ? 16 : 24),
                    Center(
                      child: SizedBox(
                        width: stageWidth,
                        child: TraceRadialConsole(
                          centerTitle: '设备中心',
                          centerSubtitle: 'CONTROL CORE',
                          centerIcon: Icons.bluetooth_audio,
                          badgeLabel: 'TRACE',
                          footerLabel: 'BLE LINK',
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
        title: '功率计',
        subtitle: '设备功率监控',
        code: '01',
        icon: Icons.electric_meter,
        color: TraceColors.cyan,
        onTap: () => Get.to(() => const PowerMeterPage()),
      ),
      TraceOrbitAction(
        title: '码表',
        subtitle: '骑行数据与导航',
        code: '02',
        icon: Icons.speed,
        color: TraceColors.cyanSoft,
        onTap: () => Get.to(
          () => const SpeedometerPage(),
          transition: Transition.cupertino,
          duration: const Duration(milliseconds: 300),
        ),
      ),
      TraceOrbitAction(
        title: '遥控',
        subtitle: '蓝牙设备控制',
        code: '03',
        icon: Icons.settings_remote,
        color: TraceColors.mint,
        onTap: () => Get.to(() => const RemoteControlPage()),
      ),
      TraceOrbitAction(
        title: '即将推出',
        subtitle: '新模块预留',
        code: '04',
        icon: Icons.upcoming,
        color: TraceColors.amber,
        onTap: () => Get.snackbar(
          '提示',
          '功能开发中，敬请期待',
          snackPosition: SnackPosition.TOP,
          backgroundColor: TraceColors.deep,
          colorText: TraceColors.text,
          icon: const Icon(Icons.construction, color: TraceColors.amber),
        ),
      ),
    ];
  }
}
