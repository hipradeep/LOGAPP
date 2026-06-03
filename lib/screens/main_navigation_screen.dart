import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const LogsScreen(),
    const SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_filled,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'Logs',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding + 10,
          top: 8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_navItems.length, (index) {
                  final isActive = _currentIndex == index;
                  final item = _navItems[index];
                  return _buildNavItem(
                    item: item,
                    isActive: isActive,
                    onTap: () => setState(() => _currentIndex = index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container — solid purple square for active, transparent for inactive
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 40,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              item.label,
              style: TextStyle(
                color: isActive
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
