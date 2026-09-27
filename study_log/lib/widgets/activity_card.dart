import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Interactive activity card matching the design in the reference image:
/// - Light variant: soft grey container (#F4F4F6), dark text, circular dark action button
/// - Featured/Dark variant: deep charcoal container (#1E1E1E), white text, duration pill badge, circular light action button
class ActivityCard extends StatelessWidget {
  final String title;
  final String duration;
  final bool isFeatured;
  final VoidCallback? onTap;
  final Widget? illustration;
  final IconData? icon;

  const ActivityCard({
    super.key,
    required this.title,
    required this.duration,
    this.isFeatured = false,
    this.onTap,
    this.illustration,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // theme_rules Rule 3: repaint on theme switch.
    Theme.of(context);
    final bgColor = isFeatured ? AppTheme.surface(context) : AppTheme.surfaceVariant(context);
    final titleColor = isFeatured ? AppTheme.textOnDark : AppTheme.textPrimaryColor(context);
    final durationColor = isFeatured ? AppTheme.textOnDarkSecondary : AppTheme.textSecondaryColor(context);
    final arrowBgColor = isFeatured ? AppTheme.surface(context) : AppTheme.primaryColor;
    final arrowIconColor = isFeatured ? AppTheme.primaryColor : AppTheme.textOnDark;

    return Semantics(
      button: true,
      label: '$title, $duration',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              border: isFeatured
                  ? null
                  : Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
            ),
            padding: AppTheme.defaultCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headingSmall.copyWith(
                          color: titleColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeFill(context),
                            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Text(
                            duration,
                            style: AppTheme.bodySmall.copyWith(
                              color: durationColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Text(
                          duration,
                          style: AppTheme.bodySmall.copyWith(color: durationColor),
                        ),
                      const VGapMd(),
                      // Circular action button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: arrowBgColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: arrowIconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const HGapMd(),
                if (illustration != null)
                  illustration!
                else if (icon != null)
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 44,
                      color: isFeatured ? Colors.white38 : AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
