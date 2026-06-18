import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppToast {
  static void show({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Color? backgroundColor,
  }) {
    final actualBgColor = backgroundColor ?? AppTheme.primaryColor;
    ScaffoldMessenger.of(context).clearSnackBars();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: actualBgColor,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.textPrimary.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        action: actionLabel != null && onActionPressed != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.textPrimary,
                onPressed: onActionPressed,
              )
            : null,
      ),
    );

    // Force hide after duration to override Flutter's persistent action snackbar behavior
    Future.delayed(const Duration(seconds: 3), () {
      try {
        controller.close();
      } catch (_) {}
    });
  }
}
