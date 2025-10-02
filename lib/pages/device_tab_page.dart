import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'power_meter_page.dart';
import 'speedometer_page.dart';
import 'remote_control_page.dart';
import '../widgets/responsive_widgets.dart';

class DeviceTabPage extends StatelessWidget {
  const DeviceTabPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '设备中心',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E3A59),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF2E3A59)),
            onPressed: () {
              // 设置页面
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.devices,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '智能设备管理中心',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '连接、监控、控制您的蓝牙设备',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '选择下方功能模块开始使用',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0),

            const SizedBox(height: 24),

            // 功能模块标题
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '功能模块',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3A59),
                  ),
                ),
              ],
            )
                .animate(delay: 400.ms)
                .fadeIn(duration: 600.ms)
                .slideX(begin: -0.3, end: 0),

            const SizedBox(height: 20),

            // 功能模块网格
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildFeatureCard(
                    title: '功率计',
                    subtitle: 'BLE设备功率监控',
                    icon: Icons.electric_meter,
                    colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    onTap: () {
                      Get.to(() => const PowerMeterPage());
                    },
                  ).animate(delay: 600.ms).fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                  _buildFeatureCard(
                    title: '码表',
                    subtitle: '骑行数据与导航',
                    icon: Icons.speed,
                    colors: [const Color(0xFF11998e), const Color(0xFF38ef7d)],
                    onTap: () {
                      Get.to(() => const SpeedometerPage());
                    },
                  ).animate(delay: 800.ms).fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                  _buildFeatureCard(
                    title: '遥控',
                    subtitle: '蓝牙设备控制',
                    icon: Icons.settings_remote,
                    colors: [const Color(0xFFee0979), const Color(0xFFff6a00)],
                    onTap: () {
                      Get.to(() => const RemoteControlPage());
                    },
                  ).animate(delay: 1000.ms).fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                  _buildFeatureCard(
                    title: '即将推出',
                    subtitle: '更多功能敬请期待',
                    icon: Icons.upcoming,
                    colors: [Colors.grey.shade400, Colors.grey.shade600],
                    onTap: () {
                      Get.snackbar('提示', '功能开发中，敬请期待',
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          colorText: Colors.orange.shade700,
                          snackPosition: SnackPosition.TOP,
                          icon: const Icon(Icons.construction,
                              color: Colors.orange));
                    },
                  ).animate(delay: 1200.ms).fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ResponsiveContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // 防止溢出
            children: [
              ResponsiveContainer(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ResponsiveIcon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              ResponsiveSpacing(spacing: 16),
              Flexible(
                // 防止文本溢出
                child: ResponsiveText(
                  title,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ResponsiveSpacing(spacing: 6),
              Flexible(
                // 防止副标题溢出
                child: ResponsiveText(
                  subtitle,
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
