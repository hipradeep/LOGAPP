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
        selectedItemBuilder: (BuildContext context) {
          return items.map<Widget>((DropdownMenuItem<T> item) {
            final child = item.child;
            if (child is Text) {
              return Text(
                child.data ?? '',
                style: TextStyle(
                  color: AppTheme.primaryAccentColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              );
            }
            return child;
          }).toList();
        },
        style: TextStyle(
          color: AppTheme.primaryAccentColor(context),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: AppTheme.primaryAccentColor(context),
          size: 18,
        ),
      ),
    );
  }
}
