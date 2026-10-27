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
import 'bookmarks_screen.dart';
import '../models/notification_payload.dart';
import '../services/notification_service.dart';

/// Root navigation screen housing the 4 core tabs:
/// - Home
/// - Revision (R1 -> R5 spaced repetition ladder)
/// - TODO (Daily todos, checklists, deadlines)
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
      RevisionScreen(
        revisionController: getIt<RevisionController>(),
        onOpenRevision: _openRevisionDetail,
      ),
      const TodoScreen(),
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
      case 'open_revision':
        _onTabSelected(1);
        break;
      case 'open_todo':
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
        _onTabSelected(1);
        break;
      case 'open_bookmarks':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookmarksScreen(highlightBookmarkId: payload.targetId),
          ),
        );
      case 'open_session':
        // SessionTimerScreen is already top-of-stack; resuming brings it into view
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
        if (getIt.isRegistered<RevisionController>()) {
          getIt<RevisionController>().reconcile();
        }
        if (getIt.isRegistered<TopicRevisionController>()) {
          getIt<TopicRevisionController>().refresh();
        }
      } else if (index == 2) {
        if (getIt.isRegistered<TodoController>()) {
          getIt<TodoController>().refresh();
        }
      } else if (index == 3 && getIt.isRegistered<ProgressController>()) {
        getIt<ProgressController>().refresh();
      }
      return;
    }
    _currentIndex.value = index;
    if (index == 1) {
      if (getIt.isRegistered<RevisionController>()) {
        getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<TopicRevisionController>()) {
        getIt<TopicRevisionController>().refresh();
      }
    } else if (index == 2) {
      if (getIt.isRegistered<TodoController>()) {
        getIt<TodoController>().refresh();
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor(context),
            width: 0.8,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync_rounded),
            label: 'Revision',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: '#TODO',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
