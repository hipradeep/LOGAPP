import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../theme/app_theme.dart';
import '../app_spacers.dart';

/// Screen 5: Agenda View displaying upcoming revisions grouped by date
class CalendarAgendaView extends StatelessWidget {
  final Map<DateTime, List<CalendarEvent>> agendaGroups;
  final ValueChanged<CalendarEvent> onEventTap;

  const CalendarAgendaView({
    super.key,
    required this.agendaGroups,
    required this.onEventTap,
  });

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  static final DateFormat _dayNameFormat = DateFormat('EEE');

  String _groupTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final clean = DateTime(date.year, date.month, date.day);

    if (clean == today) {
      return 'Today • ${_dateFormat.format(clean)}';
    } else if (clean == tomorrow) {
      return 'Tomorrow • ${_dateFormat.format(clean)}';
    } else {
      return '${_dayNameFormat.format(clean)} • ${_dateFormat.format(clean)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = agendaGroups.keys.toList()..sort();

    if (dates.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_rounded, size: 48, color: AppTheme.textSecondaryColor(context)),
              VGapMd(),
              Text(
                'No upcoming revisions scheduled',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              VGapXs(),
              Text(
                'Completed topics and scheduled ladder revisions will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final events = agendaGroups[date] ?? [];
          final title = _groupTitle(date);

          return Padding(
            padding: const EdgeInsets.only(bottom: 18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Header: Today • 10 Oct 2025       3 items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      '${events.length} ${events.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
                const VGapSm(),
                // Cards
                ...events.map((event) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _AgendaItemCard(
                      event: event,
                      onTap: () => onEventTap(event),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AgendaItemCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _AgendaItemCard({
    required this.event,
    required this.onTap,
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
              // Title
              Expanded(
                child: Text(
                  event.topicTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const HGapSm(),
              // Scheduled Time
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const HGapXs(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
