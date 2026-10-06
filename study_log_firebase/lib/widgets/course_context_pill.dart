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
  final EdgeInsetsGeometry? padding;

  const CourseContextPill({
    super.key,
    required this.courseTitle,
    this.courseId,
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
    if (courseTitle.isEmpty) return const SizedBox.shrink();

    final course = _lookupCourse();
    final IconData iconData =
        courseIconFrom(course?.iconCodePoint, fallback: Icons.school_rounded);

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
