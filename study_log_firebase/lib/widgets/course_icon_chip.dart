import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/course_icon_util.dart';

/// A rounded pastel square holding a course glyph.
///
/// If [courseId] corresponds to a Course with a custom [iconCodePoint] or
/// [colorValue] (or if those are explicitly supplied), it displays that icon
/// and color palette.
/// Otherwise, falls back to a deterministic stable hash and cycling palette.
class CourseIconChip extends StatelessWidget {
  final String courseId;
  final double size;
  final double radius;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final int? iconCodePoint;
  final int? colorValue;

  const CourseIconChip({
    super.key,
    required this.courseId,
    this.size = 44,
    this.radius = 12,
    this.background,
    this.foreground,
    this.borderColor,
    this.iconCodePoint,
    this.colorValue,
  });

  static const List<IconData> _icons = [
    Icons.code_rounded,
    Icons.settings_suggest_rounded,
    Icons.smart_toy_rounded,
    Icons.android_rounded,
    Icons.cloud_rounded,
    Icons.security_rounded,
  ];

  /// Stable index for [key] across restarts, unlike a list position.
  static int stableIndex(String key, int length) {
    if (key.isEmpty) return 0;
    return key.hashCode.abs() % length;
  }

  Course? _lookupCourse() {
    if (courseId.isEmpty) return null;
    if (!getIt.isRegistered<CoursesController>()) return null;
    try {
      final courses = getIt<CoursesController>().courses;
      for (final c in courses) {
        if (c.id == courseId) return c;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final matchedCourse = _lookupCourse();
    final effectiveIconCode = iconCodePoint ?? matchedCourse?.iconCodePoint;
    final effectiveColorValue = colorValue ?? matchedCourse?.colorValue;

    final index = stableIndex(courseId, _icons.length);
    final tint = AppTheme.tintFor(context, index);
    final glyphSize = size * 0.55;

    final Color effectiveFg;
    final Color effectiveBg;
    final Color effectiveBorder;

    if (effectiveColorValue != null) {
      final baseColor = Color(effectiveColorValue);
      effectiveFg = foreground ?? baseColor;
      effectiveBg = background ?? baseColor.withValues(alpha: 0.12);
      effectiveBorder = borderColor ?? baseColor.withValues(alpha: 0.35);
    } else {
      effectiveFg = foreground ?? tint.$2;
      effectiveBg = background ?? tint.$1;
      effectiveBorder = borderColor ?? tint.$3;
    }

    final IconData effectiveIcon = courseIconFrom(
      effectiveIconCode,
      fallback: _icons[index],
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder, width: 1.0),
      ),
      alignment: Alignment.center,
      child: Icon(
        effectiveIcon,
        color: effectiveFg,
        size: glyphSize,
      ),
    );
  }
}
