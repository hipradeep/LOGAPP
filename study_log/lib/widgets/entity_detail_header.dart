import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'module_context_pill.dart';

/// Reusable and optimized metadata chip used inside [EntityDetailHeader].
class DetailMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;
  final TextStyle? style;

  const DetailMetaChip({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 13.0,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: AppTheme.textMutedColor(context),
        ),
        const HGapXs(),
        Text(
          text,
          style: style ??
              TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor(context),
              ),
        ),
      ],
    );
  }
}

/// Reusable status badge with consistent padding, border, and typography.
class DetailStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Widget? trailing;

  const DetailStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Unified, high-performance header component for:
/// - Topic detail & Revision topic detail
/// - Module detail & Revision module detail
class EntityDetailHeader extends StatelessWidget {
  final String title;
  final String? courseTitle;
  final String? courseId;
  final Widget? trailingAction;
  final double horizontalPadding;

  // Metadata chips
  final String? countText;
  final String? dateText;
  final String? durationText;
  final List<Widget> additionalChips;

  // Status badge or interactive menu
  final Widget? statusWidget;
  final bool showDivider;

  static final DateFormat _dateFormat = DateFormat('d MMM, yyyy');

  const EntityDetailHeader({
    super.key,
    required this.title,
    this.courseTitle,
    this.courseId,
    this.trailingAction,
    this.horizontalPadding = 16.0,
    this.countText,
    this.dateText,
    this.durationText,
    this.additionalChips = const [],
    this.statusWidget,
    this.showDivider = false,
  });

  /// Cached date formatter helper adhering to Rule 6 (Expensive Object Allocation Gravity)
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Consistent duration formatter helper: '0h', '45m', '1.5h'
  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes / 60.0;
    if (minutes % 60 == 0) {
      return '${hours.toInt()}h';
    } else if (hours < 1.0) {
      return '${minutes}m';
    } else {
      return '${hours.toStringAsFixed(1).replaceAll('.0', '')}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final titlePill = ModuleContextPill(
      moduleTitle: title,
      courseId: courseId,
      courseTitle: courseTitle,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingAction != null)
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: titlePill,
                  ),
                ),
                const HGapSm(),
                trailingAction!,
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: titlePill,
            ),
          const VGapXs(),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (countText != null && countText!.isNotEmpty)
                DetailMetaChip(
                  icon: Icons.task_alt_rounded,
                  text: countText!,
                ),
              if (dateText != null && dateText!.isNotEmpty)
                DetailMetaChip(
                  icon: Icons.calendar_today_rounded,
                  iconSize: 12.0,
                  text: dateText!,
                ),
              if (durationText != null && durationText!.isNotEmpty)
                DetailMetaChip(
                  icon: Icons.schedule_rounded,
                  text: durationText!,
                ),
              ...additionalChips,
              ?statusWidget,
            ],
          ),
          if (showDivider) ...[
            const VGapSm(),
            Divider(
              height: 8,
              thickness: 1.0,
              color: AppTheme.borderColor(context),
            ),
          ],
        ],
      ),
    );
  }
}
