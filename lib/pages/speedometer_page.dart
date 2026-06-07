import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ride_controller.dart';
import '../models/ride_models.dart';

class SpeedometerPage extends StatefulWidget {
  const SpeedometerPage({super.key});

  @override
  State<SpeedometerPage> createState() => _SpeedometerPageState();
}

class _SpeedometerPageState extends State<SpeedometerPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(RideController controller, int index) {
    controller.selectTab(index);
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<RideController>()
        ? Get.find<RideController>()
        : Get.put(RideController());

    return Scaffold(
      backgroundColor: _RideColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () {
                  final selectedIndex = controller.activeTabIndex.value;
                  return ListView(
                    key: PageStorageKey<String>('ride-tab-$selectedIndex'),
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: _buildPageChildren(controller, selectedIndex),
                  );
                },
              ),
            ),
            _RideTabBar(
              controller: controller,
              onSelect: (index) => _selectTab(controller, index),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageChildren(
    RideController controller,
    int selectedIndex,
  ) {
    final children = <Widget>[
      _Header(controller: controller),
      const SizedBox(height: 14),
    ];

    switch (selectedIndex) {
      case 1:
        children.addAll(_buildAnalysisContent(controller));
        break;
      case 2:
        children.addAll(_buildRecordContent(controller));
        break;
      case 3:
        children.addAll(_buildProfileContent(controller));
        break;
      case 0:
      default:
        children.addAll(_buildDashboardContent(controller));
    }

    return children;
  }

  List<Widget> _buildDashboardContent(RideController controller) {
    return [
      _HeroSection(controller: controller),
      const SizedBox(height: 10),
      _MetricGrid(controller: controller),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              children: [
                _TrackCard(controller: controller),
                const SizedBox(height: 10),
                _AltitudeCard(controller: controller),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _TrackCard(controller: controller)),
              const SizedBox(width: 10),
              Expanded(child: _AltitudeCard(controller: controller)),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      _SpeedTrendCard(controller: controller),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              children: [
                _WeeklyDistanceCard(controller: controller),
                const SizedBox(height: 10),
                _MonthlyGoalCard(controller: controller),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 7,
                child: _WeeklyDistanceCard(controller: controller),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _MonthlyGoalCard(controller: controller),
              ),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildAnalysisContent(RideController controller) {
    return [
      _AnalysisSummaryCard(controller: controller),
      const SizedBox(height: 10),
      _SpeedTrendCard(controller: controller),
      const SizedBox(height: 10),
      _WeeklyDistanceCard(controller: controller),
      const SizedBox(height: 10),
      _MonthlyGoalCard(controller: controller),
      const SizedBox(height: 10),
      _RecentRides(controller: controller),
    ];
  }

  List<Widget> _buildRecordContent(RideController controller) {
    return [
      _SaveRideCard(controller: controller),
      const SizedBox(height: 10),
      _RecentRides(controller: controller),
    ];
  }

  List<Widget> _buildProfileContent(RideController controller) {
    return [
      _ProfileSummaryCard(controller: controller),
      const SizedBox(height: 10),
      _MonthlyGoalCard(controller: controller),
      const SizedBox(height: 10),
      _RecentRides(controller: controller),
    ];
  }
}

class _DesignHeader extends StatelessWidget {
  const _DesignHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 22,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已连接',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'iGPSPORT BSC300',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '码表',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.cloud_sync_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesignSectionTabs extends StatelessWidget {
  const _DesignSectionTabs({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['活动', '统计', '训练', '路线', '设备'];
    const mappedTabs = [0, 1, 1, 2, 3];
    final activeTopIndex = switch (selectedIndex) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < labels.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(mappedTabs[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: i == activeTopIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.58),
                      fontSize: 16,
                      fontWeight:
                          i == activeTopIndex ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == activeTopIndex ? 24 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _RideColors.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityHeroCard extends StatelessWidget {
  const _ActivityHeroCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasRide = controller.distanceKm.value > 0 ||
          controller.elapsed.value > Duration.zero;
      final distance = hasRide
          ? controller.distanceKm.value.toStringAsFixed(2)
          : '102.63';
      final duration =
          hasRide ? _formatDuration(controller.elapsed.value) : '03:45:28';
      final avgSpeed = hasRide
          ? controller.avgSpeedKmh.value.toStringAsFixed(1)
          : '27.3';
      final climb = hasRide
          ? controller.totalClimbM.value.toStringAsFixed(0)
          : '1268';

      return Container(
        height: 252,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _RideColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 52,
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _RoutePreviewPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 10,
              child: Column(
                children: [
                  _FloatingRoundIcon(icon: Icons.fullscreen),
                  const SizedBox(height: 14),
                  _FloatingRoundIcon(icon: Icons.share_outlined),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_bike,
                      color: _RideColors.orange,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '户外骑行',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '2024/05/18  08:32',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: distance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          height: 0.95,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.2,
                        ),
                      ),
                      TextSpan(
                        text: ' km',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _HeroStat(label: '运动时间', value: duration, unit: ''),
                    const SizedBox(width: 22),
                    _HeroStat(label: '平均速度', value: avgSpeed, unit: 'km/h'),
                    const SizedBox(width: 22),
                    _HeroStat(label: '累计爬升', value: climb, unit: 'm'),
                    const SizedBox(width: 22),
                    const _HeroStat(label: '训练负荷', value: '187', unit: '高'),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFCB2D),
                      ),
                      child: const Center(
                        child: Text(
                          'PR',
                          style: TextStyle(
                            color: Color(0xFF1B1B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '个人新纪录！',
                            style: TextStyle(
                              color: Color(0xFFFFD84A),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '最长距离  ${distance}km',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '查看详情',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _FloatingRoundIcon extends StatelessWidget {
  const _FloatingRoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 21),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: unit == '高'
                          ? const Color(0xFFE34CFF)
                          : Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

class _DesignMetricGrid extends StatelessWidget {
  const _DesignMetricGrid({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 6.0;
        final columns = constraints.maxWidth < 360 ? 2 : 3;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Obx(
          () {
            final speed = controller.avgSpeedKmh.value > 0
                ? controller.avgSpeedKmh.value.toStringAsFixed(1)
                : '27.3';
            final climb = controller.totalClimbM.value > 0
                ? controller.totalClimbM.value.toStringAsFixed(0)
                : '1268';

            final cards = [
              _DesignMetricCard(
                icon: Icons.speed,
                color: const Color(0xFF2088FF),
                title: '平均速度',
                value: speed,
                unit: 'km/h',
                footnote: '最高 52.6 km/h',
              ),
              const _DesignMetricCard(
                icon: Icons.bolt,
                color: Color(0xFF62D729),
                title: '平均功率',
                value: '186',
                unit: 'w',
                footnote: '最大 562 w',
              ),
              const _DesignMetricCard(
                icon: Icons.favorite,
                color: Color(0xFFFF385E),
                title: '平均心率',
                value: '156',
                unit: 'bpm',
                footnote: '最大 188 bpm',
              ),
              const _DesignMetricCard(
                icon: Icons.track_changes,
                color: Color(0xFFFFC400),
                title: '平均踏频',
                value: '87',
                unit: 'rpm',
                footnote: '最高 118 rpm',
              ),
              _DesignMetricCard(
                icon: Icons.terrain,
                color: const Color(0xFFA533FF),
                title: '累计爬升',
                value: climb,
                unit: 'm',
                footnote: '总上升 $climb m',
              ),
              const _DesignMetricCard(
                icon: Icons.thermostat,
                color: Color(0xFF42D8E6),
                title: '平均温度',
                value: '22.4',
                unit: '°C',
                footnote: '最高 28.6 °C',
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        );
      },
    );
  }
}

class _DesignMetricCard extends StatelessWidget {
  const _DesignMetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    required this.footnote,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _RideColors.panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.46),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 22,
            child: CustomPaint(
              painter: _SparklinePainter(color: color),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedAltitudeCard extends StatelessWidget {
  const _SpeedAltitudeCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final speed = controller.avgSpeedKmh.value > 0
          ? controller.avgSpeedKmh.value.toStringAsFixed(1)
          : '27.3';
      final climb = controller.totalClimbM.value > 0
          ? controller.totalClimbM.value.toStringAsFixed(0)
          : '1268';

      return _Panel(
        title: '速度 & 海拔',
        height: 218,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Spacer(),
                Text(
                  '平均 ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$speed km/h',
                  style: const TextStyle(
                    color: Color(0xFF2A9CFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  '累计爬升 ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$climb m',
                  style: const TextStyle(
                    color: Color(0xFFA533FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomPaint(
                painter: _DualLineChartPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _DistributionCards extends StatelessWidget {
  const _DistributionCards({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final children = [
          const _ZoneDistributionCard(
            title: '功率分布',
            summary: '平均功率 186 w',
            colors: [
              Color(0xFFFF3158),
              Color(0xFFFF7A1A),
              Color(0xFFFFD21A),
              Color(0xFF4AD14A),
              Color(0xFF268DFF),
            ],
            labels: ['Z5 > 350 w', 'Z4 250 - 350 w', 'Z3 180 - 250 w', 'Z2 120 - 180 w', 'Z1 < 120 w'],
            values: ['12:15  11%', '28:47  26%', '40:21  36%', '32:16  18%', '12:09  9%'],
          ),
          const _ZoneDistributionCard(
            title: '心率分布',
            summary: '平均心率 156 bpm',
            colors: [
              Color(0xFFFF3158),
              Color(0xFFFF7A1A),
              Color(0xFFFFD21A),
              Color(0xFF4AD14A),
              Color(0xFF268DFF),
            ],
            labels: ['Z5 > 178 bpm', 'Z4 160 - 178 bpm', 'Z3 140 - 160 bpm', 'Z2 120 - 140 bpm', 'Z1 < 120 bpm'],
            values: ['08:36  6%', '26:18  17%', '55:21  36%', '48:23  31%', '11:10  10%'],
          ),
        ];

        if (compact) {
          return Column(
            children: [
              children[0],
              const SizedBox(height: 6),
              children[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 6),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class _ZoneDistributionCard extends StatelessWidget {
  const _ZoneDistributionCard({
    required this.title,
    required this.summary,
    required this.colors,
    required this.labels,
    required this.values,
  });

  final String title;
  final String summary;
  final List<Color> colors;
  final List<String> labels;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _RideColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                summary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: _DonutPainter(colors: colors),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              values[i],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                    ],
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

class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF161B28).withValues(alpha: 0.92),
          const Color(0xFF10141E).withValues(alpha: 0.92),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thinRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.026)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.18 + i * 0.18);
      final path = Path()
        ..moveTo(-20, y)
        ..cubicTo(
          size.width * 0.25,
          y - 24,
          size.width * 0.55,
          y + 26,
          size.width + 20,
          y - 10,
        );
      canvas.drawPath(path, i.isEven ? roadPaint : thinRoadPaint);
    }

    final route = [
      Offset(size.width * 0.62, size.height * 0.08),
      Offset(size.width * 0.50, size.height * 0.20),
      Offset(size.width * 0.42, size.height * 0.34),
      Offset(size.width * 0.31, size.height * 0.40),
      Offset(size.width * 0.42, size.height * 0.56),
      Offset(size.width * 0.56, size.height * 0.52),
      Offset(size.width * 0.72, size.height * 0.62),
      Offset(size.width * 0.64, size.height * 0.78),
      Offset(size.width * 0.48, size.height * 0.88),
      Offset(size.width * 0.39, size.height * 0.70),
      Offset(size.width * 0.24, size.height * 0.58),
      Offset(size.width * 0.28, size.height * 0.38),
      Offset(size.width * 0.46, size.height * 0.28),
      Offset(size.width * 0.62, size.height * 0.08),
    ];

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(route.first.dx, route.first.dy);
    for (final point in route.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, shadow);

    for (var i = 0; i < route.length - 1; i++) {
      final segmentPath = Path()
        ..moveTo(route[i].dx, route[i].dy)
        ..lineTo(route[i + 1].dx, route[i + 1].dy);
      final t = i / (route.length - 2);
      final color = Color.lerp(
        const Color(0xFF48D84B),
        const Color(0xFFFF4B24),
        t,
      )!;
      canvas.drawPath(
        segmentPath,
        Paint()
          ..color = color
          ..strokeWidth = 5.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.drawCircle(
      route.first,
      8,
      Paint()..color = const Color(0xFF5AE353),
    );
    canvas.drawCircle(
      route.first,
      4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      route[8],
      7,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      route[8],
      4,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final data = [0.18, 0.2, 0.19, 0.24, 0.27, 0.34, 0.30, 0.36, 0.42, 0.38, 0.44, 0.41];
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - data[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DualLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(20, y), Offset(size.width - 16, y), grid);
    }

    final speed = [18, 34, 22, 36, 29, 32, 38, 24, 31, 33, 28, 37, 35, 26, 30, 34];
    final altitude = [2, 4, 8, 12, 20, 30, 44, 56, 70, 80, 92, 76, 66, 58, 42, 30];
    _drawSeries(canvas, size, speed, const Color(0xFF2B9DFF), 60);
    _drawSeries(canvas, size, altitude, const Color(0xFFA533FF), 100);

    final labels = ['0:00', '45:00', '1:30:00', '2:15:00', '3:00:00', '3:45:28'];
    for (var i = 0; i < labels.length; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = 20 + (size.width - 44) * i / (labels.length - 1);
      text.paint(canvas, Offset(x - text.width / 2, size.height - 14));
    }
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxValue,
  ) {
    final chartRect = Rect.fromLTWH(20, 6, size.width - 44, size.height - 28);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = chartRect.left + chartRect.width * i / (data.length - 1);
      final y = chartRect.bottom - chartRect.height * (data[i] / maxValue);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.02)],
        ).createShader(chartRect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    const values = [0.11, 0.26, 0.36, 0.18, 0.09];
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - 0.035,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
    canvas.drawCircle(
      center,
      radius - 12,
      Paint()..color = _RideColors.panel,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _BuildBadge extends StatelessWidget {
  const _BuildBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF28E363).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF28E363).withValues(alpha: 0.28),
          ),
        ),
        child: const Text(
          'Trace 1.0.2+20',
          style: TextStyle(
            color: Color(0xFF65F466),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
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
      final gpsStatus = controller.gpsStatus.value.startsWith('GPS')
          ? controller.gpsStatus.value
          : 'GPS ${controller.gpsStatus.value}';

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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${now.month}月${now.day}日 '
                        '${_two(now.hour)}:${_two(now.minute)} · 晴 25°C · ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      gpsStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF39EF68),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.signal_cellular_alt,
                      color: Color(0xFF39EF68),
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.loadRideHistory,
            icon: const Icon(Icons.open_in_new, color: Colors.white),
          ),
          IconButton(
            onPressed: controller.loadRideHistory,
            icon: const Icon(Icons.more_horiz, color: Colors.white),
          ),
        ],
      );
    });
  }
}

class _RideStatusBanner extends StatelessWidget {
  const _RideStatusBanner({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final recording = controller.isRecording.value;
      final paused = controller.isPaused.value;
      final elapsed = _formatDuration(controller.elapsed.value);
      final title = recording ? (paused ? '骑行已暂停' : '正在记录骑行') : '码表待命';
      final detail = recording
          ? '$elapsed · ${controller.gpsStatus.value}'
          : '点击开始后会立即计时；静止或 GPS 未出点时速度/距离保持 0。';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (recording ? const Color(0xFF1C5F35) : _RideColors.panel)
              .withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              recording
                  ? (paused ? Icons.pause_circle : Icons.radio_button_checked)
                  : Icons.info_outline,
              color: recording ? const Color(0xFF70FF89) : _RideColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TabIntroCard extends StatelessWidget {
  const _TabIntroCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final data = switch (index) {
      1 => (
          icon: Icons.analytics_outlined,
          title: '分析',
          detail: '查看速度趋势、周里程和月度目标，判断最近骑行状态。',
        ),
      2 => (
          icon: Icons.article_outlined,
          title: '保存',
          detail: '保存当前骑行，或刷新并查看本机历史骑行记录。',
        ),
      3 => (
          icon: Icons.person_outline,
          title: '我的',
          detail: '汇总本月里程、历史次数和当前 GPS 精度。',
        ),
      _ => (
          icon: Icons.dashboard_outlined,
          title: '仪表盘',
          detail: '实时速度、里程、轨迹和骑行指标会集中显示在这里。',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF183042).withValues(alpha: 0.98),
            const Color(0xFF10231B).withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF28E363).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: const Color(0xFF65F466)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '仪表盘',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '实时速度',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: controller.currentSpeedKmh.value
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 58,
                                fontWeight: FontWeight.w900,
                                height: 0.98,
                                letterSpacing: -1.6,
                              ),
                            ),
                            TextSpan(
                              text: ' km/h',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28E363).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    controller.isRecording.value
                        ? (controller.isPaused.value ? '已暂停' : '记录中')
                        : '待命',
                    style: const TextStyle(
                      color: Color(0xFF65F466),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: '里程',
                    value: controller.distanceKm.value.toStringAsFixed(2),
                    unit: 'km',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '均速',
                    value: controller.avgSpeedKmh.value.toStringAsFixed(1),
                    unit: 'km/h',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '时长',
                    value: _formatDuration(controller.elapsed.value),
                    unit: '',
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

class _RideQuickActions extends StatelessWidget {
  const _RideQuickActions({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '操作说明',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '底部中间按钮用于开始、暂停和继续；进入“保存”页后可以保存当前骑行或刷新历史记录。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始记录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF65F466),
                    side: BorderSide(
                      color: const Color(0xFF65F466).withValues(alpha: 0.46),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.selectTab(2),
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('查看记录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.76),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisSummaryCard extends StatelessWidget {
  const _AnalysisSummaryCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '分析概览',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这里先展示稳定的基础统计；确认页面正常后再逐步恢复曲线和网格图表。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: '最高速度',
                    value: controller.maxSpeedKmh.value.toStringAsFixed(1),
                    unit: 'km/h',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '爬升',
                    value: controller.totalClimbM.value.toStringAsFixed(0),
                    unit: 'm',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '卡路里',
                    value: controller.caloriesKcal.value.toString(),
                    unit: 'kcal',
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

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final metrics = Obx(
          () {
            final hasData = _hasRideData(controller);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: compact ? 1.45 : 0.82,
              children: [
                _ValueCard(
                  label: '平均速度',
                  value: hasData
                      ? controller.avgSpeedKmh.value.toStringAsFixed(1)
                      : '28.4',
                  unit: 'km/h',
                ),
                _ValueCard(
                  label: '最大速度',
                  value: hasData
                      ? controller.maxSpeedKmh.value.toStringAsFixed(1)
                      : '46.7',
                  unit: 'km/h',
                ),
                _ValueCard(
                  label: '骑行距离',
                  value: hasData
                      ? controller.distanceKm.value.toStringAsFixed(2)
                      : '68.72',
                  unit: 'km',
                ),
                _ValueCard(
                  label: '骑行时长',
                  value: hasData
                      ? _formatDuration(controller.elapsed.value)
                      : '02:35:48',
                  unit: 'h:m:s',
                ),
              ],
            );
          },
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
            const SizedBox(width: 8),
            Expanded(flex: 9, child: metrics),
          ],
        );
      },
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasData = _hasRideData(controller);
      final speed = hasData ? controller.currentSpeedKmh.value : 32.6;
      return _Panel(
        padding: const EdgeInsets.all(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _GaugePainter(
              value: (speed / 60).clamp(0.0, 1.0).toDouble(),
            ),
            child: Stack(
              children: [
                Center(
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
                Positioned(
                  left: 45,
                  bottom: 17,
                  child: Text(
                    '0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 34,
                  bottom: 17,
                  child: Text(
                    '60',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        return Obx(
          () {
            final hasData = _hasRideData(controller);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: compact ? 2 : 3,
              childAspectRatio: compact ? 1.78 : 1.42,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _IconMetric(
                  icon: Icons.timer,
                  color: const Color(0xFF6FA8FF),
                  label: '配速',
                  value: hasData
                      ? _formatPace(controller.currentPaceSecondsPerKm.value)
                      : '02:48',
                  unit: 'min/km',
                ),
                _IconMetric(
                  icon: Icons.landscape,
                  color: const Color(0xFF31D56B),
                  label: '海拔爬升',
                  value: hasData
                      ? controller.totalClimbM.value.toStringAsFixed(0)
                      : '867',
                  unit: 'm',
                ),
                _IconMetric(
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFFF8C35),
                  label: '卡路里',
                  value:
                      hasData ? controller.caloriesKcal.value.toString() : '1627',
                  unit: 'kcal',
                ),
                const _IconMetric(
                  icon: Icons.favorite,
                  color: Color(0xFFFF5C5C),
                  label: '心率',
                  value: '152',
                  unit: 'bpm',
                ),
                const _IconMetric(
                  icon: Icons.speed,
                  color: Color(0xFFB65CFF),
                  label: '踏频',
                  value: '82',
                  unit: 'rpm',
                ),
                const _IconMetric(
                  icon: Icons.bolt,
                  color: Color(0xFFFFD43B),
                  label: '功率',
                  value: '210',
                  unit: 'W',
                ),
              ],
            );
          },
        );
      },
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

class _SaveRideCard extends StatelessWidget {
  const _SaveRideCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final recording = controller.isRecording.value;
      final paused = controller.isPaused.value;
      return _Panel(
        title: '保存',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recording
                  ? (paused ? '当前骑行已暂停，可以继续或保存记录。' : '当前骑行正在记录，可以随时保存。')
                  : '当前没有正在记录的骑行，点击中间开始按钮记录新骑行。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: '里程',
                    value: controller.distanceKm.value.toStringAsFixed(2),
                    unit: 'km',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '时长',
                    value: _formatDuration(controller.elapsed.value),
                    unit: '',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '均速',
                    value: controller.avgSpeedKmh.value.toStringAsFixed(1),
                    unit: 'km/h',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: recording
                    ? () => controller.saveCurrentRide()
                    : controller.loadRideHistory,
                icon: Icon(recording ? Icons.save_outlined : Icons.refresh),
                label: Text(recording ? '保存本次骑行' : '刷新历史记录'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28E363),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _Panel(
        title: '我的',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '骑行数据会保存在本机，用于仪表盘、趋势分析和历史记录。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: '本月里程',
                    value: controller.monthlyDistanceKm.value.toStringAsFixed(1),
                    unit: 'km',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '历史记录',
                    value: controller.recentRides.length.toString(),
                    unit: '次',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'GPS 精度',
                    value: controller.gpsAccuracyM.value.toStringAsFixed(0),
                    unit: 'm',
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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

class _RideTabBar extends StatelessWidget {
  const _RideTabBar({
    required this.controller,
    required this.onSelect,
  });

  final RideController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final selectedIndex = controller.activeTabIndex.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
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
                  icon: Icons.speed,
                  label: '仪表盘',
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _BottomAction(
                  icon: Icons.pie_chart_outline,
                  label: '分析',
                  selected: selectedIndex == 1,
                  onTap: () {
                    controller.loadRideHistory();
                    onSelect(1);
                  },
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (controller.isRecording.value) {
                          controller.pauseResume();
                        } else {
                          controller.start();
                        }
                      },
                      child: Container(
                        width: 68,
                        height: 68,
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
                              size: 27,
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
                  icon: Icons.history,
                  label: '记录',
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _BottomAction(
                  icon: Icons.person_outline,
                  label: '我的',
                  selected: selectedIndex == 3,
                  onTap: () {
                    controller.loadRideHistory();
                    onSelect(3);
                  },
                ),
              ],
            ),
          ),
        );
      },
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
    final color = selected ? _RideColors.green : const Color(0xFF98A4AD);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
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
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18212B), Color(0xFF101923)],
        ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 8),
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
                    fontSize: 20,
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
  static const background = Color(0xFF08111A);
  static const panel = Color(0xFF141F28);
  static const green = Color(0xFF65F466);
  static const orange = Color(0xFFFF5B2E);
  static const muted = Color(0xFF98A4AD);
}

bool _hasRideData(RideController controller) {
  return controller.isRecording.value ||
      controller.elapsed.value > Duration.zero ||
      controller.distanceKm.value > 0 ||
      controller.points.isNotEmpty;
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
