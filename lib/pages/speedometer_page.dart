import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ride_controller.dart';
import '../models/ride_models.dart';

class SpeedometerPage extends StatelessWidget {
  const SpeedometerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<RideController>()
        ? Get.find<RideController>()
        : Get.put(RideController());

    return Scaffold(
      backgroundColor: _RideColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _Header(controller: controller),
                    const SizedBox(height: 14),
                    _HeroSection(controller: controller),
                    const SizedBox(height: 10),
                    _MetricGrid(controller: controller),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _TrackCard(controller: controller)),
                        const SizedBox(width: 10),
                        Expanded(child: _AltitudeCard(controller: controller)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SpeedTrendCard(controller: controller),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _WeeklyDistanceCard(controller: controller),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MonthlyGoalCard(controller: controller),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _RecentRides(controller: controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomRideBar(controller: controller),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = DateTime.now();
      final subtitle =
          '${now.month}月${now.day}日 ${_two(now.hour)}:${_two(now.minute)} · 晴 25°C · ${controller.gpsStatus.value}';

      return Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFBFE7FF), Color(0xFF4AD66D)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(Icons.directions_bike, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '户外骑行',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: Colors.white, size: 24),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.loadRideHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      );
    });
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final metrics = GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: compact ? 1.45 : 1.1,
            children: [
              _ValueCard(
                label: '平均速度',
                value: controller.avgSpeedKmh.value.toStringAsFixed(1),
                unit: 'km/h',
              ),
              _ValueCard(
                label: '最大速度',
                value: controller.maxSpeedKmh.value.toStringAsFixed(1),
                unit: 'km/h',
              ),
              _ValueCard(
                label: '骑行距离',
                value: controller.distanceKm.value.toStringAsFixed(2),
                unit: 'km',
              ),
              _ValueCard(
                label: '骑行时长',
                value: _formatDuration(controller.elapsed.value),
                unit: 'h:m:s',
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                _SpeedGauge(controller: controller),
                const SizedBox(height: 10),
                metrics,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: _SpeedGauge(controller: controller)),
              const SizedBox(width: 10),
              Expanded(flex: 9, child: metrics),
            ],
          );
        },
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final speed = controller.currentSpeedKmh.value;
      return _Panel(
        padding: const EdgeInsets.all(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _GaugePainter(
              value: (speed / 60).clamp(0.0, 1.0).toDouble(),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '实时速度',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    speed.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 0.98,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    'km/h',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: compact ? 2 : 3,
            childAspectRatio: compact ? 1.78 : 1.16,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _IconMetric(
                icon: Icons.timer,
                color: const Color(0xFF6FA8FF),
                label: '配速',
                value: _formatPace(controller.currentPaceSecondsPerKm.value),
                unit: 'min/km',
              ),
              _IconMetric(
                icon: Icons.landscape,
                color: const Color(0xFF31D56B),
                label: '海拔爬升',
                value: controller.totalClimbM.value.toStringAsFixed(0),
                unit: 'm',
              ),
              _IconMetric(
                icon: Icons.local_fire_department,
                color: const Color(0xFFFF8C35),
                label: '卡路里',
                value: controller.caloriesKcal.value.toString(),
                unit: 'kcal',
              ),
              _IconMetric(
                icon: Icons.favorite,
                color: const Color(0xFFFF5C5C),
                label: '心率',
                value: '--',
                unit: 'bpm',
              ),
              _IconMetric(
                icon: Icons.speed,
                color: const Color(0xFFB65CFF),
                label: '踏频',
                value: '--',
                unit: 'rpm',
              ),
              _IconMetric(
                icon: Icons.bolt,
                color: const Color(0xFFFFD43B),
                label: '功率',
                value: '--',
                unit: 'W',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: 'GPS 轨迹',
        height: 152,
        child: CustomPaint(
          painter: _TrackPainter(points: List<RidePoint>.of(controller.points)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AltitudeCard extends StatelessWidget {
  const _AltitudeCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '海拔曲线',
        height: 152,
        child: _LineChart(
          values: List<double>.of(controller.altitudeTrendM),
          stroke: const Color(0xFF60F050),
          fill: const Color(0xFF39DF52),
          suffix: 'm',
        ),
      ),
    );
  }
}

class _SpeedTrendCard extends StatelessWidget {
  const _SpeedTrendCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '速度变化',
        subtitle: 'km/h',
        height: 154,
        child: _LineChart(
          values: List<double>.of(controller.speedTrendKmh),
          stroke: const Color(0xFF2E78FF),
          fill: const Color(0xFF2758DB),
          suffix: 'km/h',
        ),
      ),
    );
  }
}

class _WeeklyDistanceCard extends StatelessWidget {
  const _WeeklyDistanceCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '里程统计',
        subtitle: 'km',
        height: 168,
        child: _BarChart(values: List<double>.of(controller.weeklyDistancesKm)),
      ),
    );
  }
}

class _MonthlyGoalCard extends StatelessWidget {
  const _MonthlyGoalCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final distance = controller.monthlyDistanceKm.value;
      final goal = controller.monthGoalKm.value;
      final progress = goal <= 0 ? 0.0 : (distance / goal).clamp(0.0, 1.0);
      return _Panel(
        height: 168,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress.toDouble(),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '本月骑行',
                    style: TextStyle(
                      color: Color(0xFFB9C5CF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    distance.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '目标 ${goal.toStringAsFixed(0)} km',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _RecentRides extends StatelessWidget {
  const _RecentRides({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final rides = controller.recentRides.take(3).toList();
        return _Panel(
          title: '骑行记录',
          child: rides.isEmpty
              ? Text(
                  '暂无历史骑行，点击底部开始按钮记录第一段轨迹。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                )
              : Column(
                  children: [
                    for (final ride in rides) _RideRow(ride: ride),
                  ],
                ),
        );
      },
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride});

  final RideSession ride;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF27E363).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.route, color: Color(0xFF36F26C), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ride.startTime.month}/${ride.startTime.day} 户外骑行',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${ride.avgSpeedKmh.toStringAsFixed(1)} km/h · '
                  '${_formatDuration(Duration(seconds: ride.durationSeconds))}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${ride.distanceKm.toStringAsFixed(2)} km',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomRideBar extends StatelessWidget {
  const _BottomRideBar({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111A21).withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _BottomAction(
                icon: Icons.dashboard,
                label: '仪表盘',
                selected: true,
                onTap: controller.loadRideHistory,
              ),
              _BottomAction(
                icon: Icons.analytics_outlined,
                label: '分析',
                onTap: controller.loadRideHistory,
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: controller.isRecording.value
                        ? controller.pauseResume
                        : controller.start,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5DFF70), Color(0xFF21CF55)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF24E461)
                                .withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            controller.isRecording.value &&
                                    !controller.isPaused.value
                                ? Icons.pause
                                : Icons.directions_bike,
                            color: Colors.white,
                            size: 28,
                          ),
                          Text(
                            controller.isRecording.value
                                ? (controller.isPaused.value ? '继续' : '暂停')
                                : '开始',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _BottomAction(
                icon: Icons.save_outlined,
                label: '保存',
                onTap: () => controller.stopAndSave(),
              ),
              _BottomAction(
                icon: Icons.person_outline,
                label: '我的',
                onTap: controller.loadRideHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF65F466) : const Color(0xFF98A4AD);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.title,
    this.subtitle,
    this.height,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Row(
            children: [
              Text(
                title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        if (title != null) const SizedBox(height: 10),
        if (height == null) child else Expanded(child: child),
      ],
    );

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: _RideColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: title == null && height == null ? child : content,
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB8C2CA),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconMetric extends StatelessWidget {
  const _IconMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) * 0.39;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF54616C);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi * 0.76,
        endAngle: math.pi * 2.24,
        colors: [Color(0xFF22C7F4), Color(0xFF31F478), Color(0xFF31F478)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    const start = math.pi * 0.78;
    const sweep = math.pi * 1.46;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      basePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * value,
      false,
      progressPaint,
    );

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2;
    for (var i = 0; i <= 28; i++) {
      final angle = start + sweep * i / 28;
      final p1 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 26);
      final p2 =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 16);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.values,
    required this.stroke,
    required this.fill,
    required this.suffix,
  });

  final List<double> values;
  final Color stroke;
  final Color fill;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(
        values: values,
        stroke: stroke,
        fill: fill,
        suffix: suffix,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.stroke,
    required this.fill,
    required this.suffix,
  });

  final List<double> values;
  final Color stroke;
  final Color fill;
  final String suffix;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final data = values.isEmpty ? _demoLine() : values;
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final span = math.max(maxValue - minValue, 1.0);
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? 0.0 : size.width * i / (data.length - 1);
      final normalized = (data[i] - minValue) / span;
      final y = size.height - normalized * (size.height - 16) - 8;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill.withValues(alpha: 0.5), fill.withValues(alpha: 0.04)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: '${maxValue.toStringAsFixed(maxValue >= 100 ? 0 : 1)} $suffix',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.66),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(size.width - labelPainter.width, 2));
  }

  List<double> _demoLine() {
    return [4, 8, 7, 14, 11, 18, 12, 20, 16, 24, 22, 18, 28, 20, 26];
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.stroke != stroke ||
        oldDelegate.fill != fill;
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(values: values),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final data = values.length == 7 ? values : [42, 70, 54, 90, 66, 80, 118];
    final maxValue = data
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity)
        .toDouble();
    final barWidth = size.width / 10;
    final gap = (size.width - barWidth * 7) / 6;
    final paint = Paint();
    final labels = _lastSevenLabels();

    for (var i = 0; i < data.length; i++) {
      final x = i * (barWidth + gap);
      final h = (size.height - 22) * data[i] / maxValue;
      final rect = Rect.fromLTWH(x, size.height - 22 - h, barWidth, h);
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: i == data.length - 1
            ? [const Color(0xFF9A73FF), const Color(0xFF3678FF)]
            : [const Color(0xFF4D83FF), const Color(0xFF2E6BFF)],
      ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );

      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(x + barWidth / 2 - label.width / 2, size.height - 16),
      );
    }
  }

  List<String> _lastSevenLabels() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return '${day.month}/${day.day}';
    });
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.points});

  final List<RidePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D2630), Color(0xFF111B29)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      bg,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF17F3B3).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + math.sin(i) * 18),
        gridPaint,
      );
    }

    final routePoints = points.length >= 2 ? _mapPoints(size) : _demoRoute(size);
    final route = Path()..moveTo(routePoints.first.dx, routePoints.first.dy);
    for (final point in routePoints.skip(1)) {
      route.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      route,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF21EBD0), Color(0xFF5AF15E), Color(0xFFFF922E)],
        ).createShader(Offset.zero & size)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawPin(canvas, routePoints.first, const Color(0xFF25E2B7));
    _drawPin(canvas, routePoints.last, const Color(0xFFFF563A));
  }

  List<Offset> _mapPoints(Size size) {
    final minLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final latSpan = math.max(maxLat - minLat, 0.0001);
    final lngSpan = math.max(maxLng - minLng, 0.0001);

    return points.map((point) {
      final x = (point.longitude - minLng) / lngSpan * (size.width - 22) + 11;
      final y = size.height -
          ((point.latitude - minLat) / latSpan * (size.height - 22) + 11);
      return Offset(x, y);
    }).toList();
  }

  List<Offset> _demoRoute(Size size) {
    return [
      Offset(size.width * 0.12, size.height * 0.78),
      Offset(size.width * 0.25, size.height * 0.58),
      Offset(size.width * 0.34, size.height * 0.42),
      Offset(size.width * 0.48, size.height * 0.55),
      Offset(size.width * 0.58, size.height * 0.37),
      Offset(size.width * 0.74, size.height * 0.62),
      Offset(size.width * 0.88, size.height * 0.34),
    ];
  }

  void _drawPin(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 8, Paint()..color = color);
    canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF52616B);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFF5AF55C), Color(0xFF28D9F5), Color(0xFF5AF55C)],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi * 0.8, math.pi * 1.6, false, base);
    canvas.drawArc(
      rect,
      math.pi * 0.8,
      math.pi * 1.6 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RideColors {
  static const background = Color(0xFF071018);
  static const panel = Color(0xFF141F28);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
}

String _formatPace(double secondsPerKm) {
  if (secondsPerKm <= 0 || !secondsPerKm.isFinite) return '--:--';
  final minutes = secondsPerKm ~/ 60;
  final seconds = secondsPerKm.round().remainder(60);
  return '$minutes:${_two(seconds)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
