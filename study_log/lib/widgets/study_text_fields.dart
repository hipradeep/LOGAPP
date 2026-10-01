import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable clean unrounded input with bottom bar on focus.
/// Features:
/// - Clean label with optional required red asterisk
/// - Larger text size with modern semi-bold weight
/// - Subtle bottom border that highlights to primaryColor on focus
/// - Optional suffix icon (e.g. stepper or clear icon)
class UnderlineInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isRequired;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final double fontSize;
  final FontWeight fontWeight;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int? maxLines;

  const UnderlineInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.fontSize = 18.0,
    this.fontWeight = FontWeight.w600,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRequired)
          RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
              children: [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        const VGapSm(),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: AppTheme.textPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              color: AppTheme.textMutedColor(context),
            ),
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable borderless description field.
/// Features:
/// - Flat unrounded surface with no borders
/// - Clean multiline text editing with larger readable font
/// - Real-time surgical character counter (e.g. 0/500) via [ListenableBuilder]
class BorderlessDescriptionField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final int maxLength;
  final int maxLines;
  final double fontSize;
  final ValueChanged<String>? onChanged;

  const BorderlessDescriptionField({
    super.key,
    this.label = 'Description (Optional)',
    required this.controller,
    this.hintText = 'Enter description',
    this.maxLength = 500,
    this.maxLines = 4,
    this.fontSize = 15.0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Container(
          color: AppTheme.surface(context),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: controller,
                maxLines: maxLines,
                maxLength: maxLength,
                onChanged: onChanged,
                style: TextStyle(
                  fontSize: fontSize,
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.normal,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: fontSize,
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const VGapXs(),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return Text(
                    '${controller.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
