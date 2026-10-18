import 'package:flutter/material.dart';
import '../models/topic_revision.dart';
import '../theme/revision_level_palette.dart';

/// Compact badge indicating the spaced repetition level and status for a topic.
///
/// Examples:
/// - Active: [R2] (Level pastel)
/// - Mastered / Finished: [R5 ✓] (Pastel Green)
class TopicRevisionBadge extends StatelessWidget {
  final TopicRevision revision;
  final bool showDueStatus;

  const TopicRevisionBadge({
    super.key,
    required this.revision,
    this.showDueStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDue = showDueStatus && revision.isDueAt(now);
    final colors = revision.isFinished
        ? RevisionLevelPalette.completed(context)
        : RevisionLevelPalette.of(context, revision.currentLevel);

    final String label;
    if (revision.isFinished) {
      label = 'R${revision.currentLevel} ✓';
    } else {
      label = 'R${revision.currentLevel}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDue ? colors.border : colors.border.withValues(alpha: 0.5),
          width: isDue ? 1.0 : 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: colors.foreground,
          height: 1.1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
