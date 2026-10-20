import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Standard progress indicator dialog shown when initiating Google Cloud sign-in.
class GoogleSyncProgressDialog extends StatelessWidget {
  final String message;

  const GoogleSyncProgressDialog({
    super.key,
    this.message = 'Connecting to Google...',
  });

  /// Displays the dialog and returns a function to dismiss it safely.
  static void show(BuildContext context, {String message = 'Connecting to Google...'}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: GoogleSyncProgressDialog(message: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor(context),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor,
              ),
            ),
            const HGapMd(),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
