import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/course_icon_util.dart';
import 'app_spacers.dart';

/// Reusable pastel pill displaying the module name with the course icon,
/// with optional breadcrumb navigation display (`[icon] Course Name > Module Name`).
///
/// Matches the styling on [AddTopicScreen], [TopicDetailScreen], and [ModuleDetailScreen].
class ModuleContextPill extends StatelessWidget {
  final String moduleTitle;
  final String? courseId;
  final String? courseTitle;
  final bool showBreadcrumb;
  final bool? showCard;
  final EdgeInsetsGeometry? padding;

  const ModuleContextPill({
    super.key,
    required this.moduleTitle,
    this.courseId,
    this.courseTitle,
    this.showBreadcrumb = false,
    this.showCard,
    this.padding,
  });

  Course? _lookupCourse() {
    if (!getIt.isRegistered<CoursesController>()) return null;
    try {
      final courses = getIt<CoursesController>().courses;
      for (final c in courses) {
        if ((courseId != null && courseId!.isNotEmpty && c.id == courseId) ||
            (courseTitle != null && courseTitle!.isNotEmpty && c.title.toLowerCase() == courseTitle!.toLowerCase())) {
          return c;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (moduleTitle.isEmpty) return const SizedBox.shrink();

    final course = _lookupCourse();
    final IconData iconData = courseIconFrom(
      course?.iconCodePoint,
      fallback: Icons.auto_stories_rounded,
    );

    final resolvedCourseTitle = courseTitle?.isNotEmpty == true
        ? courseTitle!
        : (course?.title ?? '');

    final bool effectiveShowCard = showCard ?? !showBreadcrumb;

    if (!effectiveShowCard) {
      final Color courseColor = course?.colorValue != null
          ? Color(course!.colorValue!)
          : AppTheme.textSecondaryColor(context);

      final breadcrumbStyle = TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondaryColor(context),
        letterSpacing: 0,
      );

      Widget plain = Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 5.0),
                child: Icon(
                  iconData,
                  size: 13.0,
                  color: courseColor,
                ),
              ),
            ),
            if (showBreadcrumb && resolvedCourseTitle.isNotEmpty) ...[
              TextSpan(
                text: resolvedCourseTitle,
                style: breadcrumbStyle,
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 13.0,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
            ],
            TextSpan(
              text: moduleTitle,
              style: breadcrumbStyle,
            ),
          ],
        ),
      );

      if (padding != null) {
        plain = Padding(padding: padding!, child: plain);
      }
      return plain;
    }

    final Color fgColor;
    final Color bgColor;
    final Color borderColor;

    if (course?.colorValue != null) {
      final base = Color(course!.colorValue!);
      fgColor = base;
      bgColor = base.withValues(alpha: 0.12);
      borderColor = base.withValues(alpha: 0.30);
    } else {
      fgColor = AppTheme.pastelPurpleText(context);
      bgColor = AppTheme.pastelPurple(context);
      borderColor = AppTheme.pastelPurpleBorder(context);
    }

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: 13.5,
            color: fgColor,
          ),
          if (showBreadcrumb && resolvedCourseTitle.isNotEmpty) ...[
            const HGapXs(),
            Flexible(
              child: Text(
                resolvedCourseTitle,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 13,
                color: fgColor.withValues(alpha: 0.7),
              ),
            ),
          ] else ...[
            const HGapXs(),
          ],
          Flexible(
            child: Text(
              moduleTitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (padding != null) {
      pill = Padding(padding: padding!, child: pill);
    }

    return pill;
  }
}
