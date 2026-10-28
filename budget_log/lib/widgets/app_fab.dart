import 'package:flutter/material.dart';

class AppFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Object? heroTag;

  const AppFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = backgroundColor ?? colorScheme.primary;
    final foreground = foregroundColor ?? colorScheme.onPrimary;

    if (label != null && label!.isNotEmpty) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: tooltip,
        elevation: 1.5,
        highlightElevation: 3.0,
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(icon, size: 20),
        label: Text(
          label!,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      elevation: 1.5,
      highlightElevation: 3.0,
      backgroundColor: background,
      foregroundColor: foreground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, size: 24),
    );
  }
}
