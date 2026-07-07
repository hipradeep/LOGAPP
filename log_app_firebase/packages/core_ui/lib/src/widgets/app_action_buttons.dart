import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// A premium, reusable action button component that supports both single primary button
/// and dual action buttons (Secondary Outline + Primary Elevated) side by side.
class AppActionButtons extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isPrimaryLoading;
  final bool isSecondaryLoading;
  final Color? primaryColor;
  final Color secondaryColor;
  final int primaryFlex;
  final int secondaryFlex;
  final double height;

  const AppActionButtons({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isPrimaryLoading = false,
    this.isSecondaryLoading = false,
    this.primaryColor,
    this.secondaryColor = AppTheme.errorColor,
    this.primaryFlex = 2,
    this.secondaryFlex = 1,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final actualPrimaryColor = primaryColor ?? AppTheme.primaryColor;
    final hasSecondary = onSecondaryPressed != null && secondaryLabel != null && secondaryLabel!.isNotEmpty;

    final primaryBtn = ElevatedButton(
      onPressed: (isPrimaryLoading || isSecondaryLoading) ? null : onPrimaryPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        backgroundColor: actualPrimaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: isPrimaryLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              primaryLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
    );

    if (!hasSecondary) {
      return primaryBtn;
    }

    return Row(
      children: [
        // Secondary Button (Flex 1)
        Expanded(
          flex: secondaryFlex,
          child: OutlinedButton(
            onPressed: (isPrimaryLoading || isSecondaryLoading) ? null : onSecondaryPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height),
              foregroundColor: secondaryColor,
              side: BorderSide(color: secondaryColor, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isSecondaryLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secondaryColor,
                    ),
                  )
                : Text(
                    secondaryLabel!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
        const HGapMd(),
        // Primary Button (Flex 2)
        Expanded(
          flex: primaryFlex,
          child: primaryBtn,
        ),
      ],
    );
  }
}
