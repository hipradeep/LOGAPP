import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/study_schedule_card.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/app_empty_state.dart';
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
                  const _DynamicGreetingHeader(),
                  const VGapLg(),
                  _FilterChipsRow(
                    activeFilter: _activeFilter,
                    onFilterChanged: _onFilterChanged,
                  ),
                  const VGapLg(),
                  const _DynamicDateHeroSection(),
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

// === Dynamic Greeting Header ===

class _DynamicGreetingHeader extends StatelessWidget {
  const _DynamicGreetingHeader();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

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
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const VGapXs(),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
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
        message: 'Profile',
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

// === Dynamic Date & Time Hero Section ===

class _DynamicDateHeroSection extends StatelessWidget {
  const _DynamicDateHeroSection();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfWeek = DateFormat('EEEE').format(now);
    final dayNumber = DateFormat('d').format(now);
    final month = DateFormat('MMMM').format(now).toUpperCase();
    final time = DateFormat('HH.mm').format(now);

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
            // Right: Dynamic Time + Mode Tag
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
                  const Text(
                    'Study Mode',
                    style: TextStyle(
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

// === Schedule Cards List (Backed by Firebase Firestore) ===

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
          if (coursesController.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          }

          if (coursesController.errorMessage != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Error loading courses: ${coursesController.errorMessage}',
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final courses = coursesController.courses;
          if (courses.isEmpty) {
            return const AppEmptyState(
              icon: Icons.school_outlined,
              title: 'No Courses Yet',
              description: 'Tap your profile icon above to create your first course.',
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(courses.length, (index) {
              final Course course = courses[index];
              final bool isFeatured = index == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: StudyScheduleCard(
                  key: ValueKey(course.id),
                  title: course.title,
                  time: _formatDeadline(course.deadline),
                  subtitle: course.description.isEmpty ? 'No description' : course.description,
                  isFeatured: isFeatured,
                  leadingIcon: Icons.auto_stories_outlined,
                ),
              );
            }),
          );
        },
      );
    }

    if (activeFilter == StudyFilter.revision) {
      return const AppEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No Revision Scheduled',
        description: 'Revision sessions for your course sections will appear here.',
      );
    }

    return const AppEmptyState(
      icon: Icons.trending_up_rounded,
      title: 'No Progress Logs Yet',
      description: 'Track your completed subsections and milestones here.',
    );
  }

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return 'No Deadline';
    return DateFormat('d MMM').format(deadline);
  }
}
