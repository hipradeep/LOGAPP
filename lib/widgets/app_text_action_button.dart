import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AppTextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.primaryAccentColor(context),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
