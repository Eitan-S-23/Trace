import 'package:flutter/material.dart';

class TraceDesignHotspot {
  const TraceDesignHotspot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;
}

class ReferenceDesignScreen extends StatelessWidget {
  const ReferenceDesignScreen({
    super.key,
    required this.assetPath,
    this.hotspots = const [],
  });

  final String assetPath;
  final List<TraceDesignHotspot> hotspots;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000911),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
                fit: BoxFit.fill,
                width: width,
                height: height,
                filterQuality: FilterQuality.high,
              ),
              for (final hotspot in hotspots)
                Positioned(
                  left: width * hotspot.left,
                  top: height * hotspot.top,
                  width: width * hotspot.width,
                  height: height * hotspot.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: hotspot.onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
