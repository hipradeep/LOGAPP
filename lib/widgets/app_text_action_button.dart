import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Offset offset;

  const AppTextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.offset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.only(left: 8, right: 0),
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
      ),
    );
  }
}
