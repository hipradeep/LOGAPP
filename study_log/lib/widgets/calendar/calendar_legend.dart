import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/revision_level_palette.dart';
import '../app_spacers.dart';

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}

/// Horizontal legend showing the color dots for:
/// Completion, R1 (1 day), R2 (3 days), R3 (7 days), R4 (14 days), R5 (30 days)
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  static const List<String> _labels = [
    'Completion',
    'R1 (1 day)',
    'R2 (3 days)',
    'R3 (7 days)',
    'R4 (14 days)',
    'R5 (30 days)',
  ];

  @override
  Widget build(BuildContext context) {
    final items = <_LegendItem>[
      _LegendItem(_labels[0], RevisionLevelPalette.completed(context).foreground),
      for (var level = 1; level < _labels.length; level++)
        _LegendItem(
          _labels[level],
          RevisionLevelPalette.of(context, level).foreground,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: items.map((item) => _LegendPill(item: item)).toList(),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final _LegendItem item;

  const _LegendPill({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        ),
        const HGapXs(),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}
