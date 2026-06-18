import 'package:flutter/material.dart';
import '../theme/app_theme.dart';


class AppPopupMenuButton extends StatelessWidget {
  final PopupMenuItemSelected<String> onSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder;

  const AppPopupMenuButton({
    super.key,
    required this.onSelected,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppTheme.textPrimaryColor(context),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      ),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
    );
  }
}
