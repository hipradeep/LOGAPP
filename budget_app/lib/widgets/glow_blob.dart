import 'package:flutter/material.dart';

class GlowBlob extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;
  final double opacity;

  const GlowBlob({
    super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.size = 200,
    required this.color,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: opacity),
                  blurRadius: size * 0.6,
                  spreadRadius: size * 0.2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
