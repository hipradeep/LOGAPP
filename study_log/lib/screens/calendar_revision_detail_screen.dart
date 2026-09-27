import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import '../controllers/calendar_controller.dart';
import '../services/service_locator.dart';
import '../widgets/app_spacers.dart';
import '../widgets/calendar/revision_completion_dialog.dart';
import '../widgets/calendar/revision_progress_sheet.dart';

/// Screen 7: Revision Detail (from Calendar)
/// View details and mark revision as completed.
class CalendarRevisionDetailScreen extends StatefulWidget {
  final CalendarEvent event;

  const CalendarRevisionDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<CalendarRevisionDetailScreen> createState() => _CalendarRevisionDetailScreenState();
}

class _CalendarRevisionDetailScreenState extends State<CalendarRevisionDetailScreen> {
  late CalendarEvent _event;
  bool _isMarking = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openProgress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionProgressScreen(event: _event),
      ),
    );
  }

  Future<void> _handleMarkCompleted() async {
    setState(() => _isMarking = true);
    final controller = getIt<CalendarController>();
    await controller.markRevisionCompleted(_event.revisionId);
    if (!mounted) return;
    setState(() {
      _isMarking = false;
      _event = _event.copyWith(isCompleted: true, completedAt: DateTime.now());
    });

    // Show celebration dialog (Screen 8)
    RevisionCompletionDialog.show(
      context,
      event: _event,
      onViewInCalendar: () {
        Navigator.of(context).pop(); // Back to Calendar
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final isToday = _isSameDay(_event.date, DateTime.now());
    final dateLabel = '${_dateFormat.format(_event.date)}${isToday ? ' (Today)' : ''}';

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                    onPressed: _handleBack,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: AppTheme.textPrimaryColor(context), size: 24),
                    onSelected: (val) {
                      if (val == 'progress') _openProgress();
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: AppTheme.surface(context),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'progress',
                        child: Row(
                          children: [
                            Icon(Icons.timeline_rounded, color: AppTheme.textPrimaryColor(context), size: 20),
                            HGapMd(),
                            Text('View Progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic Title
                    Text(
                      _event.topicTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const VGapSm(),
                    // Badges row: [ R1 ]  DSA → Arrays
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _event.bgTint(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _event.color(context).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _event.levelLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _event.color(context),
                            ),
                          ),
                        ),
                        const HGapSm(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _event.breadcrumb,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const VGapXl(),
                    // Scheduled Date Card
                    _DetailFieldCard(
                      icon: Icons.calendar_today_rounded,
                      title: 'Scheduled Date',
                      value: dateLabel,
                    ),
                    const VGapMd(),
                    // Scheduled Time Card
                    _DetailFieldCard(
                      icon: Icons.access_time_rounded,
                      title: 'Scheduled Time',
                      value: _event.time,
                    ),
                    const VGapMd(),
                    // Notes Card
                    _DetailFieldCard(
                      icon: Icons.notes_rounded,
                      title: 'Notes',
                      value: _event.notes.isNotEmpty
                          ? _event.notes
                          : 'Revise core concepts, time complexity and code templates.',
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action Button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomSafe + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _event.isCompleted || _isMarking ? null : _handleMarkCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _event.isCompleted
                        ?  AppTheme.successColor
                        : AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isMarking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _event.isCompleted ? 'Completed' : 'Mark as Completed',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DetailFieldCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailFieldCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapXs(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
