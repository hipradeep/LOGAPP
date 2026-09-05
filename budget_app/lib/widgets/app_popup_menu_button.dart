import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppPopupMenuButton<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget? icon;

  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      icon: icon ?? Icon(Icons.more_vert_rounded, color: AppTheme.textSecondaryColor(context)),
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        side: BorderSide(color: AppTheme.borderColor(context)),
      ),
      elevation: 8,
      itemBuilder: itemBuilder,
      onSelected: onSelected,
    );
  }
}
