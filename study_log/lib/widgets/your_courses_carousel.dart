import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';

/// "Your Courses" horizontal carousel — dynamic from CoursesController.
/// - Listens to CoursesController via ListenableBuilder (surgical rebuild, Rule 3)
/// - Shows up to 4 courses ordered by highest module completion, completed last
/// - Cycling pastel color palette per card index
/// - Shows loading shimmer, empty state, and a "More" card when > 4 courses
class YourCoursesCarousel extends StatefulWidget {
  final VoidCallback? onMoreTap;
  final ValueChanged<String>? onCourseTap;

  const YourCoursesCarousel({
    super.key,
    this.onMoreTap,
    this.onCourseTap,
  });

  @override
  State<YourCoursesCarousel> createState() => _YourCoursesCarouselState();
}

class _YourCoursesCarouselState extends State<YourCoursesCarousel> {
  late final ScrollController _scrollController;
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final ratio = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final int index;
    if (ratio < 0.33) {
      index = 0;
    } else if (ratio < 0.67) {
      index = 1;
    } else {
      index = 2;
    }
    if (_activeIndex.value != index) {
      _activeIndex.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = getIt<CoursesController>();
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderRow(onMoreTap: widget.onMoreTap),
        const VGapMd(),
        ListenableBuilder(
          listenable: ongoing ?? controller,
          builder: (context, _) {
            if (controller.isLoading && controller.courses.isEmpty) {
              return const SizedBox(
                height: 128,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }

            final courses = controller.courses;

            if (courses.isEmpty) {
              return _EmptyCourseCard(onTap: widget.onMoreTap);
            }

            // Completed courses are pushed to the end; the rest are ordered by
            // highest module completion first.
            final sorted = [...courses]..sort((a, b) {
              final pa = ongoing?.progressForCourse(a.id);
              final pb = ongoing?.progressForCourse(b.id);
              final aComplete = pa?.isComplete ?? false;
              final bComplete = pb?.isComplete ?? false;
              if (aComplete != bComplete) return aComplete ? 1 : -1;
              final ra = pa?.ratio ?? 0.0;
              final rb = pb?.ratio ?? 0.0;
              if (ra == rb) return 0;
              return rb.compareTo(ra);
            });

            // Show up to 4 courses + "More" card
            const maxVisible = 4;
            final displayed =
                sorted.length > maxVisible ? sorted.sublist(0, maxVisible) : sorted;
            final showMore = sorted.length > maxVisible;

            return SizedBox(
              height: 128,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: displayed.length + (showMore ? 1 : 0),
                separatorBuilder: (_, __) => const HGapMd(),
                itemBuilder: (context, index) {
                  if (showMore && index == displayed.length) {
                    return _MoreCoursesCard(onTap: widget.onMoreTap);
                  }
                  final course = displayed[index];
                  final palette = _cardPalettes(context)[index % AppTheme.tintCount];
                  final progress = ongoing?.progressForCourse(course.id);
                  final isComplete = progress?.isComplete ?? false;
                  return _YourCourseCard(
                    title: course.title,
                    subtitle: _subtitleFor(course, progress),
                    progress: progress?.ratio ?? 0.0,
                    progressLabel: progress == null || !progress.hasModules
                        ? '0%'
                        : '${(progress.ratio * 100).round()}%',
                    isComplete: isComplete,
                    icon: _iconFor(index),
                    bgColor: palette.bg,
                    borderColor: palette.border,
                    accentColor: isComplete ? AppTheme.successColor : palette.accent,
                    onTap: () => widget.onCourseTap?.call(course.title),
                  );
                },
              ),
            );
          },
        ),
        const VGapSm(),
        ValueListenableBuilder<int>(
          valueListenable: _activeIndex,
          builder: (context, activeIdx, _) => _CarouselIndicatorRow(activeIndex: activeIdx),
        ),
      ],
    );
  }

  String _subtitleFor(Course course, CourseModuleProgress? progress) {
    if (progress != null) {
      if (!progress.hasModules) return 'No modules yet';
      return '${progress.completedModules} / ${progress.totalModules} modules';
    }
    if (course.description.isNotEmpty) {
      return course.description.length > 22
          ? '${course.description.substring(0, 22)}…'
          : course.description;
    }
    return course.status;
  }

  IconData _iconFor(int index) {
    const icons = [
      Icons.code_rounded,
      Icons.settings_suggest_rounded,
      Icons.smart_toy_rounded,
      Icons.android_rounded,
      Icons.menu_book_rounded,
      Icons.insights_rounded,
      Icons.hub_outlined,
      Icons.psychology_rounded,
    ];
    return icons[index % icons.length];
  }
}

class _CardPalette {
  final Color bg;
  final Color border;
  final Color accent;
  const _CardPalette(this.bg, this.border, this.accent);
}

List<_CardPalette> _cardPalettes(BuildContext context) {
  return [
    for (var i = 0; i < 4; i++)
      () {
        final tint = AppTheme.tintFor(context, i);
        return _CardPalette(tint.$1, tint.$3, tint.$2);
      }(),
  ];
}

class _HeaderRow extends StatelessWidget {
  final VoidCallback? onMoreTap;
  const _HeaderRow({this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Your Courses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        if (onMoreTap != null)
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCourseCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptyCourseCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 28),
              VGapXs(),
              Text(
                'Add your first course',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreCoursesCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _MoreCoursesCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F7FF),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.more_horiz_rounded, color: AppTheme.primaryColor, size: 32),
                  VGapSm(),
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YourCourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color accentColor;
  final bool isComplete;
  final VoidCallback? onTap;

  const _YourCourseCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.accentColor,
    this.isComplete = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accentColor, size: 16),
                  ),
                  const VGapSm(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: isComplete
                              ? AppTheme.successColor
                              : AppTheme.textSecondaryColor(context),
                          fontWeight:
                              isComplete ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const VGapXs(),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.6),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ),
                      const HGapXs(),
                      Text(
                        progressLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselIndicatorRow extends StatelessWidget {
  final int activeIndex;
  const _CarouselIndicatorRow({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 20 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
