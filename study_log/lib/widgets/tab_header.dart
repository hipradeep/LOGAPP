import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_back_button.dart';
import 'app_spacers.dart';

/// Reusable top header for root Bottom Navigation Bar (BNV) tab screens
/// (Home, Revision, Profile), adopting the Home screen header design:
/// - 26px bold title
/// - 13px medium subtitle below title
/// - Optional back button (when a tab screen is pushed with back navigation)
/// - Optional trailing action buttons (info, settings, etc.)
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  const TabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            AppBackButton(onPressed: onBack),
            const HGapSm(),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const VGapXs(),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const HGapSm(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}
