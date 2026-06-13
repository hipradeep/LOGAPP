import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class AppTitleInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final IconData icon;

  const AppTitleInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hintText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const VGapSm(),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          keyboardType: TextInputType.text,
          maxLines: 1,
          textInputAction: TextInputAction.next,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.outfit(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: false,
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10, width: 1.5),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10, width: 1.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                icon,
                color: AppTheme.primaryLight,
                size: 28,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
      ],
    );
  }
}
