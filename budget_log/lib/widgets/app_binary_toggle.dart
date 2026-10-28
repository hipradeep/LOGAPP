import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A dual-segment capsule toggle for choosing between two states (e.g. Credit | Debit).
/// Designed with rounded pill capsule, smooth active highlight, and distinct colors.
class AppBinaryToggle extends StatelessWidget {
  /// Whether the "first" option is selected.
  /// For Credit | Debit: isCredit = true selects Credit, false selects Debit.
  final bool isFirstSelected;
  final ValueChanged<bool> onChanged;
  final String firstLabel;
  final String secondLabel;
  final Color firstActiveColor;
  final Color secondActiveColor;

  const AppBinaryToggle({
    super.key,
    required this.isFirstSelected,
    required this.onChanged,
    this.firstLabel = 'Credit',
    this.secondLabel = 'Debit',
    this.firstActiveColor = AppTheme.successColor,
    this.secondActiveColor = AppTheme.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            context: context,
            label: firstLabel,
            isSelected: isFirstSelected,
            activeColor: firstActiveColor,
            onTap: () {
              if (!isFirstSelected) onChanged(true);
            },
          ),
          const SizedBox(width: 2),
          _buildSegment(
            context: context,
            label: secondLabel,
            isSelected: !isFirstSelected,
            activeColor: secondActiveColor,
            onTap: () {
              if (isFirstSelected) onChanged(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : AppTheme.textSecondaryColor(context),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
