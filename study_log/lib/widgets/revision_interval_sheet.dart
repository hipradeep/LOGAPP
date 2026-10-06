import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import 'app_spacers.dart';

/// Modal bottom sheet detailing the 5-stage spaced repetition interval schedule.
class RevisionIntervalSheet extends StatelessWidget {
  const RevisionIntervalSheet({super.key});

  /// Displays the [RevisionIntervalSheet] as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RevisionIntervalSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VGapMd(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spaced Repetition Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMutedColor(context),
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const VGapXs(),
            Text(
              'The study ladder uses 5 intervals to lock knowledge into long-term memory:',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const VGapMd(),
            const _IntervalRow(level: 1, interval: '1 day after completion'),
            const _IntervalRow(level: 2, interval: '3 days after R1'),
            const _IntervalRow(level: 3, interval: '7 days after R2'),
            const _IntervalRow(level: 4, interval: '14 days after R3'),
            const _IntervalRow(level: 5, interval: '30 days after R4 (Mastered)'),
            const VGapMd(),
          ],
        ),
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final int level;
  final String interval;

  const _IntervalRow({
    required this.level,
    required this.interval,
  });

  @override
  Widget build(BuildContext context) {
    final colors = RevisionLevelPalette.of(context, level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Text(
              'R$level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              interval,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
