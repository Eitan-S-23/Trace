import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'power_meter_page.dart';
import 'reference_design_screen.dart';
import 'remote_control_page.dart';
import 'speedometer_page.dart';
import 'trace_ui.dart';

class DeviceTabPage extends StatelessWidget {
  const DeviceTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ReferenceDesignScreen(
      assetPath: 'assets/design_refs/device_28.png',
      hotspots: [
        TraceDesignHotspot(
          left: 0.34,
          top: 0.18,
          width: 0.32,
          height: 0.20,
          onTap: () => Get.to(() => const PowerMeterPage()),
        ),
        TraceDesignHotspot(
          left: 0.61,
          top: 0.30,
          width: 0.32,
          height: 0.24,
          onTap: () => Get.to(
            () => const SpeedometerPage(),
            transition: Transition.cupertino,
            duration: const Duration(milliseconds: 300),
          ),
        ),
        TraceDesignHotspot(
          left: 0.07,
          top: 0.30,
          width: 0.32,
          height: 0.24,
          onTap: () => Get.to(() => const RemoteControlPage()),
        ),
        TraceDesignHotspot(
          left: 0.34,
          top: 0.53,
          width: 0.32,
          height: 0.20,
          onTap: () => Get.snackbar(
            '提示',
            '功能开发中，敬请期待',
            snackPosition: SnackPosition.TOP,
            backgroundColor: TraceColors.deep,
            colorText: TraceColors.text,
            icon: const Icon(Icons.construction, color: TraceColors.amber),
          ),
        ),
      ],
    );
  }
}
