import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Color? iconColor;
  final bool showCard;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
    this.iconColor,
    this.showCard = true,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = iconColor ?? AppTheme.primaryColor;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 28, color: accent),
        ),
        const VGapMd(),
        Text(title, textAlign: TextAlign.center, style: textTheme.titleMedium),
        const VGapSm(),
        Text(
          description,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        if (actionLabel != null && onActionPressed != null) ...[
          const VGapLg(),
          FilledButton(onPressed: onActionPressed, child: Text(actionLabel!)),
        ],
      ],
    );

    if (!showCard) {
      return Center(
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.fromLTRB(
                AppTheme.spacingLg,
                AppTheme.spacingXxl,
                AppTheme.spacingLg,
                AppTheme.spacingXl,
              ),
          child: content,
        ),
      );
    }

    return Center(
      child: Container(
        width: double.infinity,
        margin:
            margin ??
            const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingLg,
            ),
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: content,
      ),
    );
  }
}
