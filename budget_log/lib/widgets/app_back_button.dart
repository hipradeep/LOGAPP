import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size = 28.0,
    this.tooltip = 'Back',
  });

  void _handlePress(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.chevron_left_rounded,
        color: color ?? AppTheme.textPrimaryColor(context),
        size: size,
      ),
      onPressed: () => _handlePress(context),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
      splashRadius: 20,
    );
  }
}
