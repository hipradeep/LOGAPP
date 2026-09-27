import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../models/revision.dart';
import '../../theme/app_theme.dart';
import '../app_spacers.dart';

/// Screen 10: Revision Progress (R1–R5 Spaced Repetition Stepper)
class RevisionProgressScreen extends StatelessWidget {
  final CalendarEvent event;

  const RevisionProgressScreen({
    super.key,
    required this.event,
  });

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Breadcrumb
              Text(
                event.topicTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.4,
                ),
              ),
              const VGapXs(),
              Text(
                event.breadcrumb,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const VGapXl(),
              // Stepper Timeline
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: List.generate(5, (index) {
                    final level = index + 1;
                    final isCompleted = level < event.level || (level == event.level && event.isCompleted);
                    final isCurrent = level == event.level && !event.isCompleted;

                    final intervalText = RevisionSchedule.intervalLabel(level);
                    final targetDate = event.date.add(RevisionSchedule.intervalFor(level));

                    return _TimelineStep(
                      level: level,
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      dateText: _dateFormat.format(targetDate),
                      intervalText: intervalText,
                      isLast: level == 5,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final int level;
  final bool isCompleted;
  final bool isCurrent;
  final String dateText;
  final String intervalText;
  final bool isLast;

  const _TimelineStep({
    required this.level,
    required this.isCompleted,
    required this.isCurrent,
    required this.dateText,
    required this.intervalText,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Indicator Column
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? const Color(0xFF5B4DFB)
                          : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : isCurrent
                        ? const Icon(Icons.sync_rounded, color: Colors.white, size: 16)
                        : Text(
                            '$level',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const HGapMd(),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'R$level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const HGapMd(),
                    Text(
                      isCompleted ? 'Completed' : 'Upcoming',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? const Color(0xFF10B981) : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isCompleted ? dateText : '$dateText ($intervalText)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
