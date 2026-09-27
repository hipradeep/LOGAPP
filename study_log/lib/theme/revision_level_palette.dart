import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The foreground / background / border triple used to render one revision
/// level, or the completed state.
@immutable
class RevisionLevelColors {
  final Color foreground;
  final Color background;
  final Color border;

  const RevisionLevelColors({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

/// Single source of truth for revision level colours.
///
/// Previously each of [CalendarEvent], the Calendar screen, the Revision
/// screen and the Calendar legend carried its own copy of the R1-R5 table, so
/// the levels drifted apart and every table needed editing twice to become
/// theme-aware. Resolve them through here instead.
class RevisionLevelPalette {
  const RevisionLevelPalette._();

  /// Colours for a 1-based revision level, where level 1 is the most urgent.
  static RevisionLevelColors of(BuildContext context, int level) {
    return switch (level) {
      1 => RevisionLevelColors(
          foreground: AppTheme.pastelCoralText(context),
          background: AppTheme.pastelCoral(context),
          border: AppTheme.pastelCoralBorder(context),
        ),
      2 => RevisionLevelColors(
          foreground: AppTheme.pastelOrangeText(context),
          background: AppTheme.pastelOrange(context),
          border: AppTheme.pastelOrangeBorder(context),
        ),
      3 => RevisionLevelColors(
          foreground: AppTheme.pastelSkyText(context),
          background: AppTheme.pastelSky(context),
          border: AppTheme.pastelSkyBorder(context),
        ),
      4 => RevisionLevelColors(
          foreground: AppTheme.pastelPurpleText(context),
          background: AppTheme.pastelPurple(context),
          border: AppTheme.pastelPurpleBorder(context),
        ),
      _ => RevisionLevelColors(
          foreground: AppTheme.pastelGreenText(context),
          background: AppTheme.pastelGreen(context),
          border: AppTheme.pastelGreenBorder(context),
        ),
    };
  }

  /// Colours for a topic that has reached its target date.
  static RevisionLevelColors completed(BuildContext context) {
    return RevisionLevelColors(
      foreground: AppTheme.pastelGreenText(context),
      background: AppTheme.pastelGreen(context),
      border: AppTheme.pastelGreenBorder(context),
    );
  }
}
