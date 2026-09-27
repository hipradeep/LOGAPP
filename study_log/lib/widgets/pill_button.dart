import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Modern dark pill button matching the button in the reference image (e.g., "Get started ->")
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;

  const PillButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.isFullWidth = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else ...[
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textOnDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (icon != null) ...[
            const HGapSm(),
            Icon(
              icon,
              size: 18,
              color: AppTheme.textOnDark,
            ),
          ],
        ],
      ],
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: AppTheme.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textOnDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: buttonContent,
      ),
    );
  }
}
