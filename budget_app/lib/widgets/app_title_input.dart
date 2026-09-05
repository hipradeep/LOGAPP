import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTitleInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final bool autofocus;

  const AppTitleInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Title...',
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
      style: AppTheme.headingMedium.copyWith(
        color: AppTheme.textPrimaryColor(context),
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTheme.headingMedium.copyWith(
          color: AppTheme.hintColor(context),
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
