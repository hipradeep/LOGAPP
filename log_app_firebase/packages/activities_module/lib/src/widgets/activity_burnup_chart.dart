import 'dart:math';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'package:intl/intl.dart' hide TextDirection;

class ActivityBurnupChart extends StatelessWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;
  final int daysWindow;
  final bool showTitle;

  const ActivityBurnupChart({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
    this.daysWindow = 7,
    this.showTitle = true,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Calculate cumulative scope (total milestone subtasks defined on or before 'day')
  double _calculateTotalScope(DateTime day) {
    double total = 0;
    for (var t in tasks) {
      final taskDate = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      if (taskDate.isAfter(day)) continue; // Scheduled in the future relative to this point
      
      if (t.subTasks.isEmpty) {
        total += 1;
      } else {
        total += t.subTasks.length;
      }
    }
    return total;
  }

  // Calculate cumulative completed milestones/subtasks checked on or before 'day'
  double _calculateCompletedScope(DateTime day) {
    double completed = 0;
    for (var t in tasks) {
      final taskDate = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      if (taskDate.isAfter(day)) continue; // Scheduled in the future relative to this point
      
      if (t.subTasks.isEmpty) {
        if (t.checked) {
          final compDate = t.completionTime ?? t.timestamp;
          final compDay = DateTime(compDate.year, compDate.month, compDate.day);
          if (!compDay.isAfter(day)) {
            completed += 1;
          }
        }
      } else {
        // Count subtasks completed on or before this day
        final checkedSubTasks = t.subTasks.where((st) => st.checked).toList();
        if (checkedSubTasks.isNotEmpty) {
          final compDate = t.completionTime ?? t.timestamp;
          final compDay = DateTime(compDate.year, compDate.month, compDate.day);
          if (!compDay.isAfter(day)) {
            completed += checkedSubTasks.length;
          }
        }
      }
    }
    return completed;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Register context dependency for theme rebuilds

    final typeColor = AppTheme.warningColor; // Amber for Milestones
    final totalColor = AppTheme.secondaryColor; // Slate/Blue for Scope

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate date sequence for the selected window
    final List<DateTime> dates = List.generate(daysWindow, (index) {
      final date = today.subtract(Duration(days: daysWindow - 1 - index));
      return DateTime(date.year, date.month, date.day);
    });

    // Compute cumulative data points
    final List<double> totalPoints = dates.map((d) => _calculateTotalScope(d)).toList();
    final List<double> completedPoints = dates.map((d) => _calculateCompletedScope(d)).toList();

    // Determine scale limit
    final double maxTotalScope = totalPoints.isNotEmpty ? totalPoints.reduce(max) : 0;
    final double maxVal = max(maxTotalScope, 5.0); // Default to at least 5 for scale if empty

    final chartContent = Column(
      children: [
        // Chart Canvas
        SizedBox(
          height: 140,
          child: CustomPaint(
            size: Size.infinite,
            painter: BurnupChartPainter(
              totalPoints: totalPoints,
              completedPoints: completedPoints,
              totalColor: totalColor,
              completedColor: typeColor,
              maxVal: maxVal,
              daysWindow: daysWindow,
              borderColor: AppTheme.borderColor(context),
              textColor: AppTheme.textSecondaryColor(context),
              surfaceColor: AppTheme.surface(context),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // X-Axis Date Labels Row
        if (daysWindow == 7)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = dates[index];
              final isToday = _isSameDay(date, now);
              final label = DateFormat('E').format(date).substring(0, 1);

              return Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: isToday
                        ? BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          )
                        : null,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isToday
                            ? AppTheme.textPrimaryColor(context)
                            : AppTheme.textSecondaryColor(context),
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          )
        else
          // 30 Days window timeline labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(dates.first),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(dates[15]),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 12),

        // Custom Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Total Scope legend indicator
            _buildLegendItem(
              context: context,
              label: 'Total Scope',
              color: totalColor,
              isDashed: false,
            ),
            const SizedBox(width: 20),
            // Completed tasks legend indicator
            _buildLegendItem(
              context: context,
              label: 'Completed Tasks',
              color: typeColor,
              isDashed: false,
            ),
          ],
        ),
      ],
    );

    if (!showTitle) {
      return chartContent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.12),
            AppTheme.surface(context).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: typeColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Milestone Burnup',
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          chartContent,
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required String label,
    required Color color,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 4),
        // Small Diamond Node Representation
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class BurnupChartPainter extends CustomPainter {
  final List<double> totalPoints;
  final List<double> completedPoints;
  final Color totalColor;
  final Color completedColor;
  final double maxVal;
  final int daysWindow;
  final Color borderColor;
  final Color textColor;
  final Color surfaceColor;

  BurnupChartPainter({
    required this.totalPoints,
    required this.completedPoints,
    required this.totalColor,
    required this.completedColor,
    required this.maxVal,
    required this.daysWindow,
    required this.borderColor,
    required this.textColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalPoints.isEmpty) return;

    // Y Axis Offset for Labels
    const double xOffset = 24.0;
    final double width = size.width;
    final double height = size.height;
    
    // Bounds for drawing
    final double topLimit = height * 0.15;
    final double bottomLimit = height * 0.9;
    final double usableHeight = bottomLimit - topLimit;
    final double usableWidth = width - xOffset;

    final double widthBetweenPoints = usableWidth / (totalPoints.length - 1);

    // Draw Grid Lines (Horizontal grid lines)
    final Paint gridPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const int gridLineCount = 4;
    for (int i = 0; i < gridLineCount; i++) {
      final double y = bottomLimit - (i / (gridLineCount - 1)) * usableHeight;
      canvas.drawLine(Offset(xOffset, y), Offset(width, y), gridPaint);

      // Draw Y-Axis Labels
      final labelVal = ((i / (gridLineCount - 1)) * maxVal).round();
      _drawText(
        canvas: canvas,
        text: '$labelVal',
        x: xOffset - 6,
        y: y,
        color: textColor.withValues(alpha: 0.6),
        alignRight: true,
      );
    }

    // Map points to offsets
    final List<Offset> totalOffsets = [];
    final List<Offset> completedOffsets = [];

    for (int i = 0; i < totalPoints.length; i++) {
      final double x = xOffset + i * widthBetweenPoints;
      final double yTotal = bottomLimit - (totalPoints[i] / maxVal) * usableHeight;
      final double yCompleted = bottomLimit - (completedPoints[i] / maxVal) * usableHeight;

      totalOffsets.add(Offset(x, yTotal));
      completedOffsets.add(Offset(x, yCompleted));
    }

    // 1. Draw Completed Line Gradient Fill
    if (completedOffsets.isNotEmpty) {
      final Path areaPath = Path();
      areaPath.moveTo(xOffset, bottomLimit);
      areaPath.lineTo(completedOffsets[0].dx, completedOffsets[0].dy);
      
      for (int i = 1; i < completedOffsets.length; i++) {
        areaPath.lineTo(completedOffsets[i].dx, completedOffsets[i].dy);
      }
      
      areaPath.lineTo(width, bottomLimit);
      areaPath.close();

      final Paint areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            completedColor.withValues(alpha: 0.18),
            completedColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(xOffset, topLimit, width, bottomLimit))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);
    }

    // 2. Draw Total Scope Line (Blue/Slate)
    if (totalOffsets.isNotEmpty) {
      final Paint linePaint = Paint()
        ..color = totalColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final Path path = Path();
      path.moveTo(totalOffsets[0].dx, totalOffsets[0].dy);
      for (int i = 1; i < totalOffsets.length; i++) {
        path.lineTo(totalOffsets[i].dx, totalOffsets[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // 3. Draw Completed Line (Glowing Amber)
    if (completedOffsets.isNotEmpty) {
      final Paint glowPaint = Paint()
        ..color = completedColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final Paint linePaint = Paint()
        ..color = completedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final Path path = Path();
      path.moveTo(completedOffsets[0].dx, completedOffsets[0].dy);
      for (int i = 1; i < completedOffsets.length; i++) {
        path.lineTo(completedOffsets[i].dx, completedOffsets[i].dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    // 4. Draw Diamonds on Total Scope Line
    final Paint diamondFillPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;

    final Paint totalStrokePaint = Paint()
      ..color = totalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var offset in totalOffsets) {
      _drawDiamond(canvas, offset, 4.0, diamondFillPaint, totalStrokePaint);
    }

    // 5. Draw Diamonds on Completed Line
    final Paint completedStrokePaint = Paint()
      ..color = completedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var offset in completedOffsets) {
      _drawDiamond(canvas, offset, 4.5, diamondFillPaint, completedStrokePaint);
    }

    // 6. Draw Numeric Labels on Completed Line Points
    for (int i = 0; i < completedPoints.length; i++) {
      bool shouldDraw = false;
      if (daysWindow <= 10) {
        shouldDraw = true;
      } else {
        // Draw on endpoints, and intermediate points where scope changes
        if (i == 0 || i == completedPoints.length - 1) {
          shouldDraw = true;
        } else if (completedPoints[i] != completedPoints[i - 1]) {
          shouldDraw = true;
        }
      }

      if (shouldDraw) {
        final valText = '${completedPoints[i].round()}';
        final offset = completedOffsets[i];
        
        // Render number slightly above diamond
        _drawText(
          canvas: canvas,
          text: valText,
          x: offset.dx,
          y: offset.dy - 12.0,
          color: completedColor,
          center: true,
        );
      }
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint fillPaint, Paint strokePaint) {
    final Path path = Path();
    path.moveTo(center.dx, center.dy - size); // Top
    path.lineTo(center.dx + size, center.dy); // Right
    path.lineTo(center.dx, center.dy + size); // Bottom
    path.lineTo(center.dx - size, center.dy); // Left
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required Color color,
    bool alignRight = false,
    bool center = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double drawX = x;
    if (alignRight) {
      drawX = x - textPainter.width;
    } else if (center) {
      drawX = x - textPainter.width / 2;
    }

    final double drawY = y - textPainter.height / 2;
    textPainter.paint(canvas, Offset(drawX, drawY));
  }

  @override
  bool shouldRepaint(covariant BurnupChartPainter oldDelegate) {
    return oldDelegate.totalPoints != totalPoints ||
        oldDelegate.completedPoints != completedPoints ||
        oldDelegate.totalColor != totalColor ||
        oldDelegate.completedColor != completedColor ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.textColor != textColor ||
        oldDelegate.borderColor != borderColor;
  }
}
