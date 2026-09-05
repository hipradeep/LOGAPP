import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class AppActionButtons extends StatelessWidget {
  final String primaryLabel;
  final String cancelLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onCancelPressed;
  final bool isPrimaryLoading;

  const AppActionButtons({
    super.key,
    this.primaryLabel = 'Save',
    this.cancelLabel = 'Cancel',
    required this.onPrimaryPressed,
    required this.onCancelPressed,
    this.isPrimaryLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancelPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.borderColor(context)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
            child: Text(
              cancelLabel,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const HGapMd(),
        Expanded(
          child: ElevatedButton(
            onPressed: isPrimaryLoading ? null : onPrimaryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
            child: isPrimaryLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    primaryLabel,
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
