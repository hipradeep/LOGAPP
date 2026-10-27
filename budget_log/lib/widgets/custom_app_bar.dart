import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_back_button.dart';
import 'app_spacers.dart';

export 'app_back_button.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.only(
      left: AppTheme.spacingXs,
      right: AppTheme.spacingMd,
      top: AppTheme.spacingXs,
      bottom: AppTheme.spacingXs,
    ),
    this.backgroundColor = Colors.transparent,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasLeading = leading != null || showBackButton;

    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = leading;
    } else if (showBackButton) {
      leadingWidget = AppBackButton(onPressed: onBack);
    }

    return Container(
      color: backgroundColor,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasLeading && leadingWidget != null) ...[
                leadingWidget,
                const HGapXs(),
              ],
              if (titleWidget != null)
                Expanded(child: titleWidget!)
              else if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                    style: textTheme.titleLarge,
                  ),
                )
              else
                const Spacer(),
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
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const VGapXs(),
            Padding(
              padding: EdgeInsets.only(
                left: hasLeading ? AppTheme.spacingXl + AppTheme.spacingXs : 0,
              ),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
