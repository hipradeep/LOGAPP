import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class AppTitleInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final IconData icon;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const AppTitleInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hintText,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
    this.trailing,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;
    final isDenseField = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            ?trailingWidget,
          ],
        ),
        const VGapSm(),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          onChanged: onChanged,
          style: isDenseField
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                )
              : Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
          keyboardType:
              keyboardType ??
              (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: isDenseField
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMutedColor(context),
                  )
                : Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.w400,
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: false,
            fillColor: Colors.transparent,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
                width: 1.2,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.borderColor(context),
                width: 1.2,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: isDenseField ? 20 : 24,
              ),
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: isDenseField ? 32 : 36,
              minHeight: isDenseField ? 32 : 36,
            ),
          ),
        ),
      ],
    );
  }
}
