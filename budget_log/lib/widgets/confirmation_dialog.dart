import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class ConfirmationDialog extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool destructive;
  final Color? confirmColor;

  const ConfirmationDialog({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.destructive = false,
    this.confirmColor,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
    IconData? icon,
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        icon: icon,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        destructive: destructive,
        confirmColor: confirmColor,
      ),
    );
    return result ?? false;
  }

  static Future<bool> showDelete(
    BuildContext context, {
    required String entityName,
    String? title,
    String? message,
  }) {
    return show(
      context,
      title: title ?? 'Delete $entityName?',
      message: message ?? 'This action cannot be undone.',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final actionColor =
        confirmColor ??
        (destructive ? AppTheme.errorColor : colorScheme.primary);
    final actionForeground = destructive
        ? colorScheme.onError
        : colorScheme.onPrimary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: actionColor),
              ),
              const VGapMd(),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const VGapSm(),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const VGapLg(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelText),
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: actionForeground,
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
