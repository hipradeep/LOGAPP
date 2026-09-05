import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBinaryToggle extends StatelessWidget {
  final String firstOption;
  final String secondOption;
  final bool isFirstSelected;
  final ValueChanged<bool> onToggle;

  const AppBinaryToggle({
    super.key,
    required this.firstOption,
    required this.secondOption,
    required this.isFirstSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isFirstSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius - 4),
                ),
                alignment: Alignment.center,
                child: Text(
                  firstOption,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: isFirstSelected ? FontWeight.bold : FontWeight.normal,
                    color: isFirstSelected ? Colors.white : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isFirstSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius - 4),
                ),
                alignment: Alignment.center,
                child: Text(
                  secondOption,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: !isFirstSelected ? FontWeight.bold : FontWeight.normal,
                    color: !isFirstSelected ? Colors.white : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
