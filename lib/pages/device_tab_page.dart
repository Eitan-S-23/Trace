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
    final features = [
      _DeviceFeature(
        title: '功率计',
        subtitle: '设备功率监控',
        code: '01',
        icon: Icons.electric_meter,
        color: TraceColors.cyan,
        onTap: () => Get.to(() => const PowerMeterPage()),
      ),
      _DeviceFeature(
        title: '码表',
        subtitle: '骑行数据与导航',
        code: '02',
        icon: Icons.speed,
        color: TraceColors.mint,
        onTap: () => Get.to(
          () => const SpeedometerPage(),
          transition: Transition.cupertino,
          duration: const Duration(milliseconds: 300),
        ),
      ),
      _DeviceFeature(
        title: '遥控',
        subtitle: '蓝牙设备控制',
        code: '03',
        icon: Icons.settings_remote,
        color: TraceColors.amber,
        onTap: () => Get.to(() => const RemoteControlPage()),
      ),
      _DeviceFeature(
        title: '即将推出',
        subtitle: '敬请期待',
        code: '04',
        icon: Icons.upcoming,
        color: TraceColors.rose,
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

    return TracePageScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            TraceTheme.bottomNavHeight + 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TracePageTitle(
                eyebrow: 'BLE CONTROL CORE',
                title: '设备中心',
                subtitle: '连接、监控、控制您的蓝牙设备。选择一个轨道节点开始使用。',
                trailing: TracePill(
                  icon: Icons.settings_input_antenna,
                  label: 'TRACE',
                ),
              ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.16, end: 0),
              const SizedBox(height: 18),
              _DeviceOrbit(features: features)
                  .animate(delay: 140.ms)
                  .fadeIn(duration: 620.ms)
                  .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
              const SizedBox(height: 18),
              TraceGlassPanel(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: TraceColors.cyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '功能模块',
                          style: TextStyle(
                            color: TraceColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${features.length} 个入口',
                          style: const TextStyle(
                            color: TraceColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: features
                          .map(
                            (feature) => TracePill(
                              icon: feature.icon,
                              label: feature.title,
                              color: feature.color,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ).animate(delay: 360.ms).fadeIn(duration: 520.ms).slideY(begin: 0.18, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceOrbit extends StatelessWidget {
  const _DeviceOrbit({required this.features});

  final List<_DeviceFeature> features;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 390.0);
        final height = width + 72;
        final nodeWidth = math.min(width * 0.38, 148.0);

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: const TraceOrbitPainter()),
                ),
                _OrbitNode(
                  alignment: const Alignment(0, -0.98),
                  width: nodeWidth,
                  feature: features[0],
                  delay: 260,
                ),
                _OrbitNode(
                  alignment: const Alignment(0.98, -0.05),
                  width: nodeWidth,
                  feature: features[1],
                  delay: 340,
                ),
                _OrbitNode(
                  alignment: const Alignment(-0.98, -0.05),
                  width: nodeWidth,
                  feature: features[2],
                  delay: 420,
                ),
                _OrbitNode(
                  alignment: const Alignment(0, 0.96),
                  width: nodeWidth,
                  feature: features[3],
                  delay: 500,
                ),
                Container(
                  width: width * 0.42,
                  height: width * 0.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        TraceColors.cyan.withOpacity(0.3),
                        TraceColors.ocean.withOpacity(0.22),
                        TraceColors.ink.withOpacity(0.94),
                      ],
                    ),
                    border: Border.all(color: TraceColors.cyan.withOpacity(0.38)),
                    boxShadow: [
                      BoxShadow(
                        color: TraceColors.cyan.withOpacity(0.28),
                        blurRadius: 42,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_audio, color: TraceColors.cyan, size: 34),
                      SizedBox(height: 8),
                      Text(
                        'TRACE',
                        style: TextStyle(
                          color: TraceColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'CONTROL CORE',
                        style: TextStyle(
                          color: TraceColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrbitNode extends StatelessWidget {
  const _OrbitNode({
    required this.alignment,
    required this.width,
    required this.feature,
    required this.delay,
  });

  final Alignment alignment;
  final double width;
  final _DeviceFeature feature;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: feature.onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF071B25).withOpacity(0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: feature.color.withOpacity(0.42)),
            boxShadow: [
              BoxShadow(
                color: feature.color.withOpacity(0.2),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    feature.code,
                    style: TextStyle(
                      color: feature.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Icon(feature.icon, color: feature.color, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                feature.title,
                style: const TextStyle(
                  color: TraceColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                feature.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TraceColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 420.ms).scale(begin: const Offset(0.88, 0.88), end: const Offset(1, 1));
  }
}

class _DeviceFeature {
  const _DeviceFeature({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String code;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
