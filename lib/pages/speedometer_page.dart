import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ride_controller.dart';

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
      duration: const Duration(milliseconds: 260),
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
              child: Obx(() {
                final selectedIndex = controller.activeTabIndex.value;
                return ListView(
                  key: PageStorageKey<String>('speedometer-$selectedIndex'),
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    _TopChrome(
                      selectedIndex: selectedIndex,
                      isConnected: selectedIndex != 3,
                    ),
                    const SizedBox(height: 18),
                    _SelectedPage(
                      controller: controller,
                      selectedIndex: selectedIndex,
                    ),
                  ],
                );
              }),
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
}

class _SelectedPage extends StatelessWidget {
  const _SelectedPage({
    required this.controller,
    required this.selectedIndex,
  });

  final RideController controller;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    switch (selectedIndex) {
      case 1:
        return _StatisticsPage(controller: controller);
      case 2:
        return const _RoutesPage();
      case 3:
        return _DevicesPage(controller: controller);
      case 0:
      default:
        return _DashboardPage(controller: controller);
    }
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.selectedIndex,
    required this.isConnected,
  });

  final int selectedIndex;
  final bool isConnected;

  String get _title {
    if (selectedIndex == 2) return '路线';
    if (selectedIndex == 3) return '设备';
    return '码表';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white.withOpacity(0.78)),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isConnected ? '已连接' : '未连接',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'iGPSPORT BSC300',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
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
                    size: 26,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 25,
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

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActivityHeroCard(controller: controller),
        const SizedBox(height: 12),
        _DesignMetricGrid(controller: controller),
        const SizedBox(height: 12),
        _SpeedAltitudePanel(controller: controller),
        const SizedBox(height: 12),
        const _DistributionGrid(),
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
      final sample = _RideSample.from(controller);

      return _GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 236,
            child: Stack(
              children: [
                Positioned.fill(
                  left: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: const _RouteMapPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 18,
                  child: Column(
                    children: [
                      _RoundIconButton(icon: Icons.fullscreen, onTap: () {}),
                      const SizedBox(height: 16),
                      _RoundIconButton(icon: Icons.share_outlined, onTap: () {}),
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
                          size: 24,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '户外骑行',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.96),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Text(
                      '2024/05/18  08:32',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.62),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: sample.distanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              height: 0.96,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.4,
                            ),
                          ),
                          TextSpan(
                            text: ' km',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 22,
                      runSpacing: 12,
                      children: [
                        _HeroStat(
                          label: '运动时间',
                          value: sample.durationText,
                          unit: '',
                        ),
                        _HeroStat(
                          label: '平均速度',
                          value: sample.avgSpeedText,
                          unit: 'km/h',
                        ),
                        _HeroStat(
                          label: '累计爬升',
                          value: sample.climbText,
                          unit: 'm',
                        ),
                        const _HeroStat(
                          label: '训练负荷',
                          value: '187',
                          unit: '高',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCB2D),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFCB2D).withOpacity(0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'PR',
                    style: TextStyle(
                      color: Color(0xFF1C1B17),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '个人新纪录!',
                      style: TextStyle(
                        color: Color(0xFFFFD74A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '最长距离  ${sample.distanceText}km',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.82),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看详情'),
                    SizedBox(width: 3),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      );
    });
  }
}

class _DesignMetricGrid extends StatelessWidget {
  const _DesignMetricGrid({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sample = _RideSample.from(controller);
      final cards = [
        _MetricTile(
          icon: Icons.speed,
          color: const Color(0xFF2088FF),
          title: '平均速度',
          value: sample.avgSpeedText,
          unit: 'km/h',
          footnote: '最高 ${sample.maxSpeedText} km/h',
          sparkColor: const Color(0xFF2088FF),
          values: const [16, 17, 18, 18, 20, 24, 22, 29, 27, 31, 30, 33],
        ),
        const _MetricTile(
          icon: Icons.bolt,
          color: Color(0xFF64D72A),
          title: '平均功率',
          value: '186',
          unit: 'w',
          footnote: '最大 562 w',
          sparkColor: Color(0xFF64D72A),
          values: [110, 112, 118, 135, 172, 188, 160, 176, 182, 194, 181, 202],
        ),
        const _MetricTile(
          icon: Icons.favorite,
          color: Color(0xFFFF3B5F),
          title: '平均心率',
          value: '156',
          unit: 'bpm',
          footnote: '最大 188 bpm',
          sparkColor: Color(0xFFFF3B5F),
          values: [98, 106, 118, 130, 146, 159, 154, 165, 172, 169, 176, 182],
        ),
        const _MetricTile(
          icon: Icons.track_changes,
          color: Color(0xFFFFC400),
          title: '平均踏频',
          value: '87',
          unit: 'rpm',
          footnote: '最高 118 rpm',
          sparkColor: Color(0xFFFFC400),
          values: [62, 64, 63, 70, 76, 91, 84, 79, 82, 88, 84, 92],
        ),
        _MetricTile(
          icon: Icons.terrain,
          color: const Color(0xFFA533FF),
          title: '累计爬升',
          value: sample.climbText,
          unit: 'm',
          footnote: '总上升 ${sample.climbText} m',
          sparkColor: const Color(0xFFA533FF),
          values: const [
            0,
            20,
            45,
            110,
            180,
            260,
            360,
            510,
            650,
            820,
            1010,
            1268,
          ],
        ),
        const _MetricTile(
          icon: Icons.thermostat,
          color: Color(0xFF42D8E6),
          title: '平均温度',
          value: '22.4',
          unit: '°C',
          footnote: '最高 28.6 °C',
          sparkColor: Color(0xFF42D8E6),
          values: [24, 23, 22, 20, 18, 19, 23, 22, 20, 19, 22, 21],
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 420 ? 2 : 3;
          const spacing = 8.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
      );
    });
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    required this.footnote,
    required this.sparkColor,
    required this.values,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String footnote;
  final Color sparkColor;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: SizedBox(
        height: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.90), width: 2),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 34,
              child: CustomPaint(
                painter: _SparklinePainter(values: values, color: sparkColor),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedAltitudePanel extends StatelessWidget {
  const _SpeedAltitudePanel({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sample = _RideSample.from(controller);
      final speedData = controller.speedTrendKmh.isEmpty
          ? const [32.0, 28, 35, 20, 34, 30, 38, 27, 31, 34, 25, 36, 33, 29]
          : controller.speedTrendKmh.toList();
      final altitudeData = controller.altitudeTrendM.isEmpty
          ? const [
              0.0,
              35,
              70,
              180,
              320,
              420,
              620,
              900,
              1150,
              1268,
              1040,
              780,
              520,
              360,
            ]
          : controller.altitudeTrendM.toList();

      return _GlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
        children: [
          Row(
            children: [
              const Text(
                '速度 & 海拔',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _LegendText(
                label: '平均',
                value: '${sample.avgSpeedText} km/h',
                color: const Color(0xFF2B9DFF),
              ),
              const SizedBox(width: 16),
              _LegendText(
                label: '累计爬升',
                value: '${sample.climbText} m',
                color: const Color(0xFFA533FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 194,
            child: CustomPaint(
              painter: _DualLineChartPainter(
                speed: speedData,
                altitude: altitudeData,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
        ),
      );
    });
  }
}

class _DistributionGrid extends StatelessWidget {
  const _DistributionGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final panels = [
          const _ZoneDistributionPanel(
            title: '功率分布',
            summaryLabel: '平均功率',
            summaryValue: '186 w',
            centerText: '186',
            centerSubtext: '平均功率',
            colors: [
              Color(0xFFFF3158),
              Color(0xFFFF7A1A),
              Color(0xFFFFD21A),
              Color(0xFF4AD14A),
              Color(0xFF268DFF),
            ],
            labels: [
              'Z5  > 350 w',
              'Z4  250 - 350 w',
              'Z3  180 - 250 w',
              'Z2  120 - 180 w',
              'Z1  < 120 w',
            ],
            values: ['12:15   11%', '28:47   26%', '40:21   36%', '32:16   18%', '12:09   9%'],
            distribution: [0.11, 0.26, 0.36, 0.18, 0.09],
          ),
          const _ZoneDistributionPanel(
            title: '心率分布',
            summaryLabel: '平均心率',
            summaryValue: '156 bpm',
            centerText: '156',
            centerSubtext: '平均心率',
            colors: [
              Color(0xFFFF3158),
              Color(0xFFFF7A1A),
              Color(0xFFFFD21A),
              Color(0xFF4AD14A),
              Color(0xFF268DFF),
            ],
            labels: [
              'Z5  > 178 bpm',
              'Z4  160 - 178 bpm',
              'Z3  140 - 160 bpm',
              'Z2  120 - 140 bpm',
              'Z1  < 120 bpm',
            ],
            values: ['08:36   6%', '26:18   17%', '55:21   36%', '48:23   31%', '11:10   10%'],
            distribution: [0.06, 0.17, 0.36, 0.31, 0.10],
          ),
        ];

        if (compact) {
          return Column(
            children: [
              panels[0],
              const SizedBox(height: 8),
              panels[1],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: panels[0]),
            const SizedBox(width: 8),
            Expanded(child: panels[1]),
          ],
        );
      },
    );
  }
}

class _ZoneDistributionPanel extends StatelessWidget {
  const _ZoneDistributionPanel({
    required this.title,
    required this.summaryLabel,
    required this.summaryValue,
    required this.centerText,
    required this.centerSubtext,
    required this.colors,
    required this.labels,
    required this.values,
    required this.distribution,
  });

  final String title;
  final String summaryLabel;
  final String summaryValue;
  final String centerText;
  final String centerSubtext;
  final List<Color> colors;
  final List<String> labels;
  final List<String> values;
  final List<double> distribution;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 186,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _LegendText(
                  label: summaryLabel,
                  value: summaryValue,
                  color: title == '功率分布'
                      ? const Color(0xFF2B9DFF)
                      : const Color(0xFFA533FF),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: _DonutPainter(
                            colors: colors,
                            values: distribution,
                            backgroundColor: _RideColors.panel,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              centerSubtext,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.50),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                values[i],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 11,
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
      ),
    );
  }
}

class _StatisticsPage extends StatelessWidget {
  const _StatisticsPage({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stats = _RideStats.from(controller);

      return _OuterFrame(
        child: Column(
        children: [
          const _PeriodSegment(selectedIndex: 1),
          const SizedBox(height: 18),
          const _MonthSelector(label: '2024年5月'),
          const SizedBox(height: 18),
          _StatsOverview(stats: stats),
          const SizedBox(height: 12),
          _BarTrendPanel(
            title: '里程趋势',
            unit: '单位：km',
            values: const [82, 32, 74, 8, 41, 79, 11, 58, 44, 88, 99, 59, 14, 75, 80, 102, 66],
            labels: const ['05/01', '05/08', '05/15', '05/22', '05/29'],
            color: _RideColors.orange,
            tooltipTitle: '5月18日',
            tooltipValue: '102.6 km',
            maxValue: 120,
          ),
          const SizedBox(height: 12),
          _BarTrendPanel(
            title: '运动时长趋势',
            unit: '单位：小时',
            values: const [5, 2, 5, 0.5, 2.5, 4.9, 0.7, 3.4, 2.7, 5.3, 6.0, 3.7, 0.9, 4.6, 5.0, 6.6, 4.2],
            labels: const ['05/01', '05/08', '05/15', '05/22', '05/29'],
            color: const Color(0xFF268DFF),
            tooltipTitle: '5月18日',
            tooltipValue: '3:45:28',
            maxValue: 8,
          ),
          const SizedBox(height: 12),
          const _AnnualDistributionPanel(),
        ],
        ),
      );
    });
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    const labels = ['周', '月', '年', '全部'];
    return Container(
      height: 47,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? Colors.white.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: i == selectedIndex
                        ? Colors.white
                        : Colors.white.withOpacity(0.62),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.86), size: 30),
        const SizedBox(width: 42),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 42),
        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.86), size: 30),
      ],
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.stats});

  final _RideStats stats;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总览',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.34,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            children: [
              _OverviewMetric(label: '活动次数', value: stats.rideCount, unit: '次'),
              _OverviewMetric(label: '总里程', value: stats.totalDistance, unit: 'km'),
              _OverviewMetric(label: '总时间', value: stats.totalDuration, unit: ''),
              _OverviewMetric(label: '总爬升', value: stats.totalClimb, unit: 'm'),
              _OverviewMetric(label: '总消耗', value: stats.calories, unit: 'kcal'),
              _OverviewMetric(label: '平均速度', value: stats.avgSpeed, unit: 'km/h'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.56),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _BarTrendPanel extends StatelessWidget {
  const _BarTrendPanel({
    required this.title,
    required this.unit,
    required this.values,
    required this.labels,
    required this.color,
    required this.tooltipTitle,
    required this.tooltipValue,
    required this.maxValue,
  });

  final String title;
  final String unit;
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String tooltipTitle;
  final String tooltipValue;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.54),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: CustomPaint(
              painter: _BarChartPainter(
                values: values,
                labels: labels,
                color: color,
                maxValue: maxValue,
                tooltipIndex: values.length > 16 ? 15 : values.length - 1,
                tooltipTitle: tooltipTitle,
                tooltipValue: tooltipValue,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualDistributionPanel extends StatelessWidget {
  const _AnnualDistributionPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '运动类型分布',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '单位：km',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.54),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: const [
                    _DistributionRow(
                      color: _RideColors.orange,
                      label: '户外骑行',
                      value: '872.3 km',
                      ratio: '85%',
                    ),
                    SizedBox(height: 24),
                    _DistributionRow(
                      color: Color(0xFF268DFF),
                      label: '室内骑行',
                      value: '102.4 km',
                      ratio: '10%',
                    ),
                    SizedBox(height: 24),
                    _DistributionRow(
                      color: Color(0xFF62D729),
                      label: '其他运动',
                      value: '51.6 km',
                      ratio: '5%',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: const _DonutPainter(
                        colors: [
                          _RideColors.orange,
                          Color(0xFF268DFF),
                          Color(0xFF62D729),
                        ],
                        values: [0.85, 0.10, 0.05],
                        backgroundColor: _RideColors.panel,
                        strokeWidth: 25,
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '1026.3',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '总里程 (km)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.54),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.color,
    required this.label,
    required this.value,
    required this.ratio,
  });

  final Color color;
  final String label;
  final String value;
  final String ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          ratio,
          style: TextStyle(
            color: Colors.white.withOpacity(0.82),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RoutesPage extends StatelessWidget {
  const _RoutesPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _RouteModeTabs(),
        const SizedBox(height: 12),
        const _RouteSearchBar(),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '路线（18）',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _RouteListCard(
          title: '周末环山路线',
          date: '2024/05/18  08:32',
          distance: '102.63',
          climb: '1268',
          duration: '03:45:28',
          difficulty: '中等',
          difficultyColor: Color(0xFFA46AFF),
          variant: 0,
        ),
        const SizedBox(height: 10),
        const _RouteListCard(
          title: '滨海骑行路线',
          date: '2024/05/12  07:15',
          distance: '65.28',
          climb: '512',
          duration: '02:28:16',
          difficulty: '简单',
          difficultyColor: Color(0xFF62D729),
          variant: 1,
        ),
        const SizedBox(height: 10),
        const _RouteListCard(
          title: '城市探索路线',
          date: '2024/05/05  09:42',
          distance: '88.47',
          climb: '876',
          duration: '03:12:45',
          difficulty: '困难',
          difficultyColor: Color(0xFFFF3B5F),
          variant: 2,
        ),
        const SizedBox(height: 10),
        const _RouteListCard(
          title: '晨间训练路线',
          date: '2024/04/28  06:30',
          distance: '45.16',
          climb: '321',
          duration: '01:48:22',
          difficulty: '简单',
          difficultyColor: Color(0xFF62D729),
          variant: 3,
        ),
      ],
    );
  }
}

class _RouteModeTabs extends StatelessWidget {
  const _RouteModeTabs();

  @override
  Widget build(BuildContext context) {
    const labels = ['我的路线', '收藏路线', '导入路线'];
    return _OuterFrame(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == 0
                      ? _RideColors.orange.withOpacity(0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: i == 0
                      ? Border.all(color: _RideColors.orange.withOpacity(0.85))
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: i == 0
                        ? _RideColors.orange
                        : Colors.white.withOpacity(0.70),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteSearchBar extends StatelessWidget {
  const _RouteSearchBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white.withOpacity(0.64), size: 23),
                const SizedBox(width: 8),
                Text(
                  '搜索路线名称或地点',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Text(
                '全部',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.78),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteListCard extends StatelessWidget {
  const _RouteListCard({
    required this.title,
    required this.date,
    required this.distance,
    required this.climb,
    required this.duration,
    required this.difficulty,
    required this.difficultyColor,
    required this.variant,
  });

  final String title;
  final String date;
  final String distance;
  final String climb;
  final String duration;
  final String difficulty;
  final Color difficultyColor;
  final int variant;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 176,
        child: Row(
          children: [
            SizedBox(
              width: 148,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: CustomPaint(
                  painter: _RouteMapPainter(variant: variant),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _RouteBadge(
                          label: '公路',
                          color: _RideColors.orange,
                        ),
                        const SizedBox(width: 8),
                        _RouteBadge(
                          label: '难度 $difficulty',
                          color: difficultyColor,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        _RouteMetric(value: distance, unit: 'km'),
                        _RouteMetric(value: climb, unit: 'm'),
                        _RouteMetric(value: duration, unit: ''),
                      ],
                    ),
                    Divider(color: Colors.white.withOpacity(0.08), height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.star_border, color: Colors.white.withOpacity(0.68)),
                        const SizedBox(width: 28),
                        Icon(Icons.share_outlined, color: Colors.white.withOpacity(0.68)),
                        const SizedBox(width: 28),
                        Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.68)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({
    required this.value,
    required this.unit,
  });

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return RichText(
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
                color: Colors.white.withOpacity(0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _DevicesPage extends StatelessWidget {
  const _DevicesPage({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScanPanel(controller: controller),
        const SizedBox(height: 12),
        const _AvailableDevicesPanel(),
        const SizedBox(height: 12),
        const _ConnectedDevicePanel(),
      ],
    );
  }
}

class _ScanPanel extends StatelessWidget {
  const _ScanPanel({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: [
          const Text(
            '正在扫描设备...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请确保设备已开机并靠近手机',
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 304,
            child: CustomPaint(
              painter: const _RadarPainter(),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3BE23E).withOpacity(0.18),
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: Color(0xFF3BE23E),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: controller.loadRideHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: _RideColors.orange,
              side: BorderSide(color: Colors.white.withOpacity(0.14)),
              minimumSize: const Size(260, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              '停止扫描',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableDevicesPanel extends StatelessWidget {
  const _AvailableDevicesPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '可用设备',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Icon(Icons.refresh, color: Colors.white.withOpacity(0.78)),
            ],
          ),
          const SizedBox(height: 14),
          const _DeviceRow(
            title: 'iGPSPORT BSC300_1234',
            type: '码表',
            bars: 4,
          ),
          const SizedBox(height: 10),
          const _DeviceRow(
            title: 'iGPSPORT SR30_5678',
            type: '雷达',
            bars: 4,
          ),
          const SizedBox(height: 10),
          const _DeviceRow(
            title: 'iGPSPORT HR40_9012',
            type: '心率带',
            bars: 3,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '未找到我的设备',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.82)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.title,
    required this.type,
    required this.bars,
  });

  final String title;
  final String type;
  final int bars;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          _DeviceThumbnail(kind: type, compact: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SignalBars(value: bars),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _RideColors.orange,
              side: const BorderSide(color: _RideColors.orange),
              minimumSize: const Size(76, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              '连接',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceThumbnail extends StatelessWidget {
  const _DeviceThumbnail({
    required this.kind,
    this.compact = false,
  });

  final String kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (kind == '雷达') return _RadarDeviceThumbnail(compact: compact);
    if (kind == '心率带') return _HeartRateDeviceThumbnail(compact: compact);
    return _ComputerDeviceThumbnail(compact: compact);
  }
}

class _ComputerDeviceThumbnail extends StatelessWidget {
  const _ComputerDeviceThumbnail({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 50.0 : 84.0;
    final height = compact ? 62.0 : 104.0;
    final screenInset = compact ? 7.0 : 12.0;
    return SizedBox(
      width: compact ? 56 : 92,
      height: compact ? 64 : 108,
      child: Center(
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.all(screenInset),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 10 : 16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF30343A), Color(0xFF101318)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.34),
                blurRadius: compact ? 10 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 6 : 10),
              color: const Color(0xFF1B2026),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'iGPS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: compact ? 5 : 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: compact ? 2 : 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DeviceScreenLine(width: compact ? 13 : 22),
                        SizedBox(width: compact ? 3 : 5),
                        _DeviceScreenLine(width: compact ? 8 : 15),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarDeviceThumbnail extends StatelessWidget {
  const _RadarDeviceThumbnail({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 56 : 92,
      height: compact ? 64 : 108,
      child: Center(
        child: Container(
          width: compact ? 42 : 68,
          height: compact ? 58 : 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E3338), Color(0xFF101318)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.34),
                blurRadius: compact ? 10 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: compact ? 18 : 30,
              height: compact ? 18 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartRateDeviceThumbnail extends StatelessWidget {
  const _HeartRateDeviceThumbnail({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 56 : 92,
      height: compact ? 64 : 108,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: compact ? 54 : 88,
              height: compact ? 16 : 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFF14171C), Color(0xFF2B3036), Color(0xFF14171C)],
                ),
              ),
            ),
            Container(
              width: compact ? 34 : 54,
              height: compact ? 24 : 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 7 : 11),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF282D32), Color(0xFF0F1216)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Center(
                child: Text(
                  'iGPS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: compact ? 5 : 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceScreenLine extends StatelessWidget {
  const _DeviceScreenLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ConnectedDevicePanel extends StatelessWidget {
  const _ConnectedDevicePanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DeviceThumbnail(kind: '码表'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'iGPSPORT BSC300_1234',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3BE23E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已连接',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '固件版本：v1.23.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '电量：100%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _DeviceSettingRow(
            icon: Icons.settings,
            color: Color(0xFF268DFF),
            title: '设备设置',
          ),
          const _DeviceSettingRow(
            icon: Icons.grid_view,
            color: Color(0xFF4AD14A),
            title: '页面配置',
          ),
          const _DeviceSettingRow(
            icon: Icons.link,
            color: Color(0xFFA533FF),
            title: '传感器管理',
          ),
          const _DeviceSwitchRow(
            icon: Icons.pause,
            color: _RideColors.orange,
            title: '自动暂停',
            subtitle: '停止运动时自动暂停记录',
          ),
          const _DeviceSwitchRow(
            icon: Icons.trip_origin,
            color: Color(0xFFFFC400),
            title: '自动计圈',
            subtitle: '按距离自动生成计圈',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _RideColors.orange,
              minimumSize: const Size(double.infinity, 52),
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '解除绑定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSettingRow extends StatelessWidget {
  const _DeviceSettingRow({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _DeviceRowBase(
      icon: icon,
      color: color,
      title: title,
      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.76)),
    );
  }
}

class _DeviceSwitchRow extends StatelessWidget {
  const _DeviceSwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _DeviceRowBase(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: true,
        onChanged: (_) {},
        activeColor: Colors.white,
        activeTrackColor: _RideColors.orange,
      ),
    );
  }
}

class _DeviceRowBase extends StatelessWidget {
  const _DeviceRowBase({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: 70,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.56),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 4,
              height: 8.0 + i * 5,
              decoration: BoxDecoration(
                color: i < value
                    ? const Color(0xFF55E8E6)
                    : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
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
    return Obx(() {
      final selectedIndex = controller.activeTabIndex.value;
      final isRecording = controller.isRecording.value;
      final isPaused = controller.isPaused.value;
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101720).withOpacity(0.98),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.40),
              blurRadius: 30,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              children: [
                _BottomAction(
                  icon: Icons.speed,
                  label: '仪表盘',
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _BottomAction(
                  icon: Icons.bar_chart,
                  label: '统计',
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                _BottomAction(
                  icon: Icons.explore,
                  label: '路线',
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _BottomRecordAction(
                  isRecording: isRecording,
                  isPaused: isPaused,
                  onTap: () {
                    if (isRecording) {
                      controller.pauseResume();
                    } else {
                      controller.start();
                    }
                  },
                ),
                _BottomAction(
                  icon: Icons.devices_other,
                  label: '设备',
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _BottomRecordAction extends StatelessWidget {
  const _BottomRecordAction({
    required this.isRecording,
    required this.isPaused,
    required this.onTap,
  });

  final bool isRecording;
  final bool isPaused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = isRecording && !isPaused ? Icons.pause : Icons.play_arrow;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _RideColors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _RideColors.orange.withOpacity(0.36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 5),
            const Text(
              '开始/暂停',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _RideColors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _RideColors.orange : Colors.white.withOpacity(0.62);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 42 : 36,
              height: selected ? 42 : 36,
              decoration: BoxDecoration(
                color: selected
                    ? _RideColors.orange.withOpacity(0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _RideColors.orange : color,
                  width: selected ? 2 : 1.7,
                ),
              ),
              child: Icon(icon, color: color, size: selected ? 23 : 21),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OuterFrame extends StatelessWidget {
  const _OuterFrame({
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF151B24).withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF222A35).withOpacity(0.82),
            const Color(0xFF141A23).withOpacity(0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.82), size: 23),
      ),
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
    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.48),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
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
                          : Colors.white.withOpacity(0.62),
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

class _LegendText extends StatelessWidget {
  const _LegendText({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.54),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RideSample {
  const _RideSample({
    required this.distanceText,
    required this.durationText,
    required this.avgSpeedText,
    required this.maxSpeedText,
    required this.climbText,
  });

  final String distanceText;
  final String durationText;
  final String avgSpeedText;
  final String maxSpeedText;
  final String climbText;

  factory _RideSample.from(RideController controller) {
    final hasLiveRide = controller.distanceKm.value > 0 ||
        controller.elapsed.value > Duration.zero ||
        controller.isRecording.value;
    return _RideSample(
      distanceText: hasLiveRide
          ? controller.distanceKm.value.toStringAsFixed(2)
          : '102.63',
      durationText: hasLiveRide
          ? _formatDuration(controller.elapsed.value)
          : '03:45:28',
      avgSpeedText: hasLiveRide && controller.avgSpeedKmh.value > 0
          ? controller.avgSpeedKmh.value.toStringAsFixed(1)
          : '27.3',
      maxSpeedText: hasLiveRide && controller.maxSpeedKmh.value > 0
          ? controller.maxSpeedKmh.value.toStringAsFixed(1)
          : '52.6',
      climbText: hasLiveRide && controller.totalClimbM.value > 0
          ? controller.totalClimbM.value.toStringAsFixed(0)
          : '1268',
    );
  }
}

class _RideStats {
  const _RideStats({
    required this.rideCount,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalClimb,
    required this.calories,
    required this.avgSpeed,
  });

  final String rideCount;
  final String totalDistance;
  final String totalDuration;
  final String totalClimb;
  final String calories;
  final String avgSpeed;

  factory _RideStats.from(RideController controller) {
    final rides = controller.recentRides.toList();
    final hasHistory = rides.isNotEmpty;
    final totalDistance = hasHistory
        ? rides.fold<double>(0, (sum, ride) => sum + ride.distanceKm)
        : 1026.3;
    final totalSeconds = hasHistory
        ? rides.fold<int>(0, (sum, ride) => sum + ride.durationSeconds)
        : const Duration(hours: 45, minutes: 32, seconds: 18).inSeconds;
    final totalClimb = hasHistory
        ? rides.fold<double>(0, (sum, ride) => sum + ride.totalClimbM)
        : 12868.0;
    final avgSpeed = totalSeconds > 0 ? totalDistance / totalSeconds * 3600 : 0;

    return _RideStats(
      rideCount: hasHistory ? rides.length.toString() : '27',
      totalDistance: totalDistance.toStringAsFixed(1),
      totalDuration: _formatSeconds(totalSeconds),
      totalClimb: totalClimb.toStringAsFixed(0),
      calories: (totalDistance * 31.73).round().toString(),
      avgSpeed: (avgSpeed > 0 ? avgSpeed : 22.5).toStringAsFixed(1),
    );
  }
}

String _formatDuration(Duration duration) {
  return _formatSeconds(duration.inSeconds);
}

String _formatSeconds(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return [
    hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    secs.toString().padLeft(2, '0'),
  ].join(':');
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({this.variant = 0});

  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1F2833).withOpacity(0.92),
          const Color(0xFF10161F).withOpacity(0.98),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    _drawMapLines(canvas, size);
    _drawRoute(canvas, size);
  }

  void _drawMapLines(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thinRoadPaint = Paint()
      ..color = Colors.white.withOpacity(0.028)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.12 + i * 0.17);
      final path = Path()
        ..moveTo(-20, y + variant * 4)
        ..cubicTo(
          size.width * 0.26,
          y - 24,
          size.width * 0.58,
          y + 30,
          size.width + 20,
          y - 8,
        );
      canvas.drawPath(path, i.isEven ? roadPaint : thinRoadPaint);
    }

    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.18 + i * 0.24);
      final path = Path()
        ..moveTo(x, -16)
        ..cubicTo(
          x + 30,
          size.height * 0.26,
          x - 30,
          size.height * 0.60,
          x + 14,
          size.height + 16,
        );
      canvas.drawPath(path, thinRoadPaint);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    final route = _routePoints(size);
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.34)
      ..strokeWidth = 11
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
        const Color(0xFF57DF43),
        const Color(0xFFFF4B24),
        t,
      )!;
      canvas.drawPath(
        segmentPath,
        Paint()
          ..color = color
          ..strokeWidth = 5.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.drawCircle(route.first, 9, Paint()..color = const Color(0xFF5FE052));
    canvas.drawCircle(route.first, 4, Paint()..color = Colors.white);
    final finish = route[math.max(0, route.length - 3)];
    canvas.drawCircle(finish, 8, Paint()..color = Colors.white);
    canvas.drawCircle(finish, 4, Paint()..color = Colors.black.withOpacity(0.78));
  }

  List<Offset> _routePoints(Size size) {
    final dx = (variant % 2) * size.width * 0.04;
    final dy = (variant % 3) * size.height * 0.025;
    return [
      Offset(size.width * 0.62 - dx, size.height * 0.10 + dy),
      Offset(size.width * 0.50 - dx, size.height * 0.20 + dy),
      Offset(size.width * 0.42 - dx, size.height * 0.34 + dy),
      Offset(size.width * 0.31 - dx, size.height * 0.41 + dy),
      Offset(size.width * 0.42 + dx, size.height * 0.56),
      Offset(size.width * 0.56 + dx, size.height * 0.52),
      Offset(size.width * 0.72 + dx, size.height * 0.63),
      Offset(size.width * 0.64 + dx, size.height * 0.79),
      Offset(size.width * 0.48, size.height * 0.88 - dy),
      Offset(size.width * 0.39 - dx, size.height * 0.70 - dy),
      Offset(size.width * 0.24 - dx, size.height * 0.58 - dy),
      Offset(size.width * 0.28 - dx, size.height * 0.38),
      Offset(size.width * 0.46, size.height * 0.28),
      Offset(size.width * 0.62 - dx, size.height * 0.10 + dy),
    ];
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return oldDelegate.variant != variant;
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
  });

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(1, maxValue - minValue);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - normalized * size.height * 0.82 - 3;
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
          colors: [color.withOpacity(0.42), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _DualLineChartPainter extends CustomPainter {
  const _DualLineChartPainter({
    required this.speed,
    required this.altitude,
  });

  final List<double> speed;
  final List<double> altitude;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(26, y), Offset(size.width - 22, y), grid);
    }

    _drawAxisText(canvas, 'km/h', Offset(0, 0));
    _drawAxisText(canvas, 'm', Offset(size.width - 10, 0));
    _drawSeries(canvas, size, altitude, const Color(0xFFA533FF), 1500);
    _drawSeries(canvas, size, speed, const Color(0xFF2B9DFF), 60);

    const labels = ['0:00', '45:00', '1:30:00', '2:15:00', '3:00:00', '3:45:28'];
    for (var i = 0; i < labels.length; i++) {
      final x = 26 + (size.width - 52) * i / (labels.length - 1);
      _drawChartLabel(canvas, labels[i], Offset(x, size.height - 15), center: true);
    }
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> data,
    Color color,
    double maxValue,
  ) {
    if (data.length < 2) return;
    final chartRect = Rect.fromLTWH(26, 16, size.width - 52, size.height - 38);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = chartRect.left + chartRect.width * i / (data.length - 1);
      final value = data[i].clamp(0, maxValue);
      final y = chartRect.bottom - chartRect.height * (value / maxValue);
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
          colors: [color.withOpacity(0.34), color.withOpacity(0.02)],
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

  void _drawAxisText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.52),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawChartLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.46),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(offset.dx - (center ? painter.width / 2 : 0), offset.dy));
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.altitude != altitude;
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.maxValue,
    required this.tooltipIndex,
    required this.tooltipTitle,
    required this.tooltipValue,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double maxValue;
  final int tooltipIndex;
  final String tooltipTitle;
  final String tooltipValue;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(34, 26, size.width - 54, size.height - 52);
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartRect.bottom - chartRect.height * i / 4;
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), grid);
      _drawText(
        canvas,
        (maxValue * i / 4).round().toString(),
        Offset(0, y - 7),
        color: Colors.white.withOpacity(0.46),
        size: 11,
      );
    }

    final barWidth = math.max(4.0, chartRect.width / values.length * 0.34);
    for (var i = 0; i < values.length; i++) {
      final value = values[i].clamp(0, maxValue);
      final x = chartRect.left + chartRect.width * (i + 0.5) / values.length;
      final height = chartRect.height * value / maxValue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barWidth / 2, chartRect.bottom - height, barWidth, height),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withOpacity(0.70)],
          ).createShader(rect.outerRect),
      );
    }

    for (var i = 0; i < labels.length; i++) {
      final x = chartRect.left + chartRect.width * i / (labels.length - 1);
      _drawText(
        canvas,
        labels[i],
        Offset(x, size.height - 20),
        color: Colors.white.withOpacity(0.48),
        size: 12,
        center: true,
      );
    }

    final markerX = chartRect.left +
        chartRect.width * (tooltipIndex + 0.5) / values.length;
    final markerY = chartRect.bottom -
        chartRect.height * values[tooltipIndex].clamp(0, maxValue) / maxValue;
    _drawTooltip(canvas, Offset(markerX, markerY - 10));
  }

  void _drawTooltip(Canvas canvas, Offset anchor) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: anchor.translate(0, -36), width: 86, height: 58),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF303744).withOpacity(0.96),
    );
    final pointer = Path()
      ..moveTo(anchor.dx - 8, anchor.dy - 8)
      ..lineTo(anchor.dx + 8, anchor.dy - 8)
      ..lineTo(anchor.dx, anchor.dy + 1)
      ..close();
    canvas.drawPath(
      pointer,
      Paint()..color = const Color(0xFF303744).withOpacity(0.96),
    );
    _drawText(canvas, tooltipTitle, Offset(anchor.dx, anchor.dy - 61),
        color: Colors.white.withOpacity(0.82), size: 12, center: true);
    _drawText(canvas, tooltipValue, Offset(anchor.dx, anchor.dy - 40),
        color: Colors.white, size: 14, center: true, bold: true);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double size,
    bool center = false,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(offset.dx - (center ? painter.width / 2 : 0), offset.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.maxValue != maxValue;
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.colors,
    required this.values,
    required this.backgroundColor,
    this.strokeWidth = 16,
  });

  final List<Color> colors;
  final List<double> values;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.max(0.0, sweep - 0.035),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
    canvas.drawCircle(center, radius - strokeWidth / 1.9, Paint()..color = backgroundColor);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.values != values ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ring);
    }
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ring,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi / 2,
      true,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF42E343).withOpacity(0.08),
            const Color(0xFF42E343).withOpacity(0.52),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RideColors {
  static const background = Color(0xFF070D14);
  static const panel = Color(0xFF171D27);
  static const orange = Color(0xFFFF4B1F);
}
