import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTitleDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const AppTitleDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        dropdownColor: AppTheme.surfaceColor,
        isDense: true,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppTheme.primaryLight,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        icon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: AppTheme.primaryLight,
          size: 18,
        ),
      ),
    );
  }
}
