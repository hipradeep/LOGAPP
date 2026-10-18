import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import '../controllers/revision_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/progress_controller.dart';
import '../models/revision.dart';
import 'home_screen.dart';
import 'todo_screen.dart';
import 'revision_screen.dart';
import 'revision_detail_screen.dart';
import 'profile_screen.dart';
import '../controllers/todo_controller.dart';

import 'dart:async';
import 'course_detail_screen.dart';
import '../models/notification_payload.dart';
import '../services/notification_service.dart';

/// Root navigation screen housing the 4 core tabs:
/// - Home
/// - TODO (Daily todos, checklists, deadlines)
/// - Revision (R1 -> R5 spaced repetition ladder)
/// - Profile
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);
  DateTime? _lastBackPressTime;
  StreamSubscription<NotificationPayload>? _payloadSubscription;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      const TodoScreen(),
      RevisionScreen(
        revisionController: getIt<RevisionController>(),
        onOpenRevision: _openRevisionDetail,
      ),
      const ProfileScreen(),
    ];

    if (getIt.isRegistered<NotificationService>()) {
      _payloadSubscription =
          getIt<NotificationService>().onPayloadTapped.listen(_handleNotificationPayload);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLaunchPayload();
    });
  }

  Future<void> _checkInitialLaunchPayload() async {
    if (!getIt.isRegistered<NotificationService>()) return;
    final payload = await getIt<NotificationService>().getLaunchPayload();
    if (payload != null && mounted) {
      _handleNotificationPayload(payload);
    }
  }

  void _handleNotificationPayload(NotificationPayload payload) {
    if (!mounted) return;
    switch (payload.action) {
      case 'open_tab':
        final tab = payload.tabIndex ?? 1;
        _onTabSelected(tab);
        break;
      case 'open_home':
        _onTabSelected(0);
        break;
      case 'open_todo':
        _onTabSelected(1);
        break;
      case 'open_revision':
        _onTabSelected(2);
        break;
      case 'open_course':
        if (payload.courseId != null && getIt.isRegistered<CoursesController>()) {
          final course =
              getIt<CoursesController>().getCourseById(payload.courseId!);
          if (course != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CourseDetailScreen(course: course),
              ),
            );
          } else {
            _onTabSelected(0);
          }
        } else {
          _onTabSelected(0);
        }
        break;
      case 'open_timer':
        // Jump directly to Revision tab
        _onTabSelected(2);
        break;
      default:
        _onTabSelected(0);
    }
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
    _payloadSubscription?.cancel();
    _currentIndex.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex.value == index) {
      if (index == 1) {
        if (getIt.isRegistered<TodoController>()) {
          getIt<TodoController>().refresh();
        }
      } else if (index == 2) {
        if (getIt.isRegistered<RevisionController>()) {
          getIt<RevisionController>().reconcile();
        }
        if (getIt.isRegistered<TopicRevisionController>()) {
          getIt<TopicRevisionController>().refresh();
        }
      } else if (index == 3 && getIt.isRegistered<ProgressController>()) {
        getIt<ProgressController>().refresh();
      }
      return;
    }
    _currentIndex.value = index;
    if (index == 1) {
      if (getIt.isRegistered<TodoController>()) {
        getIt<TodoController>().refresh();
      }
    } else if (index == 2) {
      if (getIt.isRegistered<RevisionController>()) {
        getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<TopicRevisionController>()) {
        getIt<TopicRevisionController>().refresh();
      }
    } else if (index == 3) {
      if (getIt.isRegistered<CoursesController>()) {
        getIt<CoursesController>().refresh();
      }
      if (getIt.isRegistered<RevisionController>()) {
        getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<ProgressController>()) {
        getIt<ProgressController>().refresh();
      }
    }
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop) return;

    if (_currentIndex.value != 0) {
      _onTabSelected(0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Press back again to exit'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppTheme.defaultBorderRadius,
              ),
            ),
          ),
        );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: ValueListenableBuilder<int>(
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
      ),
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
            color: AppTheme.shadowColor(context),
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
            label: '#TODO',
            selectedIcon: Icons.task_alt_rounded,
            unselectedIcon: Icons.task_alt_outlined,
            onTap: onTap,
          ),
          _NavItem(
            index: 2,
            currentIndex: currentIndex,
            label: 'Revision',
            selectedIcon: Icons.sync_rounded,
            unselectedIcon: Icons.sync_outlined,
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
