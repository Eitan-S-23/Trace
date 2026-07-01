import 'package:flutter/material.dart';
import 'device_tab_page.dart';
import 'discover_tab_page.dart';
import 'profile_tab_page.dart';
import 'trace_ui.dart';

class MainAppPage extends StatefulWidget {
  const MainAppPage({Key? key}) : super(key: key);

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DeviceTabPage(),
    DiscoverTabPage(),
    ProfileTabPage(),
  ];

  final List<_TraceNavItem> _navItems = const [
    _TraceNavItem(
      icon: Icons.devices_outlined,
      activeIcon: Icons.devices,
      label: '设备',
    ),
    _TraceNavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: '发现',
    ),
    _TraceNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.ink,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: _TraceBottomNavigation(
                currentIndex: _selectedIndex,
                items: _navItems,
                onChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceNavItem {
  const _TraceNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _TraceBottomNavigation extends StatelessWidget {
  const _TraceBottomNavigation({
    required this.currentIndex,
    required this.items,
    required this.onChanged,
  });

  final int currentIndex;
  final List<_TraceNavItem> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF031018).withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TraceColors.cyan.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.42),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: TraceColors.cyan.withOpacity(0.16),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = currentIndex == index;
          final color = selected ? TraceColors.cyan : TraceColors.muted;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? TraceColors.cyan.withOpacity(0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? TraceColors.cyan.withOpacity(0.38)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: color,
                          size: selected ? 22 : 21,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? TraceColors.text : TraceColors.muted,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
