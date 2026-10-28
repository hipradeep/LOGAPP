import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// A minimalist, reusable action button component supporting single primary button
/// or dual action buttons (Secondary Outline + Primary Filled).
class AppActionButtons extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final String? cancelLabel;
  final VoidCallback? onCancelPressed;
  final bool isPrimaryLoading;
  final bool isSecondaryLoading;
  final Color? primaryColor;
  final Color? secondaryColor;
  final int primaryFlex;
  final int secondaryFlex;
  final double height;

  const AppActionButtons({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.cancelLabel,
    this.onCancelPressed,
    this.isPrimaryLoading = false,
    this.isSecondaryLoading = false,
    this.primaryColor,
    this.secondaryColor,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.height = AppTheme.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final actualPrimaryColor = primaryColor ?? AppTheme.primaryColor;
    final secLabel = secondaryLabel ?? cancelLabel;
    final secPressed = onSecondaryPressed ?? onCancelPressed;
    final secColor =
        secondaryColor ??
        (cancelLabel != null
            ? AppTheme.textSecondaryColor(context)
            : AppTheme.errorColor);
    final hasSecondary =
        secPressed != null && secLabel != null && secLabel.isNotEmpty;

    final primaryBtn = FilledButton(
      onPressed: (isPrimaryLoading || isSecondaryLoading)
          ? null
          : onPrimaryPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        backgroundColor: actualPrimaryColor,
        foregroundColor: AppTheme.textOnDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
        ),
        elevation: 0,
      ),
      child: isPrimaryLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              primaryLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
    );

    if (!hasSecondary) {
      return primaryBtn;
    }

    return Row(
      children: [
        // Secondary Button
        Expanded(
          flex: secondaryFlex,
          child: OutlinedButton(
            onPressed: (isPrimaryLoading || isSecondaryLoading)
                ? null
                : secPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height),
              foregroundColor: secColor,
              side: BorderSide(
                color: secColor.withValues(alpha: 0.4),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
              ),
            ),
            child: isSecondaryLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secColor,
                    ),
                  )
                : Text(
                    secLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: secColor,
                    ),
                  ),
          ),
        ),
        const HGapSm(),
        // Primary Button
        Expanded(flex: primaryFlex, child: primaryBtn),
      ],
    );
  }
}
