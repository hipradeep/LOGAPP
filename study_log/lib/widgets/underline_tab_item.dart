import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable underline tab button used across screen tab headers
class UnderlineTabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const UnderlineTabItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}
