import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowBlob extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color? color;
  final double opacity;

  const GlowBlob({
    super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.size = 300,
    this.color,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (color ?? AppTheme.primaryColor).withValues(alpha: opacity),
        ),
      ),
    );
  }
}
