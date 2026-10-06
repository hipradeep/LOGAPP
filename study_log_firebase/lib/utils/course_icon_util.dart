import 'package:flutter/material.dart';

/// All icons available for course selection and rendering.
///
/// Must remain a compile-time const list so that Flutter's icon tree-shaker
/// can statically determine which Material icon glyphs are in use during release builds.
/// Never construct IconData(codePoint, ...) at runtime — use [courseIconFrom]
/// to resolve a stored codePoint back to one of these const values.
const List<IconData> kCourseIcons = [
  Icons.format_list_bulleted_rounded,
  Icons.code_rounded,
  Icons.terminal_rounded,
  Icons.data_object_rounded,
  Icons.settings_suggest_rounded,
  Icons.smart_toy_rounded,
  Icons.android_rounded,
  Icons.flutter_dash_rounded,
  Icons.cloud_outlined,
  Icons.cloud_rounded,
  Icons.hub_outlined,
  Icons.menu_book_rounded,
  Icons.school_rounded,
  Icons.psychology_rounded,
  Icons.storage_rounded,
  Icons.dns_rounded,
  Icons.coffee_rounded,
  Icons.directions_boat_rounded,
  Icons.account_tree_rounded,
  Icons.science_rounded,
  Icons.calculate_rounded,
  Icons.palette_rounded,
  Icons.laptop_chromebook_rounded,
  Icons.biotech_rounded,
  Icons.architecture_rounded,
  Icons.security_rounded,
  Icons.auto_stories_rounded,
  Icons.book_rounded,
  Icons.bookmark_rounded,
  Icons.lightbulb_rounded,
  Icons.public_rounded,
  Icons.analytics_rounded,
];

/// Resolves a stored [codePoint] to a const [IconData] from [kCourseIcons].
///
/// Falls back to [fallback] when the codePoint is null or doesn't match any known icon.
IconData courseIconFrom(int? codePoint, {IconData fallback = Icons.school_rounded}) {
  if (codePoint == null) return fallback;
  for (final icon in kCourseIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return fallback;
}
