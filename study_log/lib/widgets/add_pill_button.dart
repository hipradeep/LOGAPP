import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Shared outlined pill action button for every "add" action in the app
/// (Add Course, Add Module, Add Topic) and the matching "Save" action in the
/// add screens. Keeps one consistent look across the top bars.
class AddPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const AddPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon = Icons.add_rounded,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.pastelPurple(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.pastelPurpleText(context),
                  ),
                )
              else if (icon != null)
                Icon(icon, color: AppTheme.pastelPurpleText(context), size: 16),
              const HGapXs(),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.pastelPurpleText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
