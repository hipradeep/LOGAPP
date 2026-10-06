import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/course_icon_util.dart';
import 'app_spacers.dart';

/// Reusable pastel pill displaying the module name with the course icon.
///
/// Matches the styling on [AddTopicScreen] and [ModuleDetailScreen].
class ModuleContextPill extends StatelessWidget {
  final String moduleTitle;
  final String? courseId;
  final String? courseTitle;
  final EdgeInsetsGeometry? padding;

  const ModuleContextPill({
    super.key,
    required this.moduleTitle,
    this.courseId,
    this.courseTitle,
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
              moduleTitle,
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
