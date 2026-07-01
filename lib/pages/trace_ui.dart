import 'dart:math' as math;

import 'package:flutter/material.dart';

class TraceColors {
  static const ink = Color(0xFF06141D);
  static const deep = Color(0xFF082735);
  static const ocean = Color(0xFF0B4F5C);
  static const cyan = Color(0xFF3EF7D4);
  static const cyanSoft = Color(0xFF79FFE5);
  static const mint = Color(0xFF9AF7C9);
  static const amber = Color(0xFFFFC66E);
  static const rose = Color(0xFFFF6E9F);
  static const text = Color(0xFFEAFDF7);
  static const muted = Color(0xFFA3C7C2);
}

class TraceTheme {
  static const double bottomNavHeight = 92;

  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      TraceColors.ink,
      Color(0xFF09212E),
      TraceColors.deep,
      Color(0xFF051019),
    ],
  );
}

class TracePageScaffold extends StatelessWidget {
  const TracePageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.ink,
      body: Container(
        decoration: const BoxDecoration(gradient: TraceTheme.pageGradient),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: TraceAtmospherePainter()),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class TraceAtmospherePainter extends CustomPainter {
  const TraceAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = TraceColors.cyan.withOpacity(0.035)
      ..strokeWidth = 1;

    const step = 34.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        gridPaint,
      );
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          TraceColors.cyan.withOpacity(0.22),
          TraceColors.ocean.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.22),
          radius: size.width * 0.85,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.22),
      size.width * 0.85,
      glowPaint,
    );

    final amberPaint = Paint()
      ..shader = RadialGradient(
        colors: [TraceColors.amber.withOpacity(0.14), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.94, size.height * 0.1),
          radius: size.width * 0.42,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.1),
      size.width * 0.42,
      amberPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TraceAtmospherePainter oldDelegate) => false;
}

class TraceGlassPanel extends StatelessWidget {
  const TraceGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 28,
    this.glowColor = TraceColors.cyan,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.12),
            blurRadius: 26,
            spreadRadius: -10,
          ),
        ],
      ),
      child: child,
    );
  }
}

class TracePageTitle extends StatelessWidget {
  const TracePageTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: TraceColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: TraceColors.text,
                  fontSize: 34,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  color: TraceColors.muted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class TracePill extends StatelessWidget {
  const TracePill({
    super.key,
    required this.icon,
    required this.label,
    this.color = TraceColors.cyan,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
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
    );
  }
}

class TraceOrbitPainter extends CustomPainter {
  const TraceOrbitPainter({this.progress = 1});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.39;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = TraceColors.cyan.withOpacity(0.23 * progress);

    for (final factor in [0.55, 0.78, 1.0]) {
      canvas.drawCircle(center, radius * factor, ringPaint);
    }

    final tickPaint = Paint()
      ..color = TraceColors.cyanSoft.withOpacity(0.4 * progress)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 48; i++) {
      final angle = (math.pi * 2 / 48) * i;
      final isMajor = i % 6 == 0;
      final start = radius * (isMajor ? 0.93 : 0.97);
      final end = radius * 1.03;
      canvas.drawLine(
        center + Offset(math.cos(angle) * start, math.sin(angle) * start),
        center + Offset(math.cos(angle) * end, math.sin(angle) * end),
        tickPaint,
      );
    }

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          TraceColors.cyan,
          TraceColors.mint,
          Colors.transparent,
        ],
        stops: [0, 0.42, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -math.pi / 2,
      math.pi * 1.6 * progress,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TraceOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
