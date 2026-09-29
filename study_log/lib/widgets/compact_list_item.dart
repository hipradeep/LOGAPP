import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable compact list item component used across all list screens.
///
/// Features:
/// - Compact height (~48-60px) maximizing information density.
/// - Flexible leading widget (icon chip, status indicator, numbered badge, pastel icon).
/// - Title with optional trailing badge (e.g. R-level pill, completed badge).
/// - Rich context metadata: handles description, course name, module name, or breadcrumbs.
/// - Optional bottom row (progress bar with percentage, due date status, etc.).
/// - Supports both card mode (surface, border, soft shadow, bottom margin)
///   and flat tile mode (transparent, ideal for [ListView.separated]).
class CompactListItem extends StatelessWidget {
  final Widget? leading;
  final String title;
  final Widget? titleBadge;
  final String? subtitle;
  final String? courseName;
  final String? moduleName;
  final Widget? bottom;
  final Widget? trailing;
  final bool showTrailingChevron;
  final bool isCard;
  final bool isCompleted;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const CompactListItem({
    super.key,
    this.leading,
    required this.title,
    this.titleBadge,
    this.subtitle,
    this.courseName,
    this.moduleName,
    this.bottom,
    this.trailing,
    this.showTrailingChevron = true,
    this.isCard = true,
    this.isCompleted = false,
    this.accentColor,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        (isCard
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8));

    final effectiveMargin = margin ??
        (isCard ? const EdgeInsets.only(bottom: 8.0) : EdgeInsets.zero);

    Widget content = RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(
            isCard ? AppTheme.defaultBorderRadius : AppTheme.smallBorderRadius,
          ),
          child: Ink(
            padding: effectivePadding,
            decoration: isCard
                ? BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius:
                        BorderRadius.circular(AppTheme.defaultBorderRadius),
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.successColor.withValues(alpha: 0.25)
                          : AppTheme.borderColor(context),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.shadowColor(context),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const HGapSm(),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Context breadcrumb (course / module name) if present
                      if (_hasContextLabel) ...[
                        _buildContextRow(context),
                        const SizedBox(height: 2),
                      ],

                      // Title row with optional badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? AppTheme.textSecondaryColor(context)
                                    : AppTheme.textPrimaryColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (titleBadge != null) ...[
                            const HGapXs(),
                            titleBadge!,
                          ],
                        ],
                      ),

                      // Subtitle / Description if present
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isCompleted
                                ? AppTheme.successColor
                                : AppTheme.textSecondaryColor(context),
                            fontWeight: isCompleted
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Bottom custom slot (progress bar, due chip, tags)
                      if (bottom != null) ...[
                        const SizedBox(height: 6),
                        bottom!,
                      ],
                    ],
                  ),
                ),
                if (_hasTrailing) ...[
                  const HGapSm(),
                  trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMutedColor(context),
                        size: 20,
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (effectiveMargin != EdgeInsets.zero) {
      content = Padding(
        padding: effectiveMargin,
        child: content,
      );
    }

    return content;
  }

  bool get _hasContextLabel {
    return (courseName != null && courseName!.trim().isNotEmpty) ||
        (moduleName != null && moduleName!.trim().isNotEmpty);
  }

  bool get _hasTrailing => showTrailingChevron || trailing != null;

  Widget _buildContextRow(BuildContext context) {
    final segments = <String>[];
    if (courseName != null && courseName!.trim().isNotEmpty) {
      segments.add(courseName!.trim());
    }
    if (moduleName != null && moduleName!.trim().isNotEmpty) {
      segments.add(moduleName!.trim());
    }

    return Text(
      segments.join(' › '),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: accentColor ?? AppTheme.primaryColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
