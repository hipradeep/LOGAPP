import 'dart:math';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

class DonutSegment {
  final String label;
  final double value;
  final Color color;

  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class ExpenseDonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double total;
  final double size;
  final double strokeWidth;
  final String centerLabel;

  const ExpenseDonutChart({
    super.key,
    required this.segments,
    required this.total,
    this.size = 140,
    this.strokeWidth = 18,
    this.centerLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              segments: segments,
              total: total,
              strokeWidth: strokeWidth,
              gapColor: AppTheme.surface(context),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.13,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'total',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: size * 0.08,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double total;
  final double strokeWidth;
  final Color gapColor;

  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.strokeWidth,
    required this.gapColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - strokeWidth / 2;
    const gapAngle = 0.03; // radians between segments

    if (total <= 0 || segments.isEmpty) {
      // Draw empty ring
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = gapColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    double startAngle = -pi / 2; // start at 12 o'clock

    for (final seg in segments) {
      final sweep = (seg.value / total) * (2 * pi) - gapAngle;
      if (sweep <= 0) continue;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.total != total;
}
