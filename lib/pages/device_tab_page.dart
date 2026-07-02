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
    return TracePageScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final stageWidth = math.min(constraints.maxWidth - 36, 380.0);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                18,
                compact ? 20 : 30,
                18,
                TraceTheme.bottomNavHeight + 24,
              ),
              child: Column(
                children: [
                  const Text(
                    '设备',
                    style: TextStyle(
                      color: TraceColors.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      shadows: [
                        Shadow(color: Color(0x8824F6DE), blurRadius: 22),
                      ],
                    ),
                  ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.14, end: 0),
                  const SizedBox(height: 10),
                  Text(
                    '连接、监控、控制您的蓝牙设备',
                    style: TextStyle(
                      color: TraceColors.muted.withOpacity(0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  )
                      .animate(delay: 60.ms)
                      .fadeIn(duration: 420.ms)
                      .slideY(begin: 0.2, end: 0),
                  SizedBox(height: compact ? 10 : 22),
                  _DeviceStage(width: stageWidth)
                      .animate(delay: 120.ms)
                      .fadeIn(duration: 520.ms)
                      .scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1, 1),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceStage extends StatelessWidget {
  const _DeviceStage({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final geometry = _DeviceStageGeometry(width);
    final actions = _buildActions();

    return SizedBox(
      width: geometry.width,
      height: geometry.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DeviceStagePainter(geometry)),
          ),
          for (var i = 0; i < actions.length; i++)
            Positioned(
              left: geometry.satellites[i].dx - geometry.nodeSize * 0.95,
              top: geometry.satellites[i].dy - geometry.nodeSize / 2,
              width: geometry.nodeSize * 1.9,
              child: TraceGlowNode(
                size: geometry.nodeSize,
                icon: actions[i].icon,
                label: actions[i].title,
                sublabel: actions[i].subtitle,
                labelWidth: geometry.nodeSize * 1.9,
                onTap: actions[i].onTap,
              ),
            ),
          Positioned(
            left: geometry.core.dx - geometry.coreSize / 2,
            top: geometry.core.dy - geometry.coreSize / 2,
            child: _DeviceCore(size: geometry.coreSize),
          ),
        ],
      ),
    );
  }

  List<_DeviceAction> _buildActions() {
    return [
      _DeviceAction(
        title: '功率计',
        subtitle: '设备功率监控',
        icon: Icons.bolt,
        onTap: () => Get.to(() => const PowerMeterPage()),
      ),
      _DeviceAction(
        title: '码表',
        subtitle: '骑行数据与导航',
        icon: Icons.directions_bike,
        onTap: () => Get.to(
          () => const SpeedometerPage(),
          transition: Transition.cupertino,
          duration: const Duration(milliseconds: 300),
        ),
      ),
      _DeviceAction(
        title: '遥控',
        subtitle: '蓝牙设备控制',
        icon: Icons.settings_remote,
        onTap: () => Get.to(() => const RemoteControlPage()),
      ),
      _DeviceAction(
        title: '即将推出',
        subtitle: '敬请期待',
        icon: Icons.hourglass_bottom,
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

class _DeviceAction {
  const _DeviceAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

/// 舞台几何：核心与四个对角卫星共用的一套坐标，painter 与布局保持一致
class _DeviceStageGeometry {
  _DeviceStageGeometry(this.width)
      : height = width * 1.06,
        coreSize = width * 0.435,
        nodeSize = width * 0.185,
        orbitRadius = width * 0.375,
        core = Offset(width / 2, width * 1.06 * 0.42) {
    const diagonal = math.pi / 4;
    final offsets = [
      Offset(-math.cos(diagonal), -math.sin(diagonal)), // 左上
      Offset(math.cos(diagonal), -math.sin(diagonal)), // 右上
      Offset(-math.cos(diagonal), math.sin(diagonal)), // 左下
      Offset(math.cos(diagonal), math.sin(diagonal)), // 右下
    ];
    satellites = offsets
        .map((direction) => core + direction * orbitRadius)
        .toList(growable: false);
  }

  final double width;
  final double height;
  final double coreSize;
  final double nodeSize;
  final double orbitRadius;
  final Offset core;
  late final List<Offset> satellites;
}

class _DeviceStagePainter extends CustomPainter {
  const _DeviceStagePainter(this.geometry);

  final _DeviceStageGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final center = geometry.core;

    // 核心外围大光晕
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          TraceColors.cyan.withOpacity(0.2),
          TraceColors.ocean.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: geometry.orbitRadius * 1.3),
      );
    canvas.drawCircle(center, geometry.orbitRadius * 1.3, glowPaint);

    // 穿过卫星圆心的轨道圆
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = TraceColors.cyan.withOpacity(0.16);
    canvas.drawCircle(center, geometry.orbitRadius, orbitPaint);
    canvas.drawCircle(center, geometry.orbitRadius * 1.14, orbitPaint..color = TraceColors.cyan.withOpacity(0.08));

    // 核心 → 卫星 对角连接线（青色渐隐）
    for (final satellite in geometry.satellites) {
      final direction = (satellite - center) / (satellite - center).distance;
      final start = center + direction * (geometry.coreSize * 0.52);
      final end = satellite - direction * (geometry.nodeSize * 0.56);
      final linkPaint = Paint()
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          colors: [
            TraceColors.cyan.withOpacity(0.55),
            TraceColors.cyan.withOpacity(0.1),
          ],
        ).createShader(Rect.fromPoints(start, end));
      canvas.drawLine(start, end, linkPaint);

      // 连接线中点光珠
      final midpoint = Offset.lerp(start, end, 0.5)!;
      canvas.drawCircle(
        midpoint,
        1.8,
        Paint()..color = TraceColors.cyanSoft.withOpacity(0.55),
      );
    }

    // 固定种子散布光点
    final random = math.Random(28);
    final dotPaint = Paint();
    for (int i = 0; i < 26; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final radius = geometry.orbitRadius * (0.5 + random.nextDouble() * 0.75);
      final position = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      dotPaint.color = TraceColors.cyanSoft
          .withOpacity(0.08 + random.nextDouble() * 0.3);
      canvas.drawCircle(position, 0.7 + random.nextDouble() * 1.3, dotPaint);
    }

    // 舞台底部地面反射光
    final floorPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          TraceColors.cyan.withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.99),
          width: size.width * 1.1,
          height: size.height * 0.24,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.99),
        width: size.width * 1.1,
        height: size.height * 0.24,
      ),
      floorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DeviceStagePainter oldDelegate) {
    return oldDelegate.geometry.width != geometry.width;
  }
}

/// 中央“设备中心”核心：强发光青环 + 深色盘面 + 蓝牙圆钮
class _DeviceCore extends StatelessWidget {
  const _DeviceCore({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TraceColors.cyan, width: 3),
        boxShadow: [
          BoxShadow(
            color: TraceColors.cyan.withOpacity(0.55),
            blurRadius: 34,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: TraceColors.cyan.withOpacity(0.22),
            blurRadius: 80,
            spreadRadius: 14,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color(0xFF0D3844),
              Color(0xFF072028),
              Color(0xFF03141B),
            ],
            stops: [0, 0.6, 1],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 盘面同心装饰环
            Container(
              margin: EdgeInsets.all(size * 0.075),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TraceColors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.all(size * 0.14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TraceColors.cyan.withOpacity(0.14),
                  width: 1,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '设备中心',
                  style: TextStyle(
                    color: TraceColors.text,
                    fontSize: size * 0.115,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: const [
                      Shadow(color: Color(0x9924F6DE), blurRadius: 16),
                    ],
                  ),
                ),
                SizedBox(height: size * 0.075),
                Container(
                  width: size * 0.2,
                  height: size * 0.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF041A22),
                    border: Border.all(
                      color: TraceColors.cyan.withOpacity(0.65),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TraceColors.cyan.withOpacity(0.4),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    color: TraceColors.cyan,
                    size: size * 0.11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
