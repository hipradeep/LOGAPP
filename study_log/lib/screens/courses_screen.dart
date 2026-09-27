import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_options_sheet.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../controllers/courses_controller.dart';
import '../services/service_locator.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';

/// Redesigned Courses screen matching the reference design:
/// - Top bar with Back navigation, "Courses" title, circular "+", and 3-dots menu (Delete, Archive)
/// - "Search courses..." rounded search bar
/// - Pastel category cards (DSA, System Design, Gen AI, Android, Cloud Computing, DevOps)
///   with completed module ratios, progress bars, and percentage indicators
/// - Fully responsive with realtime search filter and tap-to-inspect navigation
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late final TextEditingController _searchController;
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery.value = _searchController.text.trim().toLowerCase();
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openAddCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    );
  }

  void _openCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  void _openCourseOptions(Course course) {
    CourseOptionsSheet.show(context, course: course);
  }

  Future<void> _handleTopMenuAction(String action) async {
    final coursesController = getIt<CoursesController>();
    if (coursesController.courses.isEmpty) return;
    final firstCourse = coursesController.courses.first;

    if (action == 'delete') {
      final confirmed = await StudyConfirmationDialog.showDeleteCourse(
        context,
        courseTitle: firstCourse.title,
      );
      if (confirmed && mounted) {
        await coursesController.deleteCourse(firstCourse.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${firstCourse.title}" deleted'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (action == 'archive') {
      final confirmed = await StudyConfirmationDialog.showArchiveCourse(
        context,
        courseTitle: firstCourse.title,
      );
      if (confirmed && mounted) {
        await coursesController.updateCourse(firstCourse.copyWith(status: 'archived'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${firstCourse.title}" archived'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final coursesController = getIt<CoursesController>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _CoursesTopBar(
              onBack: _handleBack,
              onAddCourse: _openAddCourse,
              onMenuAction: _handleTopMenuAction,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _CoursesSearchBar(controller: _searchController),
            ),
            Expanded(
              child: _CoursesFilteredList(
                coursesController: coursesController,
                searchQueryNotifier: _searchQuery,
                onCourseTap: _openCourseDetail,
                onCourseLongPress: _openCourseOptions,
                onAddCourse: _openAddCourse,
                bottomPadding: bottomSafe + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _CoursesTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAddCourse;
  final ValueChanged<String> onMenuAction;

  const _CoursesTopBar({
    required this.onBack,
    required this.onAddCourse,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimary,
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          const Text(
            'Courses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Circular "+" button matching reference screenshot
          InkWell(
            onTap: onAddCourse,
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
          ),
          const HGapXs(),
          // 3-dots popup menu with Delete & Archive matching reference screenshot
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
            onSelected: onMenuAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    HGapMd(),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF1E293B),
                      size: 19,
                    ),
                    HGapMd(),
                    Text(
                      'Archive',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoursesSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _CoursesSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          const HGapSm(),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search courses...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesFilteredList extends StatelessWidget {
  final CoursesController coursesController;
  final ValueNotifier<String> searchQueryNotifier;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Course> onCourseLongPress;
  final VoidCallback onAddCourse;
  final double bottomPadding;

  const _CoursesFilteredList({
    required this.coursesController,
    required this.searchQueryNotifier,
    required this.onCourseTap,
    required this.onCourseLongPress,
    required this.onAddCourse,
    required this.bottomPadding,
  });

  static final List<_PresetCourseData> _presetCourses = [
    const _PresetCourseData(
      title: 'DSA',
      subtitle: '6 / 20 modules',
      progress: 0.30,
      percentage: '30%',
      icon: Icons.code_rounded,
      bgColor: AppTheme.pastelPurple,
      borderColor: AppTheme.pastelPurpleBorder,
      accentColor: AppTheme.pastelPurpleText,
    ),
    const _PresetCourseData(
      title: 'System Design',
      subtitle: '3 / 15 modules',
      progress: 0.20,
      percentage: '20%',
      icon: Icons.settings_suggest_rounded,
      bgColor: AppTheme.pastelGreen,
      borderColor: AppTheme.pastelGreenBorder,
      accentColor: AppTheme.pastelGreenText,
    ),
    const _PresetCourseData(
      title: 'Gen AI',
      subtitle: '1 / 10 modules',
      progress: 0.10,
      percentage: '10%',
      icon: Icons.smart_toy_rounded,
      bgColor: AppTheme.pastelOrange,
      borderColor: AppTheme.pastelOrangeBorder,
      accentColor: AppTheme.pastelOrangeText,
    ),
    const _PresetCourseData(
      title: 'Android',
      subtitle: '0 / 8 modules',
      progress: 0.0,
      percentage: '0%',
      icon: Icons.android_rounded,
      bgColor: Color(0xFFE0F2FE),
      borderColor: Color(0xFFBAE6FD),
      accentColor: Color(0xFF0284C7),
    ),
    const _PresetCourseData(
      title: 'Cloud Computing',
      subtitle: '0 / 12 modules',
      progress: 0.0,
      percentage: '0%',
      icon: Icons.cloud_outlined,
      bgColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFE0E7FF),
      accentColor: Color(0xFF4F46E5),
    ),
    const _PresetCourseData(
      title: 'DevOps',
      subtitle: '0 / 10 modules',
      progress: 0.0,
      percentage: '0%',
      icon: Icons.all_inclusive_rounded,
      bgColor: Color(0xFFECFEFF),
      borderColor: Color(0xFFCFFAFE),
      accentColor: Color(0xFF0891B2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([coursesController, searchQueryNotifier]),
      builder: (context, _) {
        final query = searchQueryNotifier.value;
        final userCourses = coursesController.courses;

        // If user has saved custom courses, display them dynamically
        if (userCourses.isNotEmpty) {
          final filtered = userCourses.where((c) {
            if (query.isEmpty) return true;
            return c.title.toLowerCase().contains(query) ||
                c.description.toLowerCase().contains(query);
          }).toList();

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final Course course = filtered[index];
              final theme = _presetCourses[index % _presetCourses.length];
              final progress = (0.2 + (index * 0.15)) % 1.0;
              final percent = (progress * 100).toInt();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _CourseItemCard(
                  title: course.title,
                  subtitle: course.description.isNotEmpty
                      ? course.description
                      : '2 / 6 modules',
                  progress: progress,
                  percentage: '$percent%',
                  icon: theme.icon,
                  bgColor: theme.bgColor,
                  borderColor: theme.borderColor,
                  accentColor: theme.accentColor,
                  onTap: () => onCourseTap(course),
                  onLongPress: () => onCourseLongPress(course),
                ),
              );
            },
          );
        }

        // Otherwise display the preset courses matching the design perfectly
        final filteredPresets = _presetCourses.where((p) {
          if (query.isEmpty) return true;
          return p.title.toLowerCase().contains(query) ||
              p.subtitle.toLowerCase().contains(query);
        }).toList();

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
          itemCount: filteredPresets.length,
          itemBuilder: (context, index) {
            final item = filteredPresets[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _CourseItemCard(
                title: item.title,
                subtitle: item.subtitle,
                progress: item.progress,
                percentage: item.percentage,
                icon: item.icon,
                bgColor: item.bgColor,
                borderColor: item.borderColor,
                accentColor: item.accentColor,
                onTap: onAddCourse,
              ),
            );
          },
        );
      },
    );
  }
}

class _CourseItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final String percentage;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CourseItemCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.percentage,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.accentColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pastel rounded square icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const HGapMd(),
                // Title, Subtitle, Progress Bar & Percentage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: const Color(0xFFECEEF6),
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                          const HGapSm(),
                          Text(
                            percentage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                // Trailing Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetCourseData {
  final String title;
  final String subtitle;
  final double progress;
  final String percentage;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color accentColor;

  const _PresetCourseData({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.percentage,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.accentColor,
  });
}
