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
            18,
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
              const SizedBox(height: 16),
              _DeviceRadarStage(features: features)
                  .animate(delay: 140.ms)
                  .fadeIn(duration: 620.ms)
                  .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
              const TraceFirstViewportSpacer(consumedHeight: 614),
              _DeviceCommandDeck(features: features)
                  .animate(delay: 360.ms)
                  .fadeIn(duration: 520.ms)
                  .slideY(begin: 0.18, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRadarStage extends StatelessWidget {
  const _DeviceRadarStage({required this.features});

  final List<_DeviceFeature> features;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = math.min(constraints.maxWidth, 390.0);
        final stageHeight = math.max(outerWidth * 1.08, 408.0);

        return Center(
          child: SizedBox(
            width: outerWidth,
            child: TraceGlassPanel(
              padding: const EdgeInsets.all(12),
              borderRadius: 34,
              child: SizedBox(
                height: stageHeight,
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final width = innerConstraints.maxWidth;
                    final height = stageHeight;
                    final nodeSize = math.min(width * 0.25, 88.0);
                    final hubSize = math.min(width * 0.42, 148.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: const TraceOrbitPainter()),
                        ),
                        const Positioned(
                          top: 14,
                          left: 18,
                          child: _OrbitCoordinate(label: 'BLE', value: '04 NODES'),
                        ),
                        const Positioned(
                          right: 18,
                          bottom: 14,
                          child: _OrbitCoordinate(label: 'SYNC', value: 'READY'),
                        ),
                        Positioned(
                          top: 22,
                          left: (width - nodeSize) / 2,
                          child: _RadialDeviceNode(
                            size: nodeSize,
                            feature: features[0],
                            delay: 260,
                          ),
                        ),
                        Positioned(
                          top: (height - nodeSize) / 2,
                          right: 8,
                          child: _RadialDeviceNode(
                            size: nodeSize,
                            feature: features[1],
                            delay: 340,
                          ),
                        ),
                        Positioned(
                          top: (height - nodeSize) / 2,
                          left: 8,
                          child: _RadialDeviceNode(
                            size: nodeSize,
                            feature: features[2],
                            delay: 420,
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: (width - nodeSize) / 2,
                          child: _RadialDeviceNode(
                            size: nodeSize,
                            feature: features[3],
                            delay: 500,
                          ),
                        ),
                        Container(
                          width: hubSize,
                          height: hubSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                TraceColors.cyan.withOpacity(0.34),
                                TraceColors.ocean.withOpacity(0.22),
                                TraceColors.ink.withOpacity(0.96),
                              ],
                            ),
                            border: Border.all(color: TraceColors.cyan.withOpacity(0.42)),
                            boxShadow: [
                              BoxShadow(
                                color: TraceColors.cyan.withOpacity(0.3),
                                blurRadius: 46,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bluetooth_audio, color: TraceColors.cyan, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'TRACE',
                                style: TextStyle(
                                  color: TraceColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
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
}

class _RadialDeviceNode extends StatelessWidget {
  const _RadialDeviceNode({
    required this.size,
    required this.feature,
    required this.delay,
  });

  final double size;
  final _DeviceFeature feature;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.onTap,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF071B25).withOpacity(0.9),
          border: Border.all(color: feature.color.withOpacity(0.48)),
          boxShadow: [
            BoxShadow(
              color: feature.color.withOpacity(0.24),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(feature.icon, color: feature.color, size: 22),
            const SizedBox(height: 8),
            SizedBox(
              width: size - 20,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  feature.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TraceColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              feature.code,
              style: TextStyle(
                color: feature.color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: delay.ms).fadeIn(duration: 420.ms).scale(
          begin: const Offset(0.84, 0.84),
          end: const Offset(1, 1),
        );
  }
}

class _DeviceCommandDeck extends StatelessWidget {
  const _DeviceCommandDeck({required this.features});

  final List<_DeviceFeature> features;

  @override
  Widget build(BuildContext context) {
    return TraceGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '设备入口',
                style: TextStyle(
                  color: TraceColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${features.length} MODULES',
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
          Column(
            children: [
              for (var i = 0; i < features.length; i++) ...[
                _DeviceDeckRow(feature: features[i]),
                if (i != features.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceDeckRow extends StatelessWidget {
  const _DeviceDeckRow({required this.feature});

  final _DeviceFeature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: feature.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: feature.color.withOpacity(0.075),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: feature.color.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(feature.icon, color: feature.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: const TextStyle(
                        color: TraceColors.text,
                        fontSize: 15,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                feature.code,
                style: TextStyle(
                  color: feature.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitCoordinate extends StatelessWidget {
  const _OrbitCoordinate({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: TraceColors.cyan.withOpacity(0.52),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: TraceColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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
