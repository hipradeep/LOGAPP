import 'package:flutter/material.dart';

/// All icons available for topic selection.
///
/// Must remain a compile-time const list so that Flutter's icon tree-shaker
/// can statically determine which Material icon glyphs are in use.
/// Never construct IconData(codePoint, ...) at runtime — use [topicIconFrom]
/// to resolve a stored codePoint back to one of these const values.
const List<IconData> kTopicIcons = [
  Icons.format_list_bulleted_rounded,
  Icons.code_rounded,
  Icons.functions_rounded,
  Icons.data_object_rounded,
  Icons.terminal_rounded,
  Icons.hub_outlined,
  Icons.account_tree_outlined,
  Icons.menu_book_rounded,
  Icons.psychology_rounded,
  Icons.insights_rounded,
  Icons.auto_stories_rounded,
  Icons.bolt_rounded,
  Icons.description_outlined,
];

/// Resolves a stored [codePoint] to a const [IconData] from [kTopicIcons].
///
/// Falls back to [Icons.description_outlined] when the codePoint is null or
/// doesn't match any known icon.
IconData topicIconFrom(int? codePoint) {
  if (codePoint == null) return Icons.description_outlined;
  for (final icon in kTopicIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.description_outlined;
}
