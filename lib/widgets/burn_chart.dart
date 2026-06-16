import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class BurnChart extends StatefulWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;

  const BurnChart({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
  });

  @override
  State<BurnChart> createState() => _BurnChartState();
}

class _BurnChartState extends State<BurnChart> with SingleTickerProviderStateMixin {
  int? _hoveredIndex;

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Calculate daily completion rate (0.0 to 1.0)
  double _calculateDailyCompletion(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    if (widget.activity.trackingType == 'single') {
      final dayCheckIns = widget.checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
      return dayCheckIns.isNotEmpty ? 1.0 : 0.0;
    } else if (widget.activity.trackingType == 'multiple') {
      final task = widget.tasks.firstWhere(
        (t) => _isSameDay(t.timestamp, day),
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
      );
      if (task.id.isEmpty) {
        final dayCheckIns = widget.checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
        if (dayCheckIns.isEmpty) return 0.0;
        final totalTemplates = widget.activity.subTaskTemplates.length;
        if (totalTemplates == 0) return 0.0;
        return (dayCheckIns.length / totalTemplates).clamp(0.0, 1.0);
      }
      if (task.subTasks.isEmpty) {
        return task.checked ? 1.0 : 0.0;
      }
      final checkedCount = task.subTasks.where((st) => st.checked).length;
      return (checkedCount / task.subTasks.length).clamp(0.0, 1.0);
    } else if (widget.activity.trackingType == 'milestone') {
      final milestoneTasks = widget.tasks.where((t) {
        final taskDay = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
        return !taskDay.isAfter(day);
      }).toList();

      if (milestoneTasks.isEmpty) return 0.0;

      double totalProgress = 0.0;
      for (var t in milestoneTasks) {
        if (t.subTasks.isEmpty) {
          totalProgress += t.checked ? 1.0 : 0.0;
        } else {
          final completed = t.subTasks.where((st) => st.checked).length;
          totalProgress += (completed / t.subTasks.length);
        }
      }
      return (totalProgress / milestoneTasks.length).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  // Check if a day is scheduled
  bool _isScheduledDay(DateTime date) {
    if (widget.activity.startDate != null) {
      final start = DateTime(widget.activity.startDate!.year, widget.activity.startDate!.month, widget.activity.startDate!.day);
      if (date.isBefore(start)) return false;
    }
    if (widget.activity.endDate != null) {
      final end = DateTime(widget.activity.endDate!.year, widget.activity.endDate!.month, widget.activity.endDate!.day);
      if (date.isAfter(end)) return false;
    }
    final repeatDays = widget.activity.repeatDays;
    if (repeatDays.isEmpty) return true;
    return repeatDays.contains(date.weekday);
  }

  // Check if a day was skipped
  bool _isDaySkipped(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final hasSkipCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, day) && c.skipped);
    if (hasSkipCheckIn) return true;
    
    if (widget.activity.skippable && _isScheduledDay(day)) {
      final hasAnyCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, day) && c.checked);
      if (!hasAnyCheckIn) {
        if (widget.activity.trackingType == 'multiple') {
          final task = widget.tasks.any((t) => _isSameDay(t.timestamp, day) && (t.checked || t.subTasks.any((st) => st.checked)));
          return !task;
        }
        return true;
      }
    }
    return false;
  }

  // Calculate current active streak
  int _calculateStreak() {
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool todayCompletedOrSkipped = false;
    if (!_isScheduledDay(today)) {
      todayCompletedOrSkipped = true;
    } else {
      final completion = _calculateDailyCompletion(today);
      final isCompleted = completion >= 0.99;
      final isSkipped = _isDaySkipped(today);
      if (isCompleted || isSkipped) {
        todayCompletedOrSkipped = true;
        if (isCompleted && !isSkipped) {
          streak = 1;
        }
      }
    }

    DateTime checkDate = today.subtract(const Duration(days: 1));
    for (int i = 1; i < 365; i++) {
      final day = DateTime(checkDate.year, checkDate.month, checkDate.day);
      if (!_isScheduledDay(day)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final completion = _calculateDailyCompletion(day);
      final isCompleted = completion >= 0.99;
      final isSkipped = _isDaySkipped(day);

      if (isCompleted) {
        streak++;
      } else if (isSkipped) {
        // preserve
      } else {
        if (i == 1 && !todayCompletedOrSkipped) {
          return 0;
        }
        break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Widget _buildRedesignedStat({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = widget.activity.trackingType == 'multiple'
        ? AppTheme.secondaryColor
        : (widget.activity.trackingType == 'milestone' ? AppTheme.warningColor : AppTheme.primaryColor);

    // 1. Generate last 7 days
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });

    // 2. Fetch daily completions (rates from 0.0 to 1.0)
    final List<double> completionRates = last7Days.map((d) => _calculateDailyCompletion(d)).toList();
    final double averageCompletion = completionRates.reduce((a, b) => a + b) / 7.0;
    final int currentStreak = _calculateStreak();

    // Determine the "Best Day"
    int bestDayIndex = 0;
    double maxCompletion = -1.0;
    for (int i = 0; i < 7; i++) {
      if (completionRates[i] > maxCompletion) {
        maxCompletion = completionRates[i];
        bestDayIndex = i;
      }
    }
    final String bestDayLabel = DateFormat('EEEE').format(last7Days[bestDayIndex]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.08),
            AppTheme.surfaceColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: typeColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '7-Day Progress Chart',
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const VGapLg(),

          // Chart Display
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
              const chartHeight = 140.0;
              final double stepX = chartWidth / 6;

              return SizedBox(
                width: chartWidth,
                height: chartHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final double localX = details.localPosition.dx;
                    setState(() {
                      _hoveredIndex = (localX / stepX).round().clamp(0, 6);
                    });
                  },
                  onPanDown: (details) {
                    final double localX = details.localPosition.dx;
                    setState(() {
                      _hoveredIndex = (localX / stepX).round().clamp(0, 6);
                    });
                  },
                  onTapDown: (details) {
                    final double localX = details.localPosition.dx;
                    setState(() {
                      _hoveredIndex = (localX / stepX).round().clamp(0, 6);
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _hoveredIndex = null;
                    });
                  },
                  onTapUp: (_) {
                    setState(() {
                      _hoveredIndex = null;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(chartWidth, chartHeight),
                        painter: BurnChartPainter(
                          completionRates: completionRates,
                          primaryColor: typeColor,
                        ),
                      ),

                      // Hover tooltip
                      if (_hoveredIndex != null)
                        Positioned(
                          left: math.min(
                            chartWidth - 140,
                            math.max(10, (_hoveredIndex! * stepX) - 70),
                          ),
                          top: -24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: typeColor.withValues(alpha: 0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.shadowColor(context),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '${DateFormat('MMM d').format(last7Days[_hoveredIndex!])}: '
                              '${(completionRates[_hoveredIndex!] * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const VGapMd(),

          // X Axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = last7Days[index];
              final label = DateFormat('E').format(date).substring(0, 1);
              final isToday = index == 6;

              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isToday
                          ? typeColor
                          : AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ),
          const VGapLg(),

          // Legend
          Row(
            children: [
              _buildLegendItem(
                color: Colors.white38,
                label: 'Target line',
                isDashed: true,
              ),
              const SizedBox(width: 12),
              _buildLegendItem(
                color: typeColor,
                label: 'Completed',
                isDashed: false,
              ),
            ],
          ),
          const VGapLg(),

          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Streak Stat
                _buildRedesignedStat(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orangeAccent,
                  bgColor: Colors.orange.withValues(alpha: 0.1),
                  label: 'Active Streak',
                  value: currentStreak == 1 ? '1 Day' : '$currentStreak Days',
                ),
                
                // Divider
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                
                // Weekly Rate Stat
                _buildRedesignedStat(
                  icon: Icons.check_circle_rounded,
                  iconColor: typeColor,
                  bgColor: typeColor.withValues(alpha: 0.1),
                  label: 'Weekly Avg',
                  value: '${(averageCompletion * 100).toStringAsFixed(0)}%',
                ),
                
                // Divider (only if best day is shown)
                if (maxCompletion > 0.01) ...[
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  
                  // Best Day Stat
                  _buildRedesignedStat(
                    icon: Icons.star_rounded,
                    iconColor: AppTheme.successColor,
                    bgColor: AppTheme.successColor.withValues(alpha: 0.1),
                    label: 'Best Day',
                    value: bestDayLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
  }) {
    return Row(
      children: [
        if (isDashed)
          Row(
            children: List.generate(3, (index) => Container(
              width: 4,
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: color,
            )),
          )
        else
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class BurnChartPainter extends CustomPainter {
  final List<double> completionRates;
  final Color primaryColor;

  BurnChartPainter({
    required this.completionRates,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (completionRates.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double stepX = width / 6;

    final double topLimit = height * 0.15;
    final double bottomLimit = height * 0.85;
    final double heightRange = bottomLimit - topLimit;

    // Draw horizontal grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 3; i++) {
      final double y = bottomLimit - (i * heightRange / 3);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Convert data to screen coordinates
    final List<Offset> points = List.generate(completionRates.length, (i) {
      final double x = i * stepX;
      final double y = bottomLimit - (completionRates[i] * heightRange);
      return Offset(x, y);
    });

    // Draw target line at 100% (dashed)
    final Paint targetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Path targetPath = Path();
    targetPath.moveTo(0, topLimit);
    targetPath.lineTo(width, topLimit);
    _drawDashedPath(canvas, targetPath, targetPaint);

    // Draw completed line (glowing curve)
    final Paint linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      final midY = (prev.dy + current.dy) / 2;
      if (i == 1) {
        linePath.lineTo(midX, midY);
      } else {
        linePath.quadraticBezierTo(prev.dx, prev.dy, midX, midY);
      }
      if (i == points.length - 1) {
        linePath.lineTo(current.dx, current.dy);
      }
    }

    // Draw shadow/glow under completed line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.25)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Draw main line path
    canvas.drawPath(linePath, linePaint);

    // Fill area below completed line
    final Path fillPath = Path.from(linePath);
    fillPath.lineTo(width, bottomLimit);
    fillPath.lineTo(0, bottomLimit);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withValues(alpha: 0.15),
        primaryColor.withValues(alpha: 0.0),
      ],
    );

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = gradient.createShader(Rect.fromLTRB(0, topLimit, width, bottomLimit))
        ..style = PaintingStyle.fill,
    );

    // Draw data points/dots
    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, dotPaint);
      canvas.drawCircle(points[i], 4.5, borderPaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    
    final List<PathMetric> metrics = path.computeMetrics().toList();
    for (final PathMetric metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = math.min(dashWidth, metric.length - distance);
        final Path extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant BurnChartPainter oldDelegate) {
    return oldDelegate.completionRates != completionRates ||
        oldDelegate.primaryColor != primaryColor;
  }
}
