import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassModalSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  const GlassModalSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.defaultBorderRadius * 1.5),
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.borderColor(context),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
