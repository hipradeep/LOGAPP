import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      textStyle: AppTheme.bodySmall.copyWith(
        color: AppTheme.textPrimaryColor(context),
      ),
      child: child,
    );
  }
}
