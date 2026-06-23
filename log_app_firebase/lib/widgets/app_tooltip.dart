import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppTooltip extends StatelessWidget {
  final String message;
  final Widget child;
  final TooltipTriggerMode triggerMode;
  final bool preferBelow;

  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.triggerMode = TooltipTriggerMode.longPress,
    this.preferBelow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
    final borderColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.4)
        : AppTheme.primaryColor.withValues(alpha: 0.25);

    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      triggerMode: triggerMode,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: BubbleShapeBorder(
          borderColor: borderColor,
          borderWidth: 1.0,
          arrowHeight: 5,
          arrowWidth: 8,
          borderRadius: 6,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 9), // Bottom padding includes arrowHeight
      child: child,
    );
  }
}

class AppTooltipStatic extends StatelessWidget {
  final Widget child;

  const AppTooltipStatic({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bgColor = isDark ? AppTheme.surface(context) : Colors.white;
    final borderColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.4)
        : AppTheme.primaryColor.withValues(alpha: 0.25);

    return Container(
      decoration: ShapeDecoration(
        color: bgColor,
        shape: BubbleShapeBorder(
          borderColor: borderColor,
          borderWidth: 1.0,
          arrowHeight: 5,
          arrowWidth: 8,
          borderRadius: 6,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 9),
      child: child,
    );
  }
}

class BubbleShapeBorder extends ShapeBorder {
  final double arrowHeight;
  final double arrowWidth;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;

  const BubbleShapeBorder({
    this.arrowHeight = 5,
    this.arrowWidth = 8,
    this.borderRadius = 6,
    this.borderColor = Colors.grey,
    this.borderWidth = 1.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double width = rect.width;
    final double height = rect.height;
    final double bubbleHeight = height - arrowHeight;
    final double arrowLeft = (width - arrowWidth) / 2;

    final path = Path();
    path.moveTo(borderRadius, 0);
    path.lineTo(width - borderRadius, 0);
    path.arcToPoint(Offset(width, borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(width, bubbleHeight - borderRadius);
    path.arcToPoint(Offset(width - borderRadius, bubbleHeight), radius: Radius.circular(borderRadius));
    path.lineTo(arrowLeft + arrowWidth, bubbleHeight);
    path.lineTo(width / 2, height);
    path.lineTo(arrowLeft, bubbleHeight);
    path.lineTo(borderRadius, bubbleHeight);
    path.arcToPoint(Offset(0, bubbleHeight - borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(0, borderRadius);
    path.arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius));
    path.close();

    return path.shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
