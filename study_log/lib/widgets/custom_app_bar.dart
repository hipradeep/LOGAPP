import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_back_button.dart';
import 'app_spacers.dart';

export 'app_back_button.dart';

/// Reusable custom app bar matching [AppTheme] design guidelines.
///
/// Can be used:
/// 1. Directly in a [Column] below [SafeArea]:
///    `CustomAppBar(title: 'My Screen', actions: [...])`
/// 2. As a [Scaffold.appBar] (implements [PreferredSizeWidget]):
///    `appBar: CustomAppBar(title: 'My Screen')`
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
  final BackButtonVariant backButtonVariant;
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
    this.padding = const EdgeInsets.only(left: 4.0, right: 16.0, top: 4.0, bottom: 4.0),
    this.backgroundColor = Colors.transparent,
    this.backButtonVariant = BackButtonVariant.plain,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final hasLeading = leading != null || showBackButton;

    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = leading;
    } else if (showBackButton) {
      leadingWidget = AppBackButton(
        onPressed: onBack,
        variant: backButtonVariant,
      );
    }

    Widget? titleContent;
    if (titleWidget != null) {
      titleContent = titleWidget;
    } else if (title != null) {
      titleContent = Column(
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 1),
          ],
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.2,
            ),
          ),
        ],
      );
    }

    return Container(
      color: backgroundColor,
      padding: padding,
      child: Row(
        children: [
          if (hasLeading && leadingWidget != null) ...[
            leadingWidget,
            const HGapXs(),
          ],
          if (titleContent != null)
            Expanded(
              child: titleContent,
            )
          else
            const Spacer(),
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
