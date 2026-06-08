import 'dart:async';
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
  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<RideController>()
        ? Get.find<RideController>()
        : Get.put(RideController());

    return Scaffold(
      backgroundColor: _RideColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final selectedIndex = controller.activeTabIndex.value;
          return Column(
            children: [
              // 固定顶部栏：永远可见、永远可点（不随内容滚动）
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: _TopChrome(
                  selectedIndex: selectedIndex,
                  isConnected: selectedIndex != 3,
                ),
              ),
              // 选中页占满中间剩余空间，由各页自行决定固定子头与单一滚动区
              Expanded(
                child: _SelectedPage(
                  controller: controller,
                  selectedIndex: selectedIndex,
                ),
              ),
              // 记录中：可见的「结束并保存」入口（移动端与桌面均可点）
              if (controller.isRecording.value)
                _RecordingBar(controller: controller),
              // 固定底栏
              _RideTabBar(
                controller: controller,
                onSelect: controller.selectTab,
              ),
            ],
          );
        }),
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
                  onPressed: () => _showUiMessage('数据同步', '正在准备同步码表数据'),
                  icon: const Icon(
                    Icons.cloud_sync_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                IconButton(
                  onPressed: () => _showUiMessage('更多操作', '码表更多操作入口已激活'),
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
    // LayoutBuilder 置于有界根（由父级 Expanded 给出有限高度），不在滚动体内测高。
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: ConstrainedBox(
            // 内容不足时填满视口、超出时可滚动，绝不溢出。
            constraints: BoxConstraints(
              minHeight: math.max(0.0, constraints.maxHeight - 28),
            ),
            child: Column(
              children: [
                _ActivityHeroCard(controller: controller),
                const SizedBox(height: 12),
                _DesignMetricGrid(controller: controller),
                const SizedBox(height: 12),
                _SpeedAltitudePanel(controller: controller),
                const SizedBox(height: 12),
                const _DistributionGrid(),
              ],
            ),
          ),
        );
      },
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
                // 地图垫底
                Positioned.fill(
                  left: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: _RouteMapPainter(track: controller.points),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                // 文字内容限定在左侧区域（right:58），绝不延伸到右侧圆钮下方
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 58,
                  child: Column(
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
                ),
                // 圆钮置于最顶层，永远可点
                Positioned(
                  right: 6,
                  top: 18,
                  child: Column(
                    children: [
                      _RoundIconButton(
                        icon: Icons.fullscreen,
                        onTap: () => _showUiMessage('地图全屏', '已聚焦路线预览'),
                      ),
                      const SizedBox(height: 16),
                      _RoundIconButton(
                        icon: Icons.share_outlined,
                        onTap: () => _showUiMessage('分享路线', '路线分享入口已激活'),
                      ),
                    ],
                  ),
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
                onPressed: () => _showUiMessage('骑行详情', '点击图表可查看对应数据'),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      final List<double> speedData = controller.speedTrendKmh.isEmpty
          ? const <double>[
              32,
              28,
              35,
              20,
              34,
              30,
              38,
              27,
              31,
              34,
              25,
              36,
              33,
              29,
            ]
          : controller.speedTrendKmh.toList();
      final List<double> altitudeData = controller.altitudeTrendM.isEmpty
          ? const <double>[
              0,
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
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '速度 & 海拔',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _LegendText(
                label: '平均',
                value: '${sample.avgSpeedText} km/h',
                color: const Color(0xFF2B9DFF),
              ),
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
        final compact = constraints.maxWidth < 720;
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
                  _InteractiveDonutChart(
                    size: 104,
                    colors: colors,
                    values: distribution,
                    labels: labels,
                    details: values,
                    backgroundColor: _RideColors.panel,
                    center: Column(
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

class _StatisticsPage extends StatefulWidget {
  const _StatisticsPage({required this.controller});

  final RideController controller;

  @override
  State<_StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<_StatisticsPage> {
  var _periodIndex = 1; // 0 周 / 1 月 / 2 年 / 3 全部

  // 周/全部 的总览为示例数据（统计页定位为示例驱动的设计复刻）。
  static const _weekStats = _RideStats(
    rideCount: '5',
    totalDistance: '128.7',
    totalDuration: '05:32:18',
    totalClimb: '1586',
    calories: '4028',
    avgSpeed: '23.2',
  );
  static const _allStats = _RideStats(
    rideCount: '320',
    totalDistance: '8564.7',
    totalDuration: '360:15:42',
    totalClimb: '95688',
    calories: '245680',
    avgSpeed: '23.8',
  );

  String get _dateLabel {
    switch (_periodIndex) {
      case 0:
        return '2024/05/12 - 05/18';
      case 2:
        return '2024年';
      case 3:
        return '2023/01 - 2024/05';
      case 1:
      default:
        return '2024年5月';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final monthStats = _RideStats.from(widget.controller);
      return Column(
        children: [
          // 固定子头：周期分段 + 日期选择器（无第二顶部栏）
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Column(
              children: [
                _PeriodSegment(
                  selectedIndex: _periodIndex,
                  onSelect: (index) => setState(() => _periodIndex = index),
                ),
                const SizedBox(height: 14),
                _MonthSelector(label: _dateLabel),
              ],
            ),
          ),
          // 单一滚动区：按周期切换面板
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Column(children: _panelsForPeriod(monthStats)),
            ),
          ),
        ],
      );
    });
  }

  List<Widget> _panelsForPeriod(_RideStats monthStats) {
    switch (_periodIndex) {
      case 0:
        return _trendPanels(_weekStats, isWeek: true);
      case 2:
        return _yearPanels();
      case 3:
        return _allPanels(_allStats);
      case 1:
      default:
        return _trendPanels(monthStats, isWeek: false);
    }
  }

  // 周/月：总览 + 里程趋势 + 运动时长趋势
  List<Widget> _trendPanels(_RideStats stats, {required bool isWeek}) {
    final labels = isWeek
        ? const ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
        : const ['05/01', '05/08', '05/15', '05/22', '05/29'];
    final mileage = isWeek
        ? const <double>[18, 24, 0, 32, 27, 41, 36]
        : const <double>[
            82, 32, 74, 8, 41, 79, 11, 58, 44, 88, 99, 59, 14, 75, 80, 102, 66,
          ];
    final duration = isWeek
        ? const <double>[0.9, 1.2, 0, 1.7, 1.4, 2.1, 1.8]
        : const <double>[
            5, 2, 5, 0.5, 2.5, 4.9, 0.7, 3.4, 2.7, 5.3, 6.0, 3.7, 0.9, 4.6, 5.0,
            6.6, 4.2,
          ];
    return [
      _StatsOverview(stats: stats),
      const SizedBox(height: 12),
      _BarTrendPanel(
        title: '里程趋势',
        unit: '单位：km',
        values: mileage,
        labels: labels,
        color: _RideColors.orange,
        tooltipTitle: isWeek ? '5月15日' : '5月18日',
        tooltipValue: isWeek ? '32.4 km' : '102.6 km',
        maxValue: isWeek ? 60.0 : 120.0,
      ),
      const SizedBox(height: 12),
      _BarTrendPanel(
        title: '运动时长趋势',
        unit: '单位：小时',
        values: duration,
        labels: labels,
        color: const Color(0xFF268DFF),
        tooltipTitle: isWeek ? '5月15日' : '5月18日',
        tooltipValue: isWeek ? '1:45:28' : '3:45:28',
        maxValue: isWeek ? 3.0 : 8.0,
      ),
    ];
  }

  // 年：运动类型分布 + 月度统计 + 强度分布
  List<Widget> _yearPanels() {
    return [
      const _AnnualDistributionPanel(),
      const SizedBox(height: 12),
      _BarTrendPanel(
        title: '月度统计',
        unit: '单位：km',
        values: const <double>[320, 0, 410, 680, 920, 1026, 0, 0, 0, 0, 0, 0],
        labels: const ['1月', '3月', '5月', '7月', '9月', '11月'],
        color: _RideColors.orange,
        tooltipTitle: '5月',
        tooltipValue: '1026.3 km',
        maxValue: 1500,
      ),
      const SizedBox(height: 12),
      const _ZoneDistributionPanel(
        title: '强度分布',
        summaryLabel: '总时间',
        summaryValue: '149:48:00',
        centerText: '149:48',
        centerSubtext: '总时间',
        colors: [
          Color(0xFFFF3158),
          Color(0xFFFF7A1A),
          Color(0xFFFFD21A),
          Color(0xFF4AD14A),
          Color(0xFF268DFF),
        ],
        labels: [
          'Z5  > 178 bpm',
          'Z4  162 - 178 bpm',
          'Z3  140 - 160 bpm',
          'Z2  120 - 140 bpm',
          'Z1  < 120 bpm',
        ],
        values: ['08:36   6%', '26:18   17%', '55:21   36%', '48:23   31%', '11:10   10%'],
        distribution: [0.06, 0.17, 0.36, 0.31, 0.10],
      ),
    ];
  }

  // 全部：总览 + 运动类型分布 + 月度里程趋势
  List<Widget> _allPanels(_RideStats stats) {
    return [
      _StatsOverview(stats: stats),
      const SizedBox(height: 12),
      const _AnnualDistributionPanel(),
      const SizedBox(height: 12),
      _BarTrendPanel(
        title: '月度里程趋势',
        unit: '单位：km',
        values: const <double>[
          320, 280, 410, 680, 920, 1026, 760, 540, 620, 880, 700, 430,
        ],
        labels: const ['1月', '3月', '5月', '7月', '9月', '11月'],
        color: _RideColors.orange,
        tooltipTitle: '5月',
        tooltipValue: '1026.3 km',
        maxValue: 1500,
      ),
    ];
  }
}

class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

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
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(i),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 2 : 3;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                childAspectRatio: columns == 2 ? 1.72 : 1.34,
                mainAxisSpacing: 12,
                crossAxisSpacing: 10,
                children: [
                  _OverviewMetric(
                    label: '活动次数',
                    value: stats.rideCount,
                    unit: '次',
                  ),
                  _OverviewMetric(
                    label: '总里程',
                    value: stats.totalDistance,
                    unit: 'km',
                  ),
                  _OverviewMetric(
                    label: '总时间',
                    value: stats.totalDuration,
                    unit: '',
                  ),
                  _OverviewMetric(
                    label: '总爬升',
                    value: stats.totalClimb,
                    unit: 'm',
                  ),
                  _OverviewMetric(
                    label: '总消耗',
                    value: stats.calories,
                    unit: 'kcal',
                  ),
                  _OverviewMetric(
                    label: '平均速度',
                    value: stats.avgSpeed,
                    unit: 'km/h',
                  ),
                ],
              );
            },
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.56),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              maxLines: 1,
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
          ),
        ],
      ),
    );
  }
}

class _BarTrendPanel extends StatefulWidget {
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
  State<_BarTrendPanel> createState() => _BarTrendPanelState();
}

class _BarTrendPanelState extends State<_BarTrendPanel> {
  Timer? _hideTimer;
  int? _tooltipIndex;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showTooltip(int index) {
    _hideTimer?.cancel();
    setState(() => _tooltipIndex = index);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _tooltipIndex = null);
    });
  }

  int? _indexForTap(Offset local, Size size) {
    if (widget.values.isEmpty || size.width <= 54 || size.height <= 52) {
      return null;
    }
    final chartRect = Rect.fromLTWH(34, 26, size.width - 54, size.height - 52);
    if (!chartRect.inflate(18).contains(local)) return null;
    final raw =
        ((local.dx - chartRect.left) / chartRect.width * widget.values.length)
            .floor();
    if (raw < 0) return 0;
    if (raw >= widget.values.length) return widget.values.length - 1;
    return raw;
  }

  String _tooltipTitleFor(int index) {
    if (widget.title.contains('趋势')) {
      final day = math.min(31, index * 2 + 1);
      return '5月$day日';
    }
    return widget.tooltipTitle;
  }

  String _tooltipValueFor(int index) {
    final value = widget.values[index];
    if (widget.unit.contains('小时')) {
      return value >= 1
          ? '${value.toStringAsFixed(1)} 小时'
          : '${(value * 60).round()} 分钟';
    }
    return '${value.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                widget.unit,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final selectedIndex = _tooltipIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final index = _indexForTap(details.localPosition, size);
                    if (index != null) _showTooltip(index);
                  },
                  child: CustomPaint(
                    painter: _BarChartPainter(
                      values: widget.values,
                      labels: widget.labels,
                      color: widget.color,
                      maxValue: widget.maxValue,
                      tooltipIndex: selectedIndex,
                      tooltipTitle: selectedIndex == null
                          ? widget.tooltipTitle
                          : _tooltipTitleFor(selectedIndex),
                      tooltipValue: selectedIndex == null
                          ? widget.tooltipValue
                          : _tooltipValueFor(selectedIndex),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
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
    const colors = [
      _RideColors.orange,
      Color(0xFF268DFF),
      Color(0xFF62D729),
    ];
    const distribution = [0.85, 0.10, 0.05];
    const labels = ['户外骑行', '室内骑行', '其他运动'];
    const details = ['872.3 km  85%', '102.4 km  10%', '51.6 km  5%'];

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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 400;
              final legend = Column(
                children: const [
                  _DistributionRow(
                    color: _RideColors.orange,
                    label: '户外骑行',
                    value: '872.3 km',
                    ratio: '85%',
                  ),
                  SizedBox(height: 18),
                  _DistributionRow(
                    color: Color(0xFF268DFF),
                    label: '室内骑行',
                    value: '102.4 km',
                    ratio: '10%',
                  ),
                  SizedBox(height: 18),
                  _DistributionRow(
                    color: Color(0xFF62D729),
                    label: '其他运动',
                    value: '51.6 km',
                    ratio: '5%',
                  ),
                ],
              );
              final donut = _InteractiveDonutChart(
                size: compact ? 136 : 148,
                strokeWidth: 25,
                colors: colors,
                values: distribution,
                labels: labels,
                details: details,
                backgroundColor: _RideColors.panel,
                center: Column(
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
              );

              if (compact) {
                return Column(
                  children: [
                    legend,
                    const SizedBox(height: 16),
                    donut,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: legend),
                  const SizedBox(width: 20),
                  donut,
                ],
              );
            },
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

class _InteractiveDonutChart extends StatefulWidget {
  const _InteractiveDonutChart({
    required this.size,
    required this.colors,
    required this.values,
    required this.labels,
    required this.details,
    required this.backgroundColor,
    required this.center,
    this.strokeWidth = 16,
  });

  final double size;
  final List<Color> colors;
  final List<double> values;
  final List<String> labels;
  final List<String> details;
  final Color backgroundColor;
  final Widget center;
  final double strokeWidth;

  @override
  State<_InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<_InteractiveDonutChart> {
  Timer? _hideTimer;
  int? _selectedIndex;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final index = _segmentForTap(details.localPosition);
    if (index == null) return;
    _hideTimer?.cancel();
    setState(() => _selectedIndex = index);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _selectedIndex = null);
    });
  }

  int? _segmentForTap(Offset local) {
    if (widget.values.isEmpty) return null;
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;
    final distance = delta.distance;
    final radius = widget.size * 0.38;
    if (distance > radius + widget.strokeWidth) return null;

    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    while (angle < 0) {
      angle += math.pi * 2;
    }
    while (angle >= math.pi * 2) {
      angle -= math.pi * 2;
    }

    final total = widget.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return null;
    final target = angle / (math.pi * 2) * total;
    var cursor = 0.0;
    for (var i = 0; i < widget.values.length; i++) {
      cursor += widget.values[i];
      if (target <= cursor) return i;
    }
    return widget.values.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    final tooltip = selected == null
        ? null
        : '${widget.labels[selected]}\n${widget.details[selected]}';

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: _DonutPainter(
                colors: widget.colors,
                values: widget.values,
                backgroundColor: widget.backgroundColor,
                strokeWidth: widget.strokeWidth,
                selectedIndex: selected,
              ),
              child: const SizedBox.expand(),
            ),
            widget.center,
            Positioned(
              top: -8,
              left: -24,
              right: -24,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: tooltip == null ? 0 : 1,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303744).withOpacity(0.96),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        tooltip ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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

class _RoutesPage extends StatefulWidget {
  const _RoutesPage();

  @override
  State<_RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<_RoutesPage> {
  var _modeIndex = 0;

  static const _cards = <_RouteListCard>[
    _RouteListCard(
      title: '周末环山路线',
      date: '2024/05/18  08:32',
      distance: '102.63',
      climb: '1268',
      duration: '03:45:28',
      difficulty: '中等',
      difficultyColor: Color(0xFFA46AFF),
      variant: 0,
    ),
    _RouteListCard(
      title: '滨海骑行路线',
      date: '2024/05/12  07:15',
      distance: '65.28',
      climb: '512',
      duration: '02:28:16',
      difficulty: '简单',
      difficultyColor: Color(0xFF62D729),
      variant: 1,
    ),
    _RouteListCard(
      title: '城市探索路线',
      date: '2024/05/05  09:42',
      distance: '88.47',
      climb: '876',
      duration: '03:12:45',
      difficulty: '困难',
      difficultyColor: Color(0xFFFF3B5F),
      variant: 2,
    ),
    _RouteListCard(
      title: '晨间训练路线',
      date: '2024/04/28  06:30',
      distance: '45.16',
      climb: '321',
      duration: '01:48:22',
      difficulty: '简单',
      difficultyColor: Color(0xFF62D729),
      variant: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final routeCountLabel = switch (_modeIndex) {
      1 => '收藏路线（6）',
      2 => '导入路线（3）',
      _ => '路线（18）',
    };

    return Column(
      children: [
        // 固定子头：模式分段 + 搜索 + 计数（无第二顶部栏）
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: [
              _RouteModeTabs(
                selectedIndex: _modeIndex,
                onSelect: (index) => setState(() => _modeIndex = index),
              ),
              const SizedBox(height: 12),
              const _RouteSearchBar(),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  routeCountLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 单一滚动区：路线卡片列表
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            itemCount: _cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = _cards[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Get.to(
                  () => _RideRouteDetailPage(
                    title: c.title,
                    date: c.date,
                    distance: c.distance,
                    climb: c.climb,
                    duration: c.duration,
                    difficulty: c.difficulty,
                    difficultyColor: c.difficultyColor,
                    variant: c.variant,
                  ),
                ),
                child: c,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RouteModeTabs extends StatelessWidget {
  const _RouteModeTabs({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['我的路线', '收藏路线', '导入路线'];
    return _OuterFrame(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(i),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? _RideColors.orange.withOpacity(0.13)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: i == selectedIndex
                        ? Border.all(
                            color: _RideColors.orange.withOpacity(0.85),
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selectedIndex
                          ? _RideColors.orange
                          : Colors.white.withOpacity(0.70),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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
                Expanded(
                  child: Text(
                    '搜索路线名称或地点',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final cardHeight = compact ? 194.0 : 176.0;
          final mapWidth = compact ? 118.0 : 148.0;
          final titleSize = compact ? 18.0 : 20.0;

          return SizedBox(
            height: cardHeight,
            child: Row(
              children: [
                SizedBox(
                  width: mapWidth,
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
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 16,
                      16,
                      12,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
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
                          spacing: compact ? 10 : 14,
                          runSpacing: 4,
                          children: [
                            _RouteMetric(value: distance, unit: 'km'),
                            _RouteMetric(value: climb, unit: 'm'),
                            _RouteMetric(value: duration, unit: ''),
                          ],
                        ),
                        Divider(
                          color: Colors.white.withOpacity(0.08),
                          height: 18,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.star_border,
                              color: Colors.white.withOpacity(0.68),
                            ),
                            const SizedBox(width: 28),
                            Icon(
                              Icons.share_outlined,
                              color: Colors.white.withOpacity(0.68),
                            ),
                            const SizedBox(width: 28),
                            Icon(
                              Icons.more_horiz,
                              color: Colors.white.withOpacity(0.68),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (actions.isEmpty) const SizedBox(width: 48) else ...actions,
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideRouteDetailPage extends StatelessWidget {
  const _RideRouteDetailPage({
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
    return Scaffold(
      backgroundColor: _RideColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DetailTopBar(
              title: '路线详情',
              actions: [
                IconButton(
                  onPressed: () => _showUiMessage('收藏', '已收藏该路线'),
                  icon: Icon(Icons.star_border, color: Colors.white.withOpacity(0.9)),
                ),
                IconButton(
                  onPressed: () => _showUiMessage('更多', '更多操作入口已激活'),
                  icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassPanel(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: 230,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: CustomPaint(
                                  painter: _RouteMapPainter(variant: variant),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: _RoundIconButton(
                                icon: Icons.fullscreen,
                                onTap: () =>
                                    _showUiMessage('地图全屏', '已聚焦路线预览'),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: _RoundIconButton(
                                icon: Icons.share_outlined,
                                onTap: () =>
                                    _showUiMessage('分享路线', '路线分享入口已激活'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3BE23E).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF3BE23E)),
                          ),
                          child: const Text(
                            '公开',
                            style: TextStyle(
                              color: Color(0xFF3BE23E),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _RouteMetric(value: distance, unit: 'km'),
                        const SizedBox(width: 34),
                        _RouteMetric(value: climb, unit: 'm'),
                        const SizedBox(width: 34),
                        _RouteMetric(value: duration, unit: ''),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _RouteBadge(label: '公路', color: _RideColors.orange),
                        const SizedBox(width: 8),
                        _RouteBadge(
                            label: '难度 $difficulty', color: difficultyColor),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '路线简介',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '这是一条经典的环山路线，适合有一定经验的骑友。路线包含平路、爬坡与下坡，沿途风景优美，建议早晨出发，注意补给和防晒。',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '海拔图',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '累计爬升 $climb m',
                                style: const TextStyle(
                                  color: Color(0xFFA533FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: CustomPaint(
                              painter: const _SparklinePainter(
                                values: [
                                  120, 180, 260, 420, 700, 980, 1180, 1268,
                                  1040, 760, 520, 360, 240, 160,
                                ],
                                color: Color(0xFFA533FF),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GlassPanel(
                      child: Column(
                        children: const [
                          _DetailInfoRow(label: '起点', value: '杭州市 西湖区'),
                          _DetailInfoRow(label: '终点', value: '杭州市 西湖区'),
                          _DetailInfoRow(
                              label: '最高海拔', value: '1268 m', last: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部固定操作栏
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF101720),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showUiMessage('发送到设备', '已发送路线到设备'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          side: BorderSide(color: Colors.white.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '发送到设备',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showUiMessage('导航', '开始导航'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _RideColors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '导航',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
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

class _DevicesPage extends StatelessWidget {
  const _DevicesPage({required this.controller});

  final RideController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 固定子头：扫描雷达 + 停止扫描（本地视觉状态，不接真实 BleController）
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: _ScanPanel(controller: controller),
        ),
        const SizedBox(height: 12),
        // 单一滚动区：可用设备列表
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: const _AvailableDevicesPanel(),
          ),
        ),
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
            height: 210,
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
          _DeviceRow(
            title: 'iGPSPORT BSC300_1234',
            type: '码表',
            bars: 4,
            onTap: () => Get.to(
              () => const _RideDeviceDetailPage(
                name: 'iGPSPORT BSC300_1234',
                type: '码表',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DeviceRow(
            title: 'iGPSPORT SR30_5678',
            type: '雷达',
            bars: 4,
            onTap: () => Get.to(
              () => const _RideDeviceDetailPage(
                name: 'iGPSPORT SR30_5678',
                type: '雷达',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DeviceRow(
            title: 'iGPSPORT HR40_9012',
            type: '心率带',
            bars: 3,
            onTap: () => Get.to(
              () => const _RideDeviceDetailPage(
                name: 'iGPSPORT HR40_9012',
                type: '心率带',
              ),
            ),
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
    this.onTap,
  });

  final String title;
  final String type;
  final int bars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18)),
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
              onPressed:
                  onTap ?? () => _showUiMessage('连接设备', '$title 正在连接...'),
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
  const _ConnectedDevicePanel({
    this.deviceName = 'iGPSPORT BSC300_1234',
    this.deviceType = '码表',
  });

  final String deviceName;
  final String deviceType;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DeviceThumbnail(kind: deviceType),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
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
        ],
      ),
    );
  }
}

class _DeviceInfoPanel extends StatelessWidget {
  const _DeviceInfoPanel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设备信息',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          _DetailInfoRow(label: '设备名称', value: name),
          const _DetailInfoRow(label: '序列号', value: 'SN1234567890'),
          const _DetailInfoRow(label: '固件版本', value: 'v1.23.0'),
          const _DetailInfoRow(label: '硬件版本', value: 'v1.0'),
          const _DetailInfoRow(
              label: 'MAC 地址', value: 'D0:55:3C:12:34:56', last: true),
        ],
      ),
    );
  }
}

class _RideDeviceDetailPage extends StatelessWidget {
  const _RideDeviceDetailPage({required this.name, required this.type});

  final String name;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RideColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DetailTopBar(
              title: '设备',
              actions: [
                IconButton(
                  onPressed: () => _showUiMessage('更多', '更多操作入口已激活'),
                  icon:
                      Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  children: [
                    _ConnectedDevicePanel(deviceName: name, deviceType: type),
                    const SizedBox(height: 12),
                    _DeviceInfoPanel(name: name),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => _showUiMessage('解除绑定', '已打开设备解绑确认'),
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
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 70),
      child: Container(
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

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.controller});

  final RideController controller;

  void _confirmFinish() {
    Get.defaultDialog(
      title: '结束骑行',
      middleText: '确定结束并保存本次骑行吗？',
      textConfirm: '结束并保存',
      textCancel: '继续骑行',
      confirmTextColor: Colors.white,
      buttonColor: _RideColors.orange,
      onConfirm: () {
        Get.back();
        controller.saveCurrentRide();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final paused = controller.isPaused.value;
      final elapsed = controller.elapsed.value;
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF12181F),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paused
                    ? const Color(0xFFFFC400)
                    : const Color(0xFF3BE23E),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              paused ? '已暂停' : '记录中',
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatDuration(elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _confirmFinish,
              style: TextButton.styleFrom(
                foregroundColor: _RideColors.orange,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              icon: const Icon(Icons.stop_circle, size: 20),
              label: const Text('结束并保存'),
            ),
          ],
        ),
      );
    });
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
                  icon: Icons.explore,
                  label: '路线',
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
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
  const _RouteMapPainter({this.variant = 0, this.track = const []});

  final int variant;
  final List<RidePoint> track;

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
    // 有有效真实轨迹则画真实轨迹，否则兜底示例环线
    final projected = _projectTrack(size);
    if (projected != null) {
      _drawPolyline(canvas, projected);
    } else {
      _drawRoute(canvas, size);
    }
  }

  // 将真实 GPS 轨迹等比投影到画布；点不足/坐标非法/跨度过小时返回 null（兜底）
  List<Offset>? _projectTrack(Size size) {
    if (track.length < 2) return null;
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLon = double.infinity;
    var maxLon = -double.infinity;
    var valid = 0;
    for (final p in track) {
      final lat = p.latitude;
      final lon = p.longitude;
      if (!lat.isFinite || !lon.isFinite) continue;
      if (lat == 0 && lon == 0) continue;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLon = math.min(minLon, lon);
      maxLon = math.max(maxLon, lon);
      valid++;
    }
    if (valid < 2) return null;
    final latSpan = maxLat - minLat;
    final lonSpan = maxLon - minLon;
    if (latSpan <= 1e-7 && lonSpan <= 1e-7) return null;
    const pad = 16.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0) return null;
    final span = math.max(latSpan, lonSpan);
    final scale = math.min(w, h) / span;
    final offsetX = pad + (w - lonSpan * scale) / 2;
    final offsetY = pad + (h - latSpan * scale) / 2;
    final pts = <Offset>[];
    for (final p in track) {
      final lat = p.latitude;
      final lon = p.longitude;
      if (!lat.isFinite || !lon.isFinite) continue;
      if (lat == 0 && lon == 0) continue;
      final x = offsetX + (lon - minLon) * scale;
      final y = offsetY + (maxLat - lat) * scale;
      pts.add(Offset(x, y));
    }
    return pts.length >= 2 ? pts : null;
  }

  void _drawPolyline(Canvas canvas, List<Offset> pts) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.34)
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, shadow);
    for (var i = 0; i < pts.length - 1; i++) {
      final t = pts.length <= 2 ? 0.0 : i / (pts.length - 2);
      final color =
          Color.lerp(const Color(0xFF57DF43), const Color(0xFFFF4B24), t)!;
      canvas.drawPath(
        Path()
          ..moveTo(pts[i].dx, pts[i].dy)
          ..lineTo(pts[i + 1].dx, pts[i + 1].dy),
        Paint()
          ..color = color
          ..strokeWidth = 5.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(pts.first, 9, Paint()..color = const Color(0xFF5FE052));
    canvas.drawCircle(pts.first, 4, Paint()..color = Colors.white);
    canvas.drawCircle(pts.last, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
        pts.last, 4, Paint()..color = Colors.black.withOpacity(0.78));
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
    return oldDelegate.variant != variant || oldDelegate.track != track;
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
    if (data.length < 2 || maxValue <= 0) return;
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
  final int? tooltipIndex;
  final String tooltipTitle;
  final String tooltipValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || maxValue <= 0) return;
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
      final x = labels.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (labels.length - 1);
      _drawText(
        canvas,
        labels[i],
        Offset(x, size.height - 20),
        color: Colors.white.withOpacity(0.48),
        size: 12,
        center: true,
      );
    }

    final selectedIndex = tooltipIndex;
    if (selectedIndex == null || selectedIndex >= values.length) return;
    final markerX =
        chartRect.left + chartRect.width * (selectedIndex + 0.5) / values.length;
    final markerY = chartRect.bottom -
        chartRect.height * values[selectedIndex].clamp(0, maxValue) / maxValue;
    _drawTooltip(canvas, Offset(markerX, markerY - 10), size);
  }

  void _drawTooltip(Canvas canvas, Offset anchor, Size size) {
    final centerX = math.min(
      math.max(anchor.dx, 43.0),
      math.max(43.0, size.width - 43.0),
    );
    final centerY = math.max(anchor.dy, 70.0);
    final adjustedAnchor = Offset(centerX, centerY);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: adjustedAnchor.translate(0, -36),
        width: 86,
        height: 58,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF303744).withOpacity(0.96),
    );
    final pointer = Path()
      ..moveTo(adjustedAnchor.dx - 8, adjustedAnchor.dy - 8)
      ..lineTo(adjustedAnchor.dx + 8, adjustedAnchor.dy - 8)
      ..lineTo(adjustedAnchor.dx, adjustedAnchor.dy + 1)
      ..close();
    canvas.drawPath(
      pointer,
      Paint()..color = const Color(0xFF303744).withOpacity(0.96),
    );
    _drawText(canvas, tooltipTitle, Offset(adjustedAnchor.dx, adjustedAnchor.dy - 61),
        color: Colors.white.withOpacity(0.82), size: 12, center: true);
    _drawText(canvas, tooltipValue, Offset(adjustedAnchor.dx, adjustedAnchor.dy - 40),
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
        oldDelegate.maxValue != maxValue ||
        oldDelegate.tooltipIndex != tooltipIndex ||
        oldDelegate.tooltipTitle != tooltipTitle ||
        oldDelegate.tooltipValue != tooltipValue;
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.colors,
    required this.values,
    required this.backgroundColor,
    this.strokeWidth = 16,
    this.selectedIndex,
  });

  final List<Color> colors;
  final List<double> values;
  final Color backgroundColor;
  final double strokeWidth;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    var start = -math.pi / 2;
    final hasSelection = selectedIndex != null;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2;
      final isSelected = selectedIndex == i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.max(0.0, sweep - 0.035),
        false,
        Paint()
          ..color = hasSelection && !isSelected
              ? colors[i].withOpacity(0.42)
              : colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? strokeWidth + 3 : strokeWidth
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
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.selectedIndex != selectedIndex;
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

void _showUiMessage(String title, String message) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 2),
  );
}

class _RideColors {
  static const background = Color(0xFF070D14);
  static const panel = Color(0xFF171D27);
  static const orange = Color(0xFFFF4B1F);
}
