import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppPremiumFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const AppPremiumFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + 36,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
