import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Clean minimalist list tile matching the list style in the reference image:
/// - Rounded square icon container (#F4F4F6, radius 14)
/// - Bold title + secondary subtitle
/// - Trailing bold "ADD" action or custom trailing widget
class ActivityListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ActivityListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel = 'ADD',
    this.onActionTap,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // theme_rules Rule 3: repaint on theme switch.
    Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rounded square icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const HGapMd(),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.headingSmall.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const HGapMd(),
            // Trailing action
            if (trailing != null)
              trailing!
            else
              GestureDetector(
                onTap: onActionTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    actionLabel,
                    style: AppTheme.actionText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
