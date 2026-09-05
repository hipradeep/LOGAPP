import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const AppTextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: isPrimary ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
        ),
      ),
    );
  }
}
