import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'power_meter_page.dart';
import 'speedometer_page.dart';
import 'remote_control_page.dart';
import '../widgets/responsive_widgets.dart';

class DeviceTabPage extends StatelessWidget {
  const DeviceTabPage({super.key});

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
      body: SingleChildScrollView(
        // 1. 新增：给整个页面内容加滚动容器
        physics: const BouncingScrollPhysics(), // 移动端友好的弹性滚动效果
        child: ResponsiveBuilder(
          builder: (context, isDesktop, isTablet, isMobile) {
            // 根据设备类型调整页面内边距
            EdgeInsets padding = isDesktop
                ? const EdgeInsets.all(24.0) // 桌面端更大间距
                : isTablet
                    ? const EdgeInsets.all(20.0) // 平板端中等间距
                    : const EdgeInsets.all(16.0); // 手机端标准间距

            return Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 欢迎卡片（内容不变）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea)
                              .withAlpha(40), // 修正：withValues→withAlpha
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
                                color: Colors.white
                                    .withAlpha(20), // 修正：withValues→withAlpha
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.devices,
                                  color: Colors.white, size: 24),
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
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '连接、监控、控制您的蓝牙设备',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withAlpha(
                                            90)), // 修正：withValues→withAlpha
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
                            color: Colors.white
                                .withAlpha(15), // 修正：withValues→withAlpha
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white
                                    .withAlpha(90), // 修正：withValues→withAlpha
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '选择下方功能模块开始使用',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(
                                        90)), // 修正：withValues→withAlpha
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 24),

                  // 功能模块标题（内容不变）
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '功能模块',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E3A59)),
                      ),
                    ],
                  )
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: -0.3, end: 0),

                  const SizedBox(height: 20),

                  // 功能模块网格 - 优化手机端参数
                  ResponsiveBuilder(
                    builder: (context, isDesktop, isTablet, isMobile) {
                      int crossAxisCount;
                      double childAspectRatio;
                      double spacing;

                      if (isDesktop) {
                        crossAxisCount = 4;
                        childAspectRatio = 0.85;
                        spacing = 20;
                      } else if (isTablet) {
                        crossAxisCount = 3;
                        childAspectRatio = 0.9;
                        spacing = 18;
                      } else {
                        crossAxisCount = 2;
                        childAspectRatio = 0.9;
                        spacing = 20;
                      }

                      return GridView.count(
                        shrinkWrap: true, // 保持：让网格高度适应内容
                        physics:
                            const NeverScrollableScrollPhysics(), // 禁止网格自身滚动，避免与外层冲突
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: childAspectRatio,
                        children: [
                          // 卡片内容不变...
                          _buildFeatureCard(
                            title: '功率计',
                            subtitle: '设备功率监控',
                            icon: Icons.electric_meter,
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            onTap: () => Get.to(() => const PowerMeterPage()),
                          )
                              .animate(delay: 600.ms)
                              .fadeIn(duration: 600.ms)
                              .scale(
                                  begin: Offset(0.8, 0.8), end: Offset(1, 1)),
                          _buildFeatureCard(
                            title: '码表',
                            subtitle: '骑行数据与导航',
                            icon: Icons.speed,
                            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                            onTap: () => Get.to(
                              () => const SpeedometerPage(),
                              transition: Transition.cupertino,
                              duration: const Duration(milliseconds: 300),
                            ),
                          )
                              .animate(delay: 800.ms)
                              .fadeIn(duration: 600.ms)
                              .scale(
                                  begin: Offset(0.8, 0.8), end: Offset(1, 1)),
                          _buildFeatureCard(
                            title: '遥控',
                            subtitle: '蓝牙设备控制',
                            icon: Icons.settings_remote,
                            colors: [Color(0xFFee0979), Color(0xFFff6a00)],
                            onTap: () =>
                                Get.to(() => const RemoteControlPage()),
                          )
                              .animate(delay: 1000.ms)
                              .fadeIn(duration: 600.ms)
                              .scale(
                                  begin: Offset(0.8, 0.8), end: Offset(1, 1)),
                          _buildFeatureCard(
                            title: '即将推出',
                            subtitle: '敬请期待',
                            icon: Icons.upcoming,
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade600
                            ],
                            onTap: () => Get.snackbar('提示', '功能开发中，敬请期待',
                                backgroundColor: Colors.orange
                                    .withAlpha(10), // 修正：withValues→withAlpha
                                colorText: Colors.orange.shade700,
                                snackPosition: SnackPosition.TOP,
                                icon: const Icon(Icons.construction,
                                    color: Colors.orange)),
                          )
                              .animate(delay: 1200.ms)
                              .fadeIn(duration: 600.ms)
                              .scale(
                                  begin: Offset(0.8, 0.8), end: Offset(1, 1)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
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
    return ResponsiveBuilder(
      builder: (context, isDesktop, isTablet, isMobile) {
        // 根据设备类型调整卡片布局
        double cardPadding;
        double iconSize;
        double titleFontSize;
        double subtitleFontSize;
        double spacing;

        if (isDesktop) {
          // 桌面端：更紧凑的布局
          cardPadding = 16;
          iconSize = 28;
          titleFontSize = 14;
          subtitleFontSize = 11;
          spacing = 12;
        } else if (isTablet) {
          // 平板端：中等大小
          cardPadding = 18;
          iconSize = 30;
          titleFontSize = 15;
          subtitleFontSize = 12;
          spacing = 14;
        } else {
          // 手机端：更大字体和图标，确保可读性
          cardPadding = 20;
          iconSize = 32;
          titleFontSize = 16;
          subtitleFontSize = 12;
          spacing = 16;
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.3),
                  blurRadius: isDesktop ? 10 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(isDesktop ? 12 : 16),
                    ),
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: spacing),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isMobile ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 6),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isMobile ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
