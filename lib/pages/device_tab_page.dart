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
      paintBackground: false,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final stageWidth = math.min(
              math.max(0.0, constraints.maxWidth - 8),
              420.0,
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                0,
                compact ? 16 : 30,
                0,
                TraceTheme.pageBottomPadding,
              ),
              child: Column(
                children: [
                  const _DeviceTitle()
                      .animate()
                      .fadeIn(duration: 420.ms)
                      .slideY(begin: 0.14, end: 0),
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    '连接、监控、控制您的蓝牙设备',
                    style: TextStyle(
                      color: TraceColors.cyanSoft.withOpacity(0.86),
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  )
                      .animate(delay: 60.ms)
                      .fadeIn(duration: 420.ms)
                      .slideY(begin: 0.2, end: 0),
                  SizedBox(height: compact ? 18 : 26),
                  Center(
                    child: _DeviceStage(width: stageWidth),
                  )
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

class _DeviceTitle extends StatelessWidget {
  const _DeviceTitle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 58,
            right: 58,
            top: 42,
            child: Row(
              children: [
                Expanded(child: _titleBeam(reverse: false)),
                const SizedBox(width: 174),
                Expanded(child: _titleBeam(reverse: true)),
              ],
            ),
          ),
          const Text(
            '设备',
            style: TextStyle(
              color: TraceColors.text,
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              shadows: [
                Shadow(color: Color(0xAA24F6DE), blurRadius: 24),
                Shadow(color: Color(0x6624F6DE), blurRadius: 42),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBeam({required bool reverse}) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.transparent,
            TraceColors.cyan.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: TraceColors.cyan.withOpacity(0.55),
            blurRadius: 10,
          ),
        ],
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
              left: geometry.satellites[i].dx - geometry.nodeSize * 0.68,
              top: geometry.satellites[i].dy - geometry.nodeSize * 0.68,
              child: TraceGlowNode(
                size: geometry.nodeSize,
                icon: actions[i].icon,
                semanticLabel: '${actions[i].title} ${actions[i].subtitle}',
                onTap: actions[i].onTap,
              ),
            ),
          for (var i = 0; i < actions.length; i++)
            Positioned(
              left: geometry.labels[i].left,
              top: geometry.labels[i].top,
              width: geometry.labels[i].width,
              child: _DeviceNodeLabel(
                title: actions[i].title,
                subtitle: actions[i].subtitle,
                alignment: geometry.labels[i].alignment,
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

class _DeviceLabelGeometry {
  const _DeviceLabelGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.alignment,
  });

  final double left;
  final double top;
  final double width;
  final TextAlign alignment;
}

class _DeviceNodeLabel extends StatelessWidget {
  const _DeviceNodeLabel({
    required this.title,
    required this.subtitle,
    required this.alignment,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final TextAlign alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: alignment == TextAlign.left
            ? CrossAxisAlignment.start
            : alignment == TextAlign.right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment == TextAlign.left
                ? Alignment.centerLeft
                : alignment == TextAlign.right
                    ? Alignment.centerRight
                    : Alignment.center,
            child: Text(
              title,
              textAlign: alignment,
              maxLines: 1,
              style: const TextStyle(
                color: TraceColors.text,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Color(0x9924F6DE), blurRadius: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: alignment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TraceColors.muted.withOpacity(0.9),
              fontSize: 10.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 舞台几何：核心、四个对角卫星和外侧标签共用的一套坐标
class _DeviceStageGeometry {
  _DeviceStageGeometry(this.width)
      : height = width * 1.34,
        coreSize = width * 0.48,
        nodeSize = width * 0.19,
        orbitRadius = width * 0.445,
        core = Offset(width / 2, width * 1.34 * 0.51) {
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

    final gutter = width * 0.02;
    final sideWidth = width * 0.27;
    final rightLabelLeft = width - sideWidth - gutter;
    final topY = satellites[0].dy + nodeSize * 0.28;
    final bottomY = satellites[2].dy + nodeSize * 0.9;

    labels = [
      _DeviceLabelGeometry(
        left: gutter,
        top: topY,
        width: sideWidth,
        alignment: TextAlign.left,
      ),
      _DeviceLabelGeometry(
        left: rightLabelLeft,
        top: topY,
        width: sideWidth,
        alignment: TextAlign.right,
      ),
      _DeviceLabelGeometry(
        left: gutter,
        top: bottomY,
        width: sideWidth,
        alignment: TextAlign.left,
      ),
      _DeviceLabelGeometry(
        left: rightLabelLeft,
        top: bottomY,
        width: sideWidth,
        alignment: TextAlign.right,
      ),
    ];
  }

  final double width;
  final double height;
  final double coreSize;
  final double nodeSize;
  final double orbitRadius;
  final Offset core;
  late final List<Offset> satellites;
  late final List<_DeviceLabelGeometry> labels;
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

    // 穿过卫星圆心的机械轨道圆
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = TraceColors.cyan.withOpacity(0.16);
    canvas.drawCircle(center, geometry.orbitRadius, orbitPaint);
    canvas.drawCircle(
      center,
      geometry.orbitRadius * 1.14,
      orbitPaint..color = TraceColors.cyan.withOpacity(0.09),
    );
    canvas.drawCircle(
      center,
      geometry.orbitRadius * 0.78,
      orbitPaint..color = TraceColors.cyan.withOpacity(0.1),
    );
    canvas.drawCircle(
      center,
      geometry.orbitRadius * 0.64,
      orbitPaint..color = TraceColors.cyan.withOpacity(0.08),
    );

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = TraceColors.cyan.withOpacity(0.36);
    for (var i = 0; i < 112; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 112;
      final major = i % 14 == 0;
      tickPaint.strokeWidth = major ? 1.2 : 0.75;
      final outer = geometry.orbitRadius * 0.93;
      final inner = geometry.orbitRadius * (major ? 0.8 : 0.86);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    // 核心 → 卫星 机械连接臂
    for (final satellite in geometry.satellites) {
      final direction = (satellite - center) / (satellite - center).distance;
      final perpendicular = Offset(-direction.dy, direction.dx);
      final start = center + direction * (geometry.coreSize * 0.5);
      final end = satellite - direction * (geometry.nodeSize * 0.58);

      final armBodyPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = geometry.width * 0.032
        ..color = TraceColors.ocean.withOpacity(0.54);
      canvas.drawLine(start, end, armBodyPaint);

      final armEdgePaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4
        ..color = TraceColors.cyan.withOpacity(0.34);
      canvas.drawLine(
        start + perpendicular * geometry.width * 0.014,
        end + perpendicular * geometry.width * 0.014,
        armEdgePaint,
      );
      canvas.drawLine(
        start - perpendicular * geometry.width * 0.014,
        end - perpendicular * geometry.width * 0.014,
        armEdgePaint..color = TraceColors.cyan.withOpacity(0.22),
      );

      final linkPaint = Paint()
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          colors: [
            TraceColors.cyan.withOpacity(0.68),
            TraceColors.cyan.withOpacity(0.16),
          ],
        ).createShader(Rect.fromPoints(start, end));
      canvas.drawLine(start, end, linkPaint);

      for (final anchor in [0.16, 0.84]) {
        final joint = Offset.lerp(start, end, anchor)!;
        canvas.drawLine(
          joint - perpendicular * geometry.width * 0.028,
          joint + perpendicular * geometry.width * 0.028,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2
            ..color = TraceColors.cyanSoft.withOpacity(0.42),
        );
        canvas.drawCircle(
          joint,
          geometry.width * 0.012,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = TraceColors.cyan.withOpacity(0.6),
        );
      }

      final midpoint = Offset.lerp(start, end, 0.5)!;
      canvas.drawCircle(
        midpoint,
        2.2,
        Paint()..color = TraceColors.cyanSoft.withOpacity(0.55),
      );
    }

    final cardinalPaint = Paint()..color = TraceColors.cyanSoft.withOpacity(0.9);
    for (final angle in const [
      -math.pi / 2,
      0.0,
      math.pi / 2,
      math.pi,
    ]) {
      final point = center + Offset(math.cos(angle), math.sin(angle)) * geometry.orbitRadius;
      canvas.drawCircle(point, 3.2, cardinalPaint);
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
            CustomPaint(
              size: Size.square(size),
              painter: _DeviceCoreDialPainter(),
            ),
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
                    fontSize: size * 0.15,
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

class _DeviceCoreDialPainter extends CustomPainter {
  const _DeviceCoreDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = TraceColors.cyanSoft.withOpacity(0.22);

    for (var i = 0; i < 96; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 96;
      final major = i % 12 == 0;
      tickPaint.strokeWidth = major ? 1.2 : 0.65;
      final outer = radius * 0.96;
      final inner = radius * (major ? 0.83 : 0.88);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          TraceColors.cyan.withOpacity(0.18),
          TraceColors.cyanSoft.withOpacity(0.45),
          Colors.transparent,
        ],
        stops: const [0, 0.18, 0.32, 0.55],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.74));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -math.pi * 0.98,
      math.pi * 1.42,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DeviceCoreDialPainter oldDelegate) => false;
}
