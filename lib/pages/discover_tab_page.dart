import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'trace_ui.dart';

class DiscoverTabPage extends StatelessWidget {
  const DiscoverTabPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                eyebrow: 'DISCOVERY LOG',
                title: '发现',
                subtitle: '把功率计、码表、遥控和更新能力整理成可快速浏览的使用指南。',
                trailing: TracePill(
                  icon: Icons.travel_explore,
                  label: 'GUIDE',
                  color: TraceColors.cyan,
                ),
              ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.16, end: 0),
              const SizedBox(height: 16),
              const _DiscoverRadarStage()
                  .animate(delay: 120.ms)
                  .fadeIn(duration: 620.ms)
                  .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
              const SizedBox(height: 18),
              const _SectionHeader(title: '功能指南', code: '01-03'),
              const SizedBox(height: 12),
              const _GuideTimeline()
                  .animate(delay: 220.ms)
                  .fadeIn(duration: 560.ms)
                  .slideY(begin: 0.14, end: 0),
              const SizedBox(height: 18),
              const _SectionHeader(title: '静态内容', code: 'INFO'),
              const SizedBox(height: 12),
              const _InfoBento()
                  .animate(delay: 320.ms)
                  .fadeIn(duration: 560.ms)
                  .slideY(begin: 0.14, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverRadarStage extends StatelessWidget {
  const _DiscoverRadarStage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = math.min(constraints.maxWidth, 390.0);
        final stageHeight = math.max(outerWidth * 0.94, 338.0);

        return Center(
          child: SizedBox(
            width: outerWidth,
            child: TraceGlassPanel(
              padding: const EdgeInsets.all(12),
              borderRadius: 34,
              glowColor: TraceColors.mint,
              child: SizedBox(
                height: stageHeight,
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final width = innerConstraints.maxWidth;
                    final hubSize = math.min(width * 0.4, 142.0);
                    final beaconWidth = math.min(width * 0.25, 86.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: TraceOrbitPainter(progress: 0.76)),
                        ),
                        Positioned(
                          top: 16,
                          left: 18,
                          right: 18,
                          child: Row(
                            children: [
                              const TracePill(
                                icon: Icons.auto_awesome,
                                label: 'BLE Monitor',
                                color: TraceColors.mint,
                              ),
                              const Spacer(),
                              Text(
                                'LOCAL ONLY',
                                style: TextStyle(
                                  color: TraceColors.cyan.withOpacity(0.54),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: stageHeight * 0.42,
                          child: _DiscoverBeacon(
                            width: beaconWidth,
                            title: '扫描',
                            code: '01',
                            icon: Icons.radar,
                            color: TraceColors.cyan,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: stageHeight * 0.42,
                          child: _DiscoverBeacon(
                            width: beaconWidth,
                            title: '控制',
                            code: '02',
                            icon: Icons.settings_remote,
                            color: TraceColors.amber,
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: (width - beaconWidth) / 2,
                          child: _DiscoverBeacon(
                            width: beaconWidth,
                            title: '更新',
                            code: '03',
                            icon: Icons.system_update_alt,
                            color: TraceColors.mint,
                          ),
                        ),
                        Container(
                          width: hubSize,
                          height: hubSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                TraceColors.mint.withOpacity(0.32),
                                TraceColors.ocean.withOpacity(0.2),
                                TraceColors.ink.withOpacity(0.96),
                              ],
                            ),
                            border: Border.all(color: TraceColors.cyan.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: TraceColors.mint.withOpacity(0.28),
                                blurRadius: 44,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.travel_explore, color: TraceColors.cyan, size: 36),
                              SizedBox(height: 8),
                              Text(
                                '发现',
                                style: TextStyle(
                                  color: TraceColors.text,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'GUIDE MAP',
                                style: TextStyle(
                                  color: TraceColors.muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          top: 64,
                          child: IgnorePointer(
                            child: Text(
                              '纯前端发现页，只展示现有能力入口说明，不引入购买、账号或社区后端。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TraceColors.muted.withOpacity(0.72),
                                fontSize: 11,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

class _DiscoverBeacon extends StatelessWidget {
  const _DiscoverBeacon({
    required this.width,
    required this.title,
    required this.code,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String code;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF071B25).withOpacity(0.9),
        border: Border.all(color: color.withOpacity(0.38)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TraceColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            code,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideTimeline extends StatelessWidget {
  const _GuideTimeline();

  static const guides = [
    _GuideItem(
      number: '01',
      title: '功率计使用指南',
      body: '扫描并选择 BLE 设备，进入监控后可保存设备用于长期查看。',
      icon: Icons.electric_meter,
      color: TraceColors.cyan,
    ),
    _GuideItem(
      number: '02',
      title: '码表入门',
      body: '连接码表设备，查看骑行数据，并在需要时执行 OTA 升级。',
      icon: Icons.speed,
      color: TraceColors.mint,
    ),
    _GuideItem(
      number: '03',
      title: '遥控教程',
      body: '连接蓝牙设备，自定义控制按钮，并发送控制指令。',
      icon: Icons.settings_remote,
      color: TraceColors.amber,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TraceGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      borderRadius: 30,
      child: Column(
        children: [
          for (var i = 0; i < guides.length; i++) ...[
            _GuideRow(item: guides[i]),
            if (i != guides.length - 1)
              Divider(color: Colors.white.withOpacity(0.08), height: 14),
          ],
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.item});

  final _GuideItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withOpacity(0.12),
              border: Border.all(color: item.color.withOpacity(0.28)),
            ),
            child: Icon(item.icon, color: item.color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.number}  ${item.title}',
                  style: const TextStyle(
                    color: TraceColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.body,
                  style: TextStyle(
                    color: TraceColors.muted.withOpacity(0.86),
                    fontSize: 12,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
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

class _InfoBento extends StatelessWidget {
  const _InfoBento();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                title: '更新公告',
                body: '检查 Cloudflare 增量更新，保持当前版本能力。',
                icon: Icons.system_update_alt,
                color: TraceColors.cyan,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _InfoCard(
                title: '使用技巧',
                body: '功率计、码表、遥控入口都从设备页进入。',
                icon: Icons.tips_and_updates_outlined,
                color: TraceColors.mint,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        _InfoCard(
          title: '常见问题',
          body: '扫描不到设备时，请确认蓝牙权限、设备可发现状态和系统蓝牙开关。',
          icon: Icons.help_outline,
          color: TraceColors.amber,
          wide: true,
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return TraceGlassPanel(
      padding: EdgeInsets.all(wide ? 16 : 14),
      borderRadius: 24,
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: wide ? 16 : 14),
          Text(
            title,
            style: const TextStyle(
              color: TraceColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: TraceColors.muted.withOpacity(0.86),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.code});

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: TraceColors.cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: TraceColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          code,
          style: TextStyle(
            color: TraceColors.cyan.withOpacity(0.58),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _GuideItem {
  const _GuideItem({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String number;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
}
