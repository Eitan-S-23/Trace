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
            20,
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
              const SizedBox(height: 20),
              const _DiscoverHero()
                  .animate(delay: 120.ms)
                  .fadeIn(duration: 620.ms)
                  .scale(begin: Offset(0.96, 0.96)),
              const SizedBox(height: 20),
              const _SectionHeader(title: '功能指南', code: '01-03'),
              const SizedBox(height: 12),
              const _GuideTimeline()
                  .animate(delay: 220.ms)
                  .fadeIn(duration: 560.ms)
                  .slideY(begin: 0.14, end: 0),
              const SizedBox(height: 20),
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

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero();

  @override
  Widget build(BuildContext context) {
    return TraceGlassPanel(
      padding: const EdgeInsets.all(18),
      glowColor: TraceColors.mint,
      child: SizedBox(
        height: 236,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: TraceOrbitPainter(progress: 0.72)),
            ),
            Positioned(
              right: -6,
              top: 10,
              child: Icon(
                Icons.bluetooth_searching,
                color: TraceColors.cyan.withOpacity(0.34),
                size: 112,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TracePill(
                  icon: Icons.auto_awesome,
                  label: '快速了解 BLE Monitor',
                  color: TraceColors.mint,
                ),
                const Spacer(),
                const Text(
                  '从扫描到控制，\n按现有能力开始。',
                  style: TextStyle(
                    color: TraceColors.text,
                    fontSize: 28,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '这里是纯前端发现页，不引入购买、账号、社区或新增后端数据。',
                  style: TextStyle(
                    color: TraceColors.muted.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
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
    return Column(
      children: [
        for (var i = 0; i < guides.length; i++) ...[
          _GuideCard(item: guides[i]),
          if (i != guides.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.item});

  final _GuideItem item;

  @override
  Widget build(BuildContext context) {
    return TraceGlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 24,
      glowColor: item.color,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withOpacity(0.12),
              border: Border.all(color: item.color.withOpacity(0.28)),
            ),
            child: Icon(item.icon, color: item.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.number}  ${item.title}',
                  style: const TextStyle(
                    color: TraceColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: TextStyle(
                    color: TraceColors.muted.withOpacity(0.86),
                    fontSize: 12,
                    height: 1.45,
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