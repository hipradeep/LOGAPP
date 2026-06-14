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
    return Transform.translate(
      offset: const Offset(16, 0),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        padding: EdgeInsets.zero,
        color: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        ),
        onSelected: onSelected,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
