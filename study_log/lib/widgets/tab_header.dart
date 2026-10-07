import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable dedicated top header for Bottom Navigation Bar (BNV) tab screens
/// (Home, Revision, Profile) matching [AppTheme] design guidelines:
/// - 26px bold primary title
/// - 12px medium secondary subtitle positioned directly below title
/// - Optional right-aligned action buttons (Settings ⚙️, Info ℹ️, Notifications 🔔)
///   vertically centered directly with the main title line.
class TabHeader extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  const TabHeader({
    super.key,
    this.title = '',
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: titleWidget ??
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const HGapSm(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const VGapXs(),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
