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
        dropdownColor: AppTheme.surface(context),
        isDense: true,
        items: items,
        onChanged: onChanged,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.primaryLight,
        ),
      ),
    );
  }
}
