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

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
    this.iconColor,
    this.showCard = true,
  });

  @override
  Widget build(BuildContext context) {
    // theme_rules Rule 3: repaint on theme switch.
    Theme.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.pastelIndigo(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.pastelIndigoBorder(context)),
          ),
          child: Icon(
            icon,
            size: 30,
            color: AppTheme.pastelIndigoText(context),
          ),
        ),
        const VGapMd(),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTheme.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondaryColor(context),
            height: 1.4,
          ),
        ),
        if (actionLabel != null && onActionPressed != null) ...[
          const VGapLg(),
          ElevatedButton(
            onPressed: onActionPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textOnDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
              ),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );

    if (!showCard) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          child: content,
        ),
      );
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: content,
      ),
    );
  }
}
