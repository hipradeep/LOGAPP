import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import '../models/activity.dart';
import '../models/log_entry.dart';
import '../models/check_in.dart';
import '../services/firebase_service.dart';
import 'write_log_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _useMockData = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  late final Stream<List<Activity>> _activitiesStream = _firebaseService.getActivitiesStream();
  late final Stream<List<LogEntry>> _logsStream = _firebaseService.getLogsStream();
  late final Stream<List<CheckIn>> _checkInsStream = _firebaseService.getCheckedActivitiesCheckInsStream();

  @override
  void initState() {
    super.initState();
    _useMockData = Firebase.apps.isEmpty;
    _currentMonth = _selectedDate;
  }


  List<DateTime?> _generateMonthGridDates(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    
    final startPadding = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    final List<DateTime?> gridDates = [];
    for (int i = 0; i < startPadding; i++) {
      gridDates.add(null);
    }
    
    final totalDays = lastDayOfMonth.day;
    for (int i = 1; i <= totalDays; i++) {
      gridDates.add(DateTime(monthDate.year, monthDate.month, i));
    }
    
    while (gridDates.length % 7 != 0) {
      gridDates.add(null);
    }
    
    return gridDates;
  }



  bool _isFutureDay(DateTime date) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    return dateMidnight.isAfter(todayMidnight);
  }

  Widget _buildCalendarHeader() {
    final dateStr = DateFormat('d MMM, yy').format(_selectedDate);
    final weekdayStr = DateFormat('EEEE').format(_selectedDate);
    
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dateStr,
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    weekdayStr,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                DateFormat('MMM yyyy').format(_currentMonth),
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysHeader() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return SizedBox(
            width: 32,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today, List<LogEntry> logs, List<CheckIn> checkIns) {
    final isSelected = _isSameDay(date, _selectedDate);
    final isTodayDate = _isSameDay(date, today);
    final isFuture = _isFutureDay(date);
    
    final hasLog = logs.any((l) => _isSameDay(l.timestamp, date));
    final hasCheckIn = checkIns.any((c) => _isSameDay(c.timestamp, date) && c.checked);
    
    final dayNumber = DateFormat('d').format(date);
    
    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              setState(() {
                _selectedDate = date;
                _currentMonth = date;
              });
            },
      child: Opacity(
        opacity: isFuture ? 0.3 : 1.0,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            border: isTodayDate && !isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayNumber,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected || isTodayDate ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.backgroundColor
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasLog)
                    Container(
                      width: 2.5,
                      height: 2.5,
                      margin: const EdgeInsets.only(right: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppTheme.primaryDark : AppTheme.primaryLight,
                      ),
                    ),
                  if (hasCheckIn)
                    Container(
                      width: 2.5,
                      height: 2.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor,
                      ),
                    ),
                  if (!hasLog && !hasCheckIn)
                    const SizedBox(height: 2.5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(List<LogEntry> logs, List<CheckIn> checkIns) {
    final gridDates = _generateMonthGridDates(_currentMonth);
    final today = DateTime.now();
    
    final List<Widget> rows = [];
    for (int i = 0; i < gridDates.length; i += 7) {
      final weekDates = gridDates.sublist(i, i + 7);
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDates.map((date) {
            if (date == null) {
              return const SizedBox(width: 32, height: 32);
            }
            return _buildDayCell(date, today, logs, checkIns);
          }).toList(),
        ),
      );
      if (i + 7 < gridDates.length) {
        rows.add(const SizedBox(height: 4));
      }
    }
    
    return Column(
      children: rows,
    );
  }

  Widget _buildCalendarView(List<LogEntry> logs, List<CheckIn> checkIns) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          _buildWeekdaysHeader(),
          const SizedBox(height: 4),
          _buildMonthGrid(logs, checkIns),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  void _navigateToWriteScreen({LogEntry? existingEntry}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteLogScreen(
          existingEntry: existingEntry,
          useMockData: _useMockData,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final title = result['title'] as String;
      final content = result['content'] as String;
      final mood = result['mood'] as String;
      final tags = result['tags'] as List<String>;

      if (_useMockData) {
        setState(() {
          if (existingEntry != null) {
            final idx = FirebaseService.mockEntries.indexWhere((item) => item.id == existingEntry.id);
            if (idx != -1) {
              FirebaseService.mockEntries[idx] = FirebaseService.mockEntries[idx].copyWith(
                title: title,
                content: content,
                mood: mood,
                tags: tags,
              );
            }
          } else {
            FirebaseService.mockEntries.insert(
              0,
              LogEntry(
                id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                content: content,
                timestamp: DateTime.now(),
                mood: mood,
                tags: tags,
              ),
            );
          }
        });
        FirebaseService.notifyLogsChanged();
      } else {
        try {
          if (existingEntry != null) {
            await _firebaseService.updateEntry(existingEntry.id, title, content, mood, tags);
          } else {
            await _firebaseService.createEntry(title, content, mood, tags);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save to Firestore. ($e)'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _handleDelete(String id, bool isLive) async {
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
      if (!isLive) {
        setState(() {
          FirebaseService.mockEntries.removeWhere((item) => item.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log deleted locally.')),
        );
        FirebaseService.notifyLogsChanged();
      } else {
        try {
          await _firebaseService.deleteEntry(id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log deleted from Firestore.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting entry: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
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
          // Mode toggle header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Expanded(
                child: Text(
                  'Journal & Check-ins'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const HGapSm(),
              GestureDetector(
                  onTap: () {
                    if (Firebase.apps.isNotEmpty) {
                      setState(() {
                        _useMockData = !_useMockData;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _useMockData
                          ? AppTheme.warningColor.withValues(alpha: 0.15)
                          : AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _useMockData
                            ? AppTheme.warningColor.withValues(alpha: 0.4)
                            : AppTheme.successColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const HGapSm(),
                        Text(
                          _useMockData ? 'OFFLINE' : 'LIVE',
                          style: TextStyle(
                            color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VGapSm(),

          // Dynamic Logs Content
          _useMockData ? _buildLocalTimeline() : _buildFirestoreTimeline(),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding + 86),
        child: FloatingActionButton(
          onPressed: () => _navigateToWriteScreen(),
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const IconMd(Icons.add, color: Colors.white),
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

        return StreamBuilder<List<LogEntry>>(
          stream: _logsStream,
          builder: (context, logsSnapshot) {
            if (logsSnapshot.hasError) {
              return const Center(child: Text('Error loading journal entries'));
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

  // LOCAL OFFLINE SIMULATION
  Widget _buildLocalTimeline() {
    final activities = FirebaseService.mockActivities;
    final logs = FirebaseService.mockEntries;
    final checkIns = FirebaseService.mockCheckIns;
    return _buildTimelineList(activities, logs, checkIns);
  }

  // TIMELINE BUILDER
  Widget _buildTimelineList(
    List<Activity> activities,
    List<LogEntry> logs,
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
      final DateTime timeA = a is LogEntry ? a.timestamp : (a as CheckIn).timestamp;
      final DateTime timeB = b is LogEntry ? b.timestamp : (b as CheckIn).timestamp;
      return timeB.compareTo(timeA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCalendarView(logs, checkIns),
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
                  if (item is LogEntry) {
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

  // BUILD JOURNAL ENTRY CARD
  Widget _buildJournalCard(LogEntry entry) {
    final timeStr = DateFormat('h:mm a').format(entry.timestamp);
    final isLive = !_useMockData;
    
    return GestureDetector(
      onLongPress: () => _showJournalOptionsBottomSheet(entry, isLive),
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

  void _showJournalOptionsBottomSheet(LogEntry entry, bool isLive) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppTheme.defaultBorderRadius),
              topRight: Radius.circular(AppTheme.defaultBorderRadius),
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VGapSm(),
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const VGapMd(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    entry.title.isNotEmpty ? entry.title : 'Journal Entry',
                    style: AppTheme.headingSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                    child: Text(
                      entry.content,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryLight),
                  title: Text('Edit Entry', style: AppTheme.bodyLarge),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToWriteScreen(existingEntry: entry);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
                  title: Text('Delete Entry', style: AppTheme.bodyLarge.copyWith(color: AppTheme.errorColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDelete(entry.id, isLive);
                  },
                ),
                const VGapSm(),
              ],
            ),
          ),
        );
      },
    );
  }



  // BUILD CHECK-IN TILE
  Widget _buildCheckInTile(CheckIn checkIn, List<Activity> activities) {
    final activity = activities.firstWhere(
      (a) => a.id == checkIn.activityId,
      orElse: () => Activity(id: '', name: 'Deleted Activity', checked: false, timestamp: DateTime.now()),
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
                          if (activity.trackingType != 'single') ...[
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
                        'Logged a quick check-in.',
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
