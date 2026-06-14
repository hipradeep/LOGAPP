import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/monthly_calendar.dart';
import '../widgets/note_options_sheet.dart';
import '../models/activity.dart';
import '../models/note_entity.dart';
import '../models/check_in.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/note_service.dart';
import 'note_write_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();
  final NoteService _noteService = NoteService();

  DateTime _selectedDate = DateTime.now();
  late final Stream<List<Activity>> _activitiesStream = _activityService.getActivitiesStream();
  late final Stream<List<NoteEntity>> _notesStream = _noteService.getNotesStream();
  late final Stream<List<CheckIn>> _checkInsStream = _checkInService.getActiveActivitiesCheckInsStream();

  @override
  void initState() {
    super.initState();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  void _navigateToWriteScreen({NoteEntity? existingEntry}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteWriteScreen(
          existingEntry: existingEntry,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final title = result['title'] as String;
      final content = result['content'] as String;
      final mood = result['mood'] as String;
      final tags = result['tags'] as List<String>;

      try {
        if (existingEntry != null) {
          await _noteService.updateEntry(existingEntry.id, title, content, mood, tags);
        } else {
          await _noteService.createEntry(title, content, mood, tags);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to Firestore. ($e)'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _handleDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius)),
        title: Text('Delete Log', style: AppTheme.headingSmall),
        content: Text(
          'Are you sure you want to permanently delete this entry?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _noteService.deleteEntry(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log deleted from Firestore.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: true,
        title: 'Activity Logs',
        padding: EdgeInsets.zero,
        backgroundWidgets: const [
          GlowBlob(
            top: -40,
            right: -40,
            size: 240,
            color: AppTheme.secondaryColor,
            opacity: 0.08,
          ),
          GlowBlob(
            bottom: -50,
            left: -50,
            size: 260,
            color: AppTheme.primaryColor,
            opacity: 0.05,
          ),
        ],
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'note & Check-ins'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VGapSm(),

          // Dynamic Logs Content
          _buildFirestoreTimeline(),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding + 36),
        child: _buildPremiumFAB(
          onPressed: () => _navigateToWriteScreen(),
        ),
      ),
    );
  }

  Widget _buildPremiumFAB({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  // FIRESTORE STREAM PIPELINE
  Widget _buildFirestoreTimeline() {
    return StreamBuilder<List<Activity>>(
      stream: _activitiesStream,
      builder: (context, activitiesSnapshot) {
        if (activitiesSnapshot.hasError) {
          return const Center(child: Text('Error loading activities'));
        }
        if (activitiesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final activities = activitiesSnapshot.data ?? [];

        return StreamBuilder<List<NoteEntity>>(
          stream: _notesStream,
          builder: (context, logsSnapshot) {
            if (logsSnapshot.hasError) {
              return const Center(child: Text('Error loading note entries'));
            }
            if (logsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            final logs = logsSnapshot.data ?? [];

            return StreamBuilder<List<CheckIn>>(
              stream: _checkInsStream,
              builder: (context, checkinsSnapshot) {
                if (checkinsSnapshot.hasError) {
                  return const Center(child: Text('Error loading check-ins'));
                }
                if (checkinsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                final checkIns = checkinsSnapshot.data ?? [];

                return _buildTimelineList(activities, logs, checkIns);
              },
            );
          },
        );
      },
    );
  }

  // TIMELINE BUILDER
  Widget _buildTimelineList(
    List<Activity> activities,
    List<NoteEntity> logs,
    List<CheckIn> checkIns,
  ) {
    final DateTime today = DateTime.now();
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    String headerTitle = '';
    if (_isSameDay(_selectedDate, today)) {
      headerTitle = 'Today';
    } else if (_isSameDay(_selectedDate, yesterday)) {
      headerTitle = 'Yesterday';
    } else {
      headerTitle = DateFormat('EEEE').format(_selectedDate);
    }

    final dayLogs = logs.where((l) => _isSameDay(l.timestamp, _selectedDate)).toList();
    final dayCheckIns = checkIns.where((c) => _isSameDay(c.timestamp, _selectedDate) && c.checked).toList();

    final List<dynamic> dayItems = [...dayLogs, ...dayCheckIns];
    dayItems.sort((a, b) {
      final DateTime timeA = a is NoteEntity ? a.timestamp : (a as CheckIn).timestamp;
      final DateTime timeB = b is NoteEntity ? b.timestamp : (b as CheckIn).timestamp;
      return timeB.compareTo(timeA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonthlyCalendar(
          selectedDate: _selectedDate,
          logs: logs,
          checkIns: checkIns,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),
        const VGapMd(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(headerTitle, _selectedDate),
              const VGapMd(),
              if (dayItems.isEmpty)
                _buildEmptyDayState('No entries or check-ins completed on this day.')
              else ...[
                ...dayItems.map((item) {
                  if (item is NoteEntity) {
                    return _buildJournalCard(item);
                  } else if (item is CheckIn) {
                    return _buildCheckInTile(item, activities);
                  }
                  return const SizedBox.shrink();
                }),
              ],
              const VGapXxl(),
              const VGapXxl(),
              const VGapXxl(),
            ],
          ),
        ),
      ],
    );
  }

  // BUILD TIMELINE DATE HEADERS
  Widget _buildSectionHeader(String title, DateTime date) {
    final formattedDate = DateFormat('MMMM d, yyyy').format(date);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const HGapSm(),
        Text(
          title,
          style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const HGapSm(),
        Text(
          '• $formattedDate',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  // BUILD DUMMY / EMPTY TEXT WIDGET
  Widget _buildEmptyDayState(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }

  // BUILD note ENTRY CARD
  Widget _buildJournalCard(NoteEntity entry) {
    final timeStr = DateFormat('h:mm a').format(entry.timestamp);
    
    return GestureDetector(
      onLongPress: () => _showJournalOptionsBottomSheet(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sleek glowing mood container
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                entry.mood,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title.isNotEmpty ? entry.title : 'Untitled Log',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const HGapSm(),
                      Text(
                        timeStr,
                        style: AppTheme.bodySmall.copyWith(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (entry.content.isNotEmpty) ...[
                    const VGapXs(),
                    // Compact Content Text (max 2 lines)
                    Text(
                      entry.content,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJournalOptionsBottomSheet(NoteEntity entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteOptionsSheet(
        entry: entry,
        onEdit: () => _navigateToWriteScreen(existingEntry: entry),
        onDelete: () => _handleDelete(entry.id),
      ),
    );
  }



  // BUILD CHECK-IN TILE
  Widget _buildCheckInTile(CheckIn checkIn, List<Activity> activities) {
    final activity = activities.firstWhere(
      (a) => a.id == checkIn.activityId,
      orElse: () => Activity(id: '', name: 'Deleted Activity', isActive: false, timestamp: DateTime.now()),
    );
    final timeStr = DateFormat('h:mm a').format(checkIn.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 18,
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activity.name,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (checkIn.subTaskName != null) ...[
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Sub-task',
                                style: TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else if (activity.trackingType != 'single') ...[
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Multi',
                                style: TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const VGapXs(),
                      Text(
                        checkIn.subTaskName != null
                            ? 'Completed: ${checkIn.subTaskName!.split('|').first}'
                            : 'Logged a quick check-in.',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const HGapMd(),
          Text(
            timeStr,
            style: AppTheme.bodySmall.copyWith(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
