import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable dedicated top header for Bottom Navigation Bar (BNV) tab screens
/// (Home, Budgets, Log, Profile) matching [AppTheme] native minimalist design guidelines:
/// - 20px w600 primary title
/// - 12px medium secondary subtitle positioned directly below title
/// - Optional right-aligned action buttons (Settings ⚙️, Info ℹ️)
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
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget ??
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                          letterSpacing: 0,
                          height: 1.15,
                        ),
                      ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const VGapXs(),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
