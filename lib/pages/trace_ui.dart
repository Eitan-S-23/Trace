import 'dart:math' as math;

import 'package:flutter/material.dart';

class TraceColors {
  static const ink = Color(0xFF02070C);
  static const deep = Color(0xFF061821);
  static const ocean = Color(0xFF0B3540);
  static const cyan = Color(0xFF24F6DE);
  static const cyanSoft = Color(0xFF8DFFF0);
  static const mint = Color(0xFF5EF1C7);
  static const amber = Color(0xFFFFCF66);
  static const rose = Color(0xFFFF5E8E);
  static const text = Color(0xFFEAFDF7);
  static const muted = Color(0xFF8FB8B6);
}

class TraceTheme {
  static const double bottomNavHeight = 92;

  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      TraceColors.ink,
      Color(0xFF04111A),
      TraceColors.deep,
      Color(0xFF010409),
    ],
  );
}

class TracePageScaffold extends StatelessWidget {
  const TracePageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: TraceTheme.pageGradient),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: TraceAtmospherePainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class TraceAtmospherePainter extends CustomPainter {
  const TraceAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = TraceColors.cyan.withOpacity(0.026)
      ..strokeWidth = 1;

    const step = 36.0;
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
          TraceColors.cyan.withOpacity(0.2),
          TraceColors.ocean.withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.28, size.height * 0.28),
          radius: size.width * 0.85,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.28),
      size.width * 0.85,
      glowPaint,
    );

    final cornerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [TraceColors.cyanSoft.withOpacity(0.1), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.94, size.height * 0.14),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.14),
      size.width * 0.5,
      cornerGlowPaint,
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
        color: const Color(0xFF071923).withOpacity(0.76),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: glowColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.36),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.14),
            blurRadius: 34,
            spreadRadius: -12,
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
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.6,
                  shadows: [
                    Shadow(
                      color: Color(0x5524F6DE),
                      blurRadius: 18,
                    ),
                  ],
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

class TraceFirstViewportSpacer extends StatelessWidget {
  const TraceFirstViewportSpacer({
    super.key,
    required this.consumedHeight,
    this.minHeight = 84,
  });

  final double consumedHeight;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight = media.size.height - media.padding.top - media.padding.bottom;
    final navReserve = TraceTheme.bottomNavHeight + 24;
    final height = safeHeight - consumedHeight - navReserve;
    return SizedBox(height: math.max(minHeight, height));
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

class TraceOrbitAction {
  const TraceOrbitAction({
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

class TraceRadialConsole extends StatelessWidget {
  const TraceRadialConsole({
    super.key,
    required this.centerTitle,
    required this.centerSubtitle,
    required this.centerIcon,
    required this.actions,
    this.badgeLabel = 'TRACE',
    this.footerLabel = 'READY',
    this.primaryColor = TraceColors.cyan,
  }) : assert(actions.length > 0 && actions.length <= 5);

  final String centerTitle;
  final String centerSubtitle;
  final IconData centerIcon;
  final List<TraceOrbitAction> actions;
  final String badgeLabel;
  final String footerLabel;
  final Color primaryColor;

  static List<Offset> _orbitPositions(int count, double size, double nodeSize) {
    final center = Offset(size / 2, size / 2);
    final orbitRadius = size * (count > 4 ? 0.365 : 0.35);
    final angles = count == 4
        ? <double>[-math.pi / 2, 0, math.pi, math.pi / 2]
        : List<double>.generate(
            count,
            (index) => -math.pi / 2 + (math.pi * 2 / count) * index,
          );

    return angles.map((angle) {
      final raw = center + Offset(math.cos(angle), math.sin(angle)) * orbitRadius;
      final left = (raw.dx - nodeSize / 2).clamp(0.0, size - nodeSize);
      final top = (raw.dy - nodeSize / 2).clamp(0.0, size - nodeSize);
      return Offset(left, top);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final nodeSize = actions.length > 4
              ? math.min(size * 0.225, 88.0)
              : math.min(size * 0.275, 104.0);
          final coreSize = math.min(
            size * (actions.length > 4 ? 0.37 : 0.43),
            164.0,
          );
          final positions = _orbitPositions(actions.length, size, nodeSize);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: TraceRadialConsolePainter(
                    primaryColor: primaryColor,
                    actionCount: actions.length,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 12,
                child: _TraceConsoleReadout(
                  label: badgeLabel,
                  value: '${actions.length.toString().padLeft(2, '0')} NODES',
                  color: primaryColor,
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                child: _TraceConsoleReadout(
                  label: footerLabel,
                  value: 'ONLINE',
                  color: primaryColor,
                  alignEnd: true,
                ),
              ),
              for (var i = 0; i < actions.length; i++)
                Positioned(
                  left: positions[i].dx,
                  top: positions[i].dy,
                  child: TraceOrbitButton(
                    size: nodeSize,
                    action: actions[i],
                  ),
                ),
              Center(
                child: _TraceConsoleCore(
                  size: coreSize,
                  title: centerTitle,
                  subtitle: centerSubtitle,
                  icon: centerIcon,
                  color: primaryColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TraceRadialConsolePainter extends CustomPainter {
  const TraceRadialConsolePainter({
    required this.primaryColor,
    required this.actionCount,
  });

  final Color primaryColor;
  final int actionCount;

  static List<double> _spokeAngles(int count) {
    if (count == 4) {
      return <double>[-math.pi / 2, 0, math.pi, math.pi / 2];
    }
    return List<double>.generate(
      count,
      (index) => -math.pi / 2 + (math.pi * 2 / count) * index,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortest * 0.455;

    final platePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.26),
          TraceColors.ocean.withOpacity(0.2),
          const Color(0xFF021018).withOpacity(0.92),
          Colors.transparent,
        ],
        stops: const [0, 0.42, 0.78, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.16));
    canvas.drawCircle(center, radius * 1.16, platePaint);

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..color = Colors.black.withOpacity(0.18);
    canvas.drawCircle(center, radius * 0.88, shadowPaint);

    final outerHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = primaryColor.withOpacity(0.28);
    canvas.drawCircle(center, radius * 1.02, outerHalo);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = primaryColor.withOpacity(0.2);
    for (final factor in [0.3, 0.42, 0.55, 0.68, 0.81, 0.94]) {
      canvas.drawCircle(center, radius * factor, ringPaint);
    }

    final softRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = primaryColor.withOpacity(0.055);
    canvas.drawCircle(center, radius * 0.72, softRingPaint);

    final connectorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = primaryColor.withOpacity(0.25);
    for (final angle in _spokeAngles(actionCount)) {
      final start = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.26;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.76;
      canvas.drawLine(start, end, connectorPaint);
    }

    final tickPaint = Paint()
      ..color = primaryColor.withOpacity(0.58)
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 96; i++) {
      final angle = (math.pi * 2 / 96) * i;
      final isMajor = i % 8 == 0;
      final isMedium = i % 4 == 0;
      final start = radius * (isMajor ? 0.91 : (isMedium ? 0.945 : 0.97));
      final end = radius * 1.045;
      canvas.drawLine(
        center + Offset(math.cos(angle) * start, math.sin(angle) * start),
        center + Offset(math.cos(angle) * end, math.sin(angle) * end),
        tickPaint,
      );
    }

    final heavyArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          primaryColor.withOpacity(0.18),
          TraceColors.cyanSoft,
          primaryColor,
          Colors.transparent,
        ],
        stops: const [0, 0.22, 0.36, 0.48, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      -math.pi * 0.86,
      math.pi * 0.66,
      false,
      heavyArc,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.98),
      math.pi * 0.62,
      math.pi * 0.48,
      false,
      heavyArc,
    );

    final innerSweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          primaryColor.withOpacity(0.08),
          primaryColor.withOpacity(0.62),
          Colors.transparent,
        ],
        stops: const [0, 0.36, 0.5, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.62),
      -math.pi * 0.2,
      math.pi * 0.88,
      false,
      innerSweep,
    );

    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = primaryColor.withOpacity(0.13);
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.98), Offset(center.dx, center.dy + radius * 0.98), crossPaint);
    canvas.drawLine(Offset(center.dx - radius * 0.98, center.dy), Offset(center.dx + radius * 0.98, center.dy), crossPaint);

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = primaryColor.withOpacity(0.32);
    const corner = 28.0;
    final rect = Offset.zero & size;
    canvas.drawLine(rect.topLeft + const Offset(6, corner), rect.topLeft + const Offset(6, 6), cornerPaint);
    canvas.drawLine(rect.topLeft + const Offset(6, 6), rect.topLeft + const Offset(corner, 6), cornerPaint);
    canvas.drawLine(rect.topRight + const Offset(-corner, 6), rect.topRight + const Offset(-6, 6), cornerPaint);
    canvas.drawLine(rect.topRight + const Offset(-6, 6), rect.topRight + const Offset(-6, corner), cornerPaint);
    canvas.drawLine(rect.bottomLeft + const Offset(6, -corner), rect.bottomLeft + const Offset(6, -6), cornerPaint);
    canvas.drawLine(rect.bottomLeft + const Offset(6, -6), rect.bottomLeft + const Offset(corner, -6), cornerPaint);
    canvas.drawLine(rect.bottomRight + const Offset(-corner, -6), rect.bottomRight + const Offset(-6, -6), cornerPaint);
    canvas.drawLine(rect.bottomRight + const Offset(-6, -corner), rect.bottomRight + const Offset(-6, -6), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant TraceRadialConsolePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.actionCount != actionCount;
  }
}
class TraceOrbitButton extends StatelessWidget {
  const TraceOrbitButton({
    super.key,
    required this.size,
    required this.action,
  });

  final double size;
  final TraceOrbitAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${action.title} ${action.subtitle}',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action.onTap,
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  action.color.withOpacity(0.25),
                  const Color(0xFF06202A).withOpacity(0.96),
                  TraceColors.ink.withOpacity(0.98),
                ],
              ),
              border: Border.all(color: action.color.withOpacity(0.62), width: 1.35),
              boxShadow: [
                BoxShadow(
                  color: action.color.withOpacity(0.26),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: action.color, size: size * 0.28),
                  SizedBox(height: size * 0.08),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: TraceColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: size * 0.03),
                  Text(
                    action.code,
                    style: TextStyle(
                      color: action.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TraceConsoleCore extends StatelessWidget {
  const _TraceConsoleCore({
    required this.size,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final double size;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.36),
            TraceColors.ocean.withOpacity(0.26),
            TraceColors.ink.withOpacity(0.98),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.58), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.34),
            blurRadius: 44,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.085),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: size * 0.24),
            SizedBox(height: size * 0.07),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  color: TraceColors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SizedBox(height: size * 0.035),
            SizedBox(
              width: size * 0.72,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  style: TextStyle(
                    color: TraceColors.muted.withOpacity(0.92),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
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

class _TraceConsoleReadout extends StatelessWidget {
  const _TraceConsoleReadout({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.64),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
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
class TraceDialogAction {
  const TraceDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.color = TraceColors.cyan,
  });

  final String label;
  final ValueChanged<BuildContext> onPressed;
  final bool isPrimary;
  final Color color;
}

class TraceDialog extends StatelessWidget {
  const TraceDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.color = TraceColors.cyan,
    this.actions = const [],
  }) : assert(message != null || content != null);

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final Color color;
  final List<TraceDialogAction> actions;

  static void close(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = content ?? Text(message!);

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF061821).withOpacity(0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withOpacity(0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.58),
                blurRadius: 34,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 34,
                spreadRadius: -12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.14),
                      border: Border.all(color: color.withOpacity(0.34)),
                    ),
                    child: Icon(icon ?? Icons.info_outline, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: TraceColors.text,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DefaultTextStyle(
                style: const TextStyle(
                  color: TraceColors.muted,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                child: SingleChildScrollView(child: body),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions
                        .map((action) => _TraceDialogButton(action: action))
                        .toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TraceDialogButton extends StatelessWidget {
  const _TraceDialogButton({required this.action});

  final TraceDialogAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => action.onPressed(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: action.isPrimary ? action.color.withOpacity(0.88) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: action.isPrimary
                  ? action.color.withOpacity(0.7)
                  : action.color.withOpacity(0.24),
            ),
            boxShadow: action.isPrimary
                ? [
                    BoxShadow(
                      color: action.color.withOpacity(0.24),
                      blurRadius: 22,
                      spreadRadius: -8,
                    ),
                  ]
                : const [],
          ),
          child: Text(
            action.label,
            style: TextStyle(
              color: action.isPrimary ? TraceColors.ink : action.color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
