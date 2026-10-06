import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BackButtonVariant {
  plain,
  circle,
  squircle,
}

/// Reusable custom back button matching [AppTheme].
///
/// Supports three styles:
/// - [BackButtonVariant.plain]: Minimal, frictionless chevron icon button.
/// - [BackButtonVariant.circle]: Circular container with surface background and border.
/// - [BackButtonVariant.squircle]: Rounded rectangle container with subtle border.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final BackButtonVariant variant;
  final Color? color;
  final double size;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.variant = BackButtonVariant.plain,
    this.color,
    this.size = 28.0,
    this.tooltip = 'Back',
  });

  void _handlePress(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppTheme.textPrimaryColor(context);

    switch (variant) {
      case BackButtonVariant.plain:
        return IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            color: iconColor,
            size: size,
          ),
          onPressed: () => _handlePress(context),
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
          splashRadius: 20,
        );

      case BackButtonVariant.circle:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handlePress(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
          ),
        );

      case BackButtonVariant.squircle:
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handlePress(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: iconColor,
                size: 22,
              ),
            ),
          ),
        );
    }
  }
}
