import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A rounded pastel square holding a course glyph.
///
/// The glyph is derived from [courseId] rather than a list index, so the same
/// course always shows the same icon no matter how the list is sorted or
/// filtered. Callers can override [background], [foreground] and [borderColor]
/// to keep an existing colour scheme; otherwise the [defaultBackgrounds] and
/// [defaultForegrounds] cycle is used.
class CourseIconChip extends StatelessWidget {
  final String courseId;
  final double size;
  final double radius;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;

  const CourseIconChip({
    super.key,
    required this.courseId,
    this.size = 44,
    this.radius = 12,
    this.background,
    this.foreground,
    this.borderColor,
  });

  static const List<IconData> _icons = [
    Icons.code_rounded,
    Icons.settings_suggest_rounded,
    Icons.smart_toy_rounded,
    Icons.android_rounded,
    Icons.cloud_rounded,
    Icons.security_rounded,
  ];

  static const List<Color> defaultBackgrounds = [
    AppTheme.pastelPurple,
    AppTheme.pastelGreen,
    AppTheme.pastelOrange,
    Color(0xFFE0F2FE),
    Color(0xFFEEF2FF),
    Color(0xFFECFEFF),
  ];

  static const List<Color> defaultForegrounds = [
    AppTheme.pastelPurpleText,
    AppTheme.pastelGreenText,
    AppTheme.pastelOrangeText,
    Color(0xFF0284C7),
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
  ];

  /// Stable index for [key] across restarts, unlike a list position.
  static int stableIndex(String key, int length) {
    if (key.isEmpty) return 0;
    return key.hashCode.abs() % length;
  }

  @override
  Widget build(BuildContext context) {
    final index = stableIndex(courseId, _icons.length);
    final glyphSize = size * 0.55;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? defaultBackgrounds[index],
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      alignment: Alignment.center,
      child: Icon(
        _icons[index],
        color: foreground ?? defaultForegrounds[index],
        size: glyphSize,
      ),
    );
  }
}
