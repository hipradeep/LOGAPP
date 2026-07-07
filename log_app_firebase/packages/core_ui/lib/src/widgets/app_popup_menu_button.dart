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
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      ),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 8),
        color: Colors.transparent,
        child: Icon(
          Icons.more_vert,
          color: AppTheme.textPrimaryColor(context),
          size: 20,
        ),
      ),
    );
  }
}
