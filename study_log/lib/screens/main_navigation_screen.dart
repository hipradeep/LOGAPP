import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import '../controllers/revision_controller.dart';
import '../models/revision.dart';
import 'home_screen.dart';
import 'revision_screen.dart';
import 'revision_detail_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

/// Root navigation screen housing the 4 core tabs:
/// - Home
/// - Revision (R1 -> R5 spaced repetition ladder)
/// - Calendar (empty)
/// - Profile
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      RevisionScreen(
        revisionController: getIt<RevisionController>(),
        onBack: () => _onTabSelected(0),
        onOpenRevision: _openRevisionDetail,
      ),
      const CalendarScreen(),
      const ProfileScreen(),
    ];
  }

  void _openRevisionDetail(Revision revision) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionDetailScreen(revision: revision),
      ),
    );
  }

  @override
  void dispose() {
    _currentIndex.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex.value == index) return;
    _currentIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, activeIndex, _) {
        return Scaffold(
          backgroundColor: AppTheme.background(context),
          body: IndexedStack(
            index: activeIndex,
            children: _pages,
          ),
          bottomNavigationBar: _StudyBottomNav(
            currentIndex: activeIndex,
            onTap: _onTabSelected,
          ),
        );
      },
    );
  }
}

class _StudyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _StudyBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: bottomSafe > 0 ? bottomSafe : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            index: 0,
            currentIndex: currentIndex,
            label: 'Home',
            selectedIcon: Icons.home_rounded,
            unselectedIcon: Icons.home_outlined,
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            currentIndex: currentIndex,
            label: 'Revision',
            selectedIcon: Icons.sync_rounded,
            unselectedIcon: Icons.sync_outlined,
            onTap: onTap,
          ),
          _NavItem(
            index: 2,
            currentIndex: currentIndex,
            label: 'Calendar',
            selectedIcon: Icons.calendar_today_rounded,
            unselectedIcon: Icons.calendar_today_outlined,
            onTap: onTap,
          ),
          _NavItem(
            index: 3,
            currentIndex: currentIndex,
            label: 'Profile',
            selectedIcon: Icons.person_rounded,
            unselectedIcon: Icons.person_outline_rounded,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.onTap,
  });

  void _handleTap() => onTap(index);

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final color = isSelected ? AppTheme.bnbActiveColor : AppTheme.bnbInactiveColor;

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
