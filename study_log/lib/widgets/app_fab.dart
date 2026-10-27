import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unified Material 3 Floating Action Button.
///
/// Features a compact elevation (1.5) and squircle shape (radius 16)
/// adhering to the Native Minimalist design guidelines.
class AppFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primaryColor;
    final fg = foregroundColor ?? Colors.white;

    if (label != null && label!.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: tooltip,
        elevation: 1.5,
        highlightElevation: 3.0,
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label!,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      elevation: 1.5,
      highlightElevation: 3.0,
      backgroundColor: bg,
      foregroundColor: fg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 24),
    );
  }
}
