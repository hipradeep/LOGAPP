import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
class SymbolIndicator extends StatelessWidget {
  final Task task;
  final double size;
  final VoidCallback? onTap;

  const SymbolIndicator({
    super.key,
    required this.task,
    this.size = 26,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (task.symbolType == 'flag') {
      final flagColor = _getFlagColor(task.symbolValue);
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: flagColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.flag_rounded, color: flagColor, size: 16),
      );
    } else if (task.symbolType == 'number') {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Center(
          child: Text(
            task.symbolValue ?? '1',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (task.symbolType == 'progress') {
      final double progress = double.tryParse(task.symbolValue ?? '0') ?? 0;
      child = SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: PieChartPainter(
            progress: progress,
            color: AppTheme.secondaryColor,
            backgroundColor: Colors.white10,
          ),
        ),
      );
    } else if (task.symbolType == 'mood') {
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Text(
          task.symbolValue ?? '😄',
          style: const TextStyle(fontSize: 16),
        ),
      );
    } else {
      // Default fallback: draw the subtasks checklist progress pie chart if items exist
      final totalCount = task.subTasks.length;
      final completedCount = task.subTasks.where((i) => i.checked).length;
      final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
      if (totalCount > 0) {
        child = SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: PieChartPainter(
              progress: progress,
              color: AppTheme.secondaryColor,
              backgroundColor: Colors.white10,
            ),
          ),
        );
      } else {
        child = Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag_outlined, color: Colors.white30, size: 16),
        );
      }
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return child;
  }

  Color _getFlagColor(String? value) {
    switch (value) {
      case 'red':
        return Colors.redAccent;
      case 'yellow':
        return Colors.amber;
      case 'purple':
        return Colors.purpleAccent;
      case 'blue':
        return Colors.blueAccent;
      case 'green':
        return Colors.greenAccent;
      default:
        return Colors.white30;
    }
  }
}

class PieChartPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  PieChartPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2,
        progress * 2 * 3.141592653589793,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
