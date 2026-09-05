import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppPremiumFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final double bottom;
  final double right;

  const AppPremiumFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.bottom = 96,
    this.right = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      right: right,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
