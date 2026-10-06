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

  /// Standard R1..R5 ladder levels.
  static const List<int> levels = [1, 2, 3, 4, 5];

  /// Standard spaced repetition intervals.
  static String interval(int level) => switch (level) {
        1 => '1 day',
        2 => '3 days',
        3 => '7 days',
        4 => '14 days',
        5 => '30 days',
        _ => '',
      };

  /// Colours for a 1-based revision level, resolved theme-aware from [AppTheme].
  /// Matches the level scheme:
  /// R1 (1 day)   -> Purple
  /// R2 (3 days)  -> Blue
  /// R3 (7 days)  -> Sky / Teal
  /// R4 (14 days) -> Orange
  /// R5 (30 days) -> Coral Red
  static RevisionLevelColors of(BuildContext context, int level) {
    return switch (level) {
      1 => RevisionLevelColors(
          foreground: AppTheme.pastelPurpleText(context),
          background: AppTheme.pastelPurple(context),
          border: AppTheme.pastelPurpleBorder(context),
        ),
      2 => RevisionLevelColors(
          foreground: AppTheme.pastelBlueText(context),
          background: AppTheme.pastelBlue(context),
          border: AppTheme.pastelBlueBorder(context),
        ),
      3 => RevisionLevelColors(
          foreground: AppTheme.pastelSkyText(context),
          background: AppTheme.pastelSky(context),
          border: AppTheme.pastelSkyBorder(context),
        ),
      4 => RevisionLevelColors(
          foreground: AppTheme.pastelOrangeText(context),
          background: AppTheme.pastelOrange(context),
          border: AppTheme.pastelOrangeBorder(context),
        ),
      _ => RevisionLevelColors(
          foreground: AppTheme.pastelCoralText(context),
          background: AppTheme.pastelCoral(context),
          border: AppTheme.pastelCoralBorder(context),
        ),
    };
  }

  /// Colours for a topic or module completion milestone -> Green
  static RevisionLevelColors completed(BuildContext context) {
    return RevisionLevelColors(
      foreground: AppTheme.pastelGreenText(context),
      background: AppTheme.pastelGreen(context),
      border: AppTheme.pastelGreenBorder(context),
    );
  }
}
