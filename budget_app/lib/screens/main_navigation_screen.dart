import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/budget_controller.dart';
import '../controllers/theme_controller.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import 'home_screen.dart';
import 'budget_screen.dart';
import 'spending_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final ThemeController? themeController;

  const MainNavigationScreen({
    super.key,
    this.themeController,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final BudgetController _budgetController;

  @override
  void initState() {
    super.initState();
    _budgetController = BudgetController();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        controller: _budgetController,
        onNavigateToLog: () => _onTabSelected(2),
        onNavigateToBudget: () => _onTabSelected(1),
      ),
      BudgetScreen(controller: _budgetController),
      SpendingScreen(controller: _budgetController),
      const ProfileScreen(),
    ];

    return AppProvider<BudgetController>(
      notifier: _budgetController,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final navItems = const [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Budget',
      ),
      _NavItem(
        icon: Icons.pie_chart_outline_rounded,
        activeIcon: Icons.pie_chart_rounded,
        label: 'Spending',
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 68 + bottomPadding,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomPadding,
            top: 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppTheme.borderColor(context),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(navItems.length, (index) {
              final isActive = _currentIndex == index;
              final item = navItems[index];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                        size: 24,
                      ),
                      const VGapXs(),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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
