import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import '../controllers/calendar_controller.dart';
import '../services/service_locator.dart';
import '../widgets/app_spacers.dart';
import 'calendar_revision_detail_screen.dart';

/// Screen 6: Calendar Date Detail
/// Detailed checklist of scheduled revisions for a specific day.
class CalendarDateDetailScreen extends StatelessWidget {
  final DateTime date;

  const CalendarDateDetailScreen({
    super.key,
    required this.date,
  });

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  void _handleBack(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _openDetail(BuildContext context, CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarRevisionDetailScreen(event: event),
      ),
    );
  }

  Future<void> _toggleComplete(BuildContext context, CalendarEvent event) async {
    if (event.isCompleted) return;
    final controller = getIt<CalendarController>();
    await controller.markRevisionCompleted(event.revisionId);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final controller = getIt<CalendarController>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                    onPressed: () => _handleBack(context),
                  ),
                  const HGapXs(),
                  Text(
                    _dateFormat.format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 22),
                    onPressed: () {
                      controller.jumpToToday();
                      _handleBack(context);
                    },
                  ),
                ],
              ),
            ),
            // Subtitle
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final events = controller.eventsForDate(date);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Text(
                    '${events.length} ${events.length == 1 ? 'item' : 'items'} scheduled',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                );
              },
            ),
            const VGapSm(),
            // Checklist items
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final events = controller.eventsForDate(date);

                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        'No items scheduled for this date.',
                        style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 14),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 24),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const VGapSm(),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _DateChecklistItem(
                        event: event,
                        onTap: () => _openDetail(context, event),
                        onCheckTap: () => _toggleComplete(context, event),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChecklistItem extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onCheckTap;

  const _DateChecklistItem({
    required this.event,
    required this.onTap,
    required this.onCheckTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Checkbox indicator
              GestureDetector(
                onTap: onCheckTap,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.isCompleted ?  AppTheme.successColor : Colors.transparent,
                    border: Border.all(
                      color: event.isCompleted ?  AppTheme.successColor : const Color(0xFFCBD5E1),
                      width: 1.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: event.isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const HGapMd(),
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.bgTint(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.levelLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: event.color(context),
                  ),
                ),
              ),
              const HGapMd(),
              // Title & Breadcrumb
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.topicTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: event.isCompleted ? AppTheme.textSecondaryColor(context) : AppTheme.textPrimaryColor(context),
                        decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const VGapXs(),
                    Text(
                      event.breadcrumb,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const HGapSm(),
              // Time
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const HGapXs(),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
