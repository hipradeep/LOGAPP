import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/course_icon_util.dart';
import 'app_spacers.dart';

/// Reusable pastel pill displaying the course name with the course icon.
///
/// Matches the styling of [ModuleContextPill] across [CourseDetailScreen] and [AddModuleScreen].
class CourseContextPill extends StatelessWidget {
  final String courseTitle;
  final String? courseId;
  final bool showCard;
  final EdgeInsetsGeometry? padding;

  const CourseContextPill({
    super.key,
    required this.courseTitle,
    this.courseId,
    this.showCard = true,
    this.padding,
  });

  Course? _lookupCourse() {
    if (!getIt.isRegistered<CoursesController>()) return null;
    try {
      final courses = getIt<CoursesController>().courses;
      for (final c in courses) {
        if ((courseId != null && courseId!.isNotEmpty && c.id == courseId) ||
            (courseTitle.isNotEmpty && c.title.toLowerCase() == courseTitle.toLowerCase())) {
          return c;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final course = _lookupCourse();
    final resolvedCourseTitle = courseTitle.isNotEmpty
        ? courseTitle
        : (course?.title ?? '');

    if (resolvedCourseTitle.isEmpty) return const SizedBox.shrink();

    final IconData iconData =
        courseIconFrom(course?.iconCodePoint, fallback: Icons.school_rounded);

    if (!showCard) {
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
            TextSpan(
              text: resolvedCourseTitle,
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
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
            size: 14,
            color: fgColor,
          ),
          const HGapXs(),
          Flexible(
            child: Text(
              courseTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
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
