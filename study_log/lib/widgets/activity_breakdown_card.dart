import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../controllers/progress_controller.dart';

/// Activity Breakdown Card: Weekly study vs revision distribution
class WeeklyProgressActivity {
  final DateTime startDate;
  final DateTime endDate;
  final int topicsFinished;
  final int revisionsDone;
  final bool isCurrentWeek;

  const WeeklyProgressActivity({
    required this.startDate,
    required this.endDate,
    required this.topicsFinished,
    required this.revisionsDone,
    required this.isCurrentWeek,
  });

  int get totalActivity => topicsFinished + revisionsDone;
}

class ActivityBreakdownCard extends StatelessWidget {
  final ProgressController controller;

  const ActivityBreakdownCard({super.key, required this.controller});

  List<WeeklyProgressActivity> _getWeeklyActivities(List<DailyProgressActivity> allActivities) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    final Map<DateTime, DailyProgressActivity> map = {};
    for (final a in allActivities) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      map[d] = a;
    }

    const int weekCount = 7;
    final List<WeeklyProgressActivity> weeks = [];

    for (int i = weekCount - 1; i >= 0; i--) {
      final weekStart = currentMonday.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrent = i == 0;

      int finished = 0;
      int revisions = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        // Only count days up to today if current week
        if (isCurrent && day.isAfter(today)) break;

        final act = map[day];
        if (act != null) {
          finished += act.topicsFinished;
          revisions += act.revisionsDone;
        }
      }

      weeks.add(WeeklyProgressActivity(
        startDate: weekStart,
        endDate: weekEnd,
        topicsFinished: finished,
        revisionsDone: revisions,
        isCurrentWeek: isCurrent,
      ));
    }

    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyActivities = _getWeeklyActivities(controller.activitiesInRange);

    int finishedTotal = 0;
    int revisionsTotal = 0;
    for (final w in weeklyActivities) {
      finishedTotal += w.topicsFinished;
      revisionsTotal += w.revisionsDone;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Weekly • Last 7 Weeks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BreakdownLegendIndicator(
                    color: const Color(0xFF10B981),
                    label: 'Finished ($finishedTotal)',
                  ),
                  const HGapSm(),
                  _BreakdownLegendIndicator(
                    color: const Color(0xFF7A6EFC),
                    label: 'Revised ($revisionsTotal)',
                  ),
                ],
              ),
            ],
          ),
          const VGapMd(),
          RepaintBoundary(
            child: SizedBox(
              height: 145,
              width: double.infinity,
              child: CustomPaint(
                painter: _ActivityBreakdownPainter(
                  activities: weeklyActivities,
                  gridColor: AppTheme.borderColor(context),
                  textColor: AppTheme.textSecondaryColor(context),
                  primaryColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _BreakdownLegendIndicator({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const HGapXs(),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}

class _ActivityBreakdownPainter extends CustomPainter {
  final List<WeeklyProgressActivity> activities;
  final Color gridColor;
  final Color textColor;
  final Color primaryColor;

  _ActivityBreakdownPainter({
    required this.activities,
    required this.gridColor,
    required this.textColor,
    required this.primaryColor,
  });

  static final DateFormat _dayFormat = DateFormat('d MMM');

  @override
  void paint(Canvas canvas, Size size) {
    if (activities.isEmpty) return;

    const double leftPadding = 20.0;
    const double bottomPadding = 28.0;
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;

    // Determine max value for Y-axis scale based on weekly activity
    int maxVal = 0;
    for (final a in activities) {
      if (a.totalActivity > maxVal) maxVal = a.totalActivity;
    }

    final int topY;
    final int stepCount;
    if (maxVal <= 0) {
      topY = 10;
      stepCount = 2;
    } else if (maxVal <= 10) {
      topY = 10;
      stepCount = 2;
    } else if (maxVal <= 20) {
      topY = 20;
      stepCount = 2;
    } else {
      topY = ((maxVal + 9) ~/ 10) * 10;
      stepCount = 3;
    }

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw Y-axis reference lines & labels
    for (int i = 0; i <= stepCount; i++) {
      final val = (topY / stepCount * i).round();
      final y = chartHeight - (chartHeight / stepCount * i);

      // Dashed horizontal line
      _drawDashedLine(canvas, Offset(leftPadding, y), Offset(size.width, y), gridPaint);

      // Y-axis label
      textPainter.text = TextSpan(
        text: '$val',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Draw 7 Weekly Bars
    final int count = activities.length;
    final double slotWidth = chartWidth / count;
    final double barWidth = (slotWidth * 0.45).clamp(12.0, 20.0);

    final Paint emptyTrackPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final Paint finishedPaint = Paint()..color = const Color(0xFF10B981);
    final Paint revisionPaint = Paint()..color = const Color(0xFF7A6EFC);
    final Paint todayDotPaint = Paint()..color = primaryColor;

    for (int i = 0; i < count; i++) {
      final act = activities[i];
      final double x = leftPadding + (i * slotWidth) + (slotWidth - barWidth) / 2;

      // Background subtle slot track
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(trackRect, emptyTrackPaint);

      final double finishedHeight = (act.topicsFinished / topY) * chartHeight;
      final double revisionHeight = (act.revisionsDone / topY) * chartHeight;
      final double totalHeight = (finishedHeight + revisionHeight).clamp(0.0, chartHeight);

      if (totalHeight > 0) {
        final double baseY = chartHeight;

        // Bottom green segment (Topics Finished)
        if (finishedHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - finishedHeight,
            barWidth,
            finishedHeight,
          );
          if (revisionHeight <= 0) {
            final rrect = RRect.fromRectAndRadius(
              rect,
              const Radius.circular(4),
            );
            canvas.drawRRect(rrect, finishedPaint);
          } else {
            final rrect = RRect.fromRectAndCorners(
              rect,
              bottomLeft: const Radius.circular(4),
              bottomRight: const Radius.circular(4),
            );
            canvas.drawRRect(rrect, finishedPaint);
          }
        }

        // Top purple segment (Topic Revisions)
        if (revisionHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - totalHeight,
            barWidth,
            revisionHeight,
          );
          if (finishedHeight <= 0) {
            final rrect = RRect.fromRectAndRadius(
              rect,
              const Radius.circular(4),
            );
            canvas.drawRRect(rrect, revisionPaint);
          } else {
            final rrect = RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            );
            canvas.drawRRect(rrect, revisionPaint);
          }
        }
      }

      // X-axis label
      final String label = act.isCurrentWeek ? 'This Wk' : _dayFormat.format(act.startDate);
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: -0.2,
          fontWeight: act.isCurrentWeek ? FontWeight.bold : FontWeight.w500,
          color: act.isCurrentWeek ? primaryColor : textColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, chartHeight + 6),
      );

      // Indicator dot for current week
      if (act.isCurrentWeek) {
        canvas.drawCircle(
          Offset(x + barWidth / 2, chartHeight + 21),
          2.0,
          todayDotPaint,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 4.0;
    const double dashSpace = 4.0;
    double currentX = start.dx;
    while (currentX < end.dx) {
      canvas.drawLine(
        Offset(currentX, start.dy),
        Offset((currentX + dashWidth).clamp(start.dx, end.dx), start.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityBreakdownPainter oldDelegate) {
    return oldDelegate.activities != activities ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.primaryColor != primaryColor;
  }
}
