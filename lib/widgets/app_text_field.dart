import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hintText,
    this.onSubmitted,
    this.onTap,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      onTap: onTap,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.02),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor),
        ),
      ),
    );
  }
}
