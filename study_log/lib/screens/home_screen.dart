import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/study_schedule_card.dart';
import '../widgets/profile_sheet.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';

enum StudyFilter {
  course,
  revision,
  progress,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StudyFilter _activeFilter = StudyFilter.course;

  void _onFilterChanged(StudyFilter filter) {
    if (_activeFilter == filter) return;
    setState(() => _activeFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: bottomSafe + 32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _GreetingHeader(
                    userName: 'Aditya',
                    subtitle: 'Have a great day!',
                  ),
                  const VGapLg(),
                  _FilterChipsRow(
                    activeFilter: _activeFilter,
                    onFilterChanged: _onFilterChanged,
                  ),
                  const VGapLg(),
                  const _DateHeroSection(
                    dayOfWeek: 'Thursday',
                    dayNumber: '25',
                    month: 'JANUARY',
                    time: '08.00',
                    locationOrMode: 'Study Mode',
                  ),
                  const VGapMd(),
                  _ScheduleCardsList(activeFilter: _activeFilter),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Greeting Header with Profile Trigger ===

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final String subtitle;

  const _GreetingHeader({
    required this.userName,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Good Morning, ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(' ☀️', style: TextStyle(fontSize: 15)),
                ],
              ),
              const VGapXs(),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const _UserAvatar(),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ProfileSheet.show(context),
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: 'Profile (Create Course)',
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// === Filter Chips Row (Course | Revision | Progress) ===

class _FilterChipsRow extends StatelessWidget {
  final StudyFilter activeFilter;
  final ValueChanged<StudyFilter> onFilterChanged;

  const _FilterChipsRow({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Course',
          isSelected: activeFilter == StudyFilter.course,
          onTap: () => onFilterChanged(StudyFilter.course),
        ),
        const HGapSm(),
        _FilterChip(
          label: 'Revision',
          isSelected: activeFilter == StudyFilter.revision,
          onTap: () => onFilterChanged(StudyFilter.revision),
        ),
        const HGapSm(),
        _FilterChip(
          label: 'Progress',
          isSelected: activeFilter == StudyFilter.progress,
          onTap: () => onFilterChanged(StudyFilter.progress),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// === Date & Time Hero Section ===

class _DateHeroSection extends StatelessWidget {
  final String dayOfWeek;
  final String dayNumber;
  final String month;
  final String time;
  final String locationOrMode;

  const _DateHeroSection({
    required this.dayOfWeek,
    required this.dayNumber,
    required this.month,
    required this.time,
    required this.locationOrMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Day of week, Big Day Number, Month
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  dayNumber,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    height: 1.05,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            // Right: Time + Mode/Location
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    locationOrMode,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const VGapMd(),
        Divider(
          color: AppTheme.borderColor.withValues(alpha: 0.8),
          thickness: 1,
          height: 1,
        ),
      ],
    );
  }
}

// === Schedule Cards List (Dynamic using theme colors) ===

class _ScheduleCardsList extends StatelessWidget {
  final StudyFilter activeFilter;

  const _ScheduleCardsList({required this.activeFilter});

  @override
  Widget build(BuildContext context) {
    if (activeFilter == StudyFilter.course) {
      final coursesController = getIt<CoursesController>();
      return ListenableBuilder(
        listenable: coursesController,
        builder: (context, _) {
          final courses = coursesController.courses;
          if (courses.isEmpty) {
            return const _EmptyCoursePrompt();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(courses.length, (index) {
              final course = courses[index];
              final bool isFeatured = index == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: StudyScheduleCard(
                  key: ValueKey(course.id),
                  title: course.title,
                  time: _formatDeadline(course.deadline),
                  subtitle: course.description,
                  isFeatured: isFeatured,
                  leadingIcon: Icons.auto_stories_outlined,
                  avatarInitials: const ['CS', 'AD'],
                ),
              );
            }),
          );
        },
      );
    }

    final items = _getNonCourseItems(activeFilter);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: StudyScheduleCard(
            key: ValueKey(item.title + item.time),
            title: item.title,
            time: item.time,
            subtitle: item.subtitle,
            isFeatured: item.isFeatured,
            leadingIcon: item.icon,
            avatarInitials: item.avatars,
          ),
        );
      }),
    );
  }

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return 'No Deadline';
    return '${deadline.day}/${deadline.month}';
  }

  List<_ItemData> _getNonCourseItems(StudyFilter filter) {
    if (filter == StudyFilter.revision) {
      return const [
        _ItemData(
          title: 'Data Structures Revision: Trees & Graphs',
          time: '09.30',
          subtitle: 'Room 204 • Lab Hall',
          isFeatured: true,
          icon: Icons.menu_book_outlined,
          avatars: ['DS', 'AL'],
        ),
        _ItemData(
          title: 'Operating Systems Quiz Prep',
          time: '14.00',
          subtitle: 'Self Study Desk #3',
          isFeatured: false,
          icon: Icons.timer_outlined,
          avatars: ['OS'],
        ),
        _ItemData(
          title: 'Discrete Mathematics Flashcards',
          time: '17.30',
          subtitle: 'Study Pod A',
          isFeatured: false,
          icon: Icons.lightbulb_outline_rounded,
          avatars: ['DM', 'MA'],
        ),
      ];
    } else {
      return const [
        _ItemData(
          title: 'Weekly Study Target Review',
          time: '11.00',
          subtitle: '85% Target Reached',
          isFeatured: true,
          icon: Icons.trending_up_rounded,
          avatars: ['ST', 'GO'],
        ),
        _ItemData(
          title: 'Sprint Retrospective & Pomodoro Log',
          time: '16.15',
          subtitle: '6 Hours Logged Today',
          isFeatured: false,
          icon: Icons.check_circle_outline_rounded,
          avatars: ['PM'],
        ),
        _ItemData(
          title: 'Milestone 3 Submission Checklist',
          time: '20.00',
          subtitle: 'Final Review',
          isFeatured: false,
          icon: Icons.flag_outlined,
          avatars: ['PR'],
        ),
      ];
    }
  }
}

class _EmptyCoursePrompt extends StatelessWidget {
  const _EmptyCoursePrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.school_outlined, size: 40, color: AppTheme.textSecondary),
            const VGapSm(),
            const Text(
              'No courses added yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const VGapXs(),
            const Text(
              'Tap your profile avatar above to create a course.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemData {
  final String title;
  final String time;
  final String subtitle;
  final bool isFeatured;
  final IconData icon;
  final List<String> avatars;

  const _ItemData({
    required this.title,
    required this.time,
    required this.subtitle,
    required this.isFeatured,
    required this.icon,
    required this.avatars,
  });
}
