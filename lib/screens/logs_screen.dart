import 'dart:ui';
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
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _useMockData = false;

  @override
  void initState() {
    super.initState();
    _useMockData = Firebase.apps.isEmpty;
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
                  'Journal & Check-ins (Last 2 Days)'.toUpperCase(),
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
                          ? AppTheme.warningColor.withOpacity(0.15)
                          : AppTheme.successColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _useMockData
                            ? AppTheme.warningColor.withOpacity(0.4)
                            : AppTheme.successColor.withOpacity(0.4),
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
      stream: _firebaseService.getActivitiesStream(),
      builder: (context, activitiesSnapshot) {
        if (activitiesSnapshot.hasError) {
          return const Center(child: Text('Error loading activities'));
        }
        if (activitiesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final activities = activitiesSnapshot.data ?? [];

        return StreamBuilder<List<LogEntry>>(
          stream: _firebaseService.getLogsStream(),
          builder: (context, logsSnapshot) {
            if (logsSnapshot.hasError) {
              return const Center(child: Text('Error loading journal entries'));
            }
            if (logsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            final logs = logsSnapshot.data ?? [];

            return StreamBuilder<List<CheckIn>>(
              stream: _firebaseService.getCheckedActivitiesCheckInsStream(),
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
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(const Duration(days: 1));

    // Today filter
    final todayLogs = logs.where((l) => _isSameDay(l.timestamp, now)).toList();
    final todayCheckIns = checkIns.where((c) => _isSameDay(c.timestamp, now) && c.checked).toList();

    // Yesterday filter
    final yesterdayLogs = logs.where((l) => _isSameDay(l.timestamp, yesterday)).toList();
    final yesterdayCheckIns = checkIns.where((c) => _isSameDay(c.timestamp, yesterday) && c.checked).toList();

    // Combine and sort Today items by timestamp (newest first)
    final List<dynamic> todayItems = [...todayLogs, ...todayCheckIns];
    todayItems.sort((a, b) {
      final DateTime timeA = a is LogEntry ? a.timestamp : (a as CheckIn).timestamp;
      final DateTime timeB = b is LogEntry ? b.timestamp : (b as CheckIn).timestamp;
      return timeB.compareTo(timeA);
    });

    // Combine and sort Yesterday items by timestamp (newest first)
    final List<dynamic> yesterdayItems = [...yesterdayLogs, ...yesterdayCheckIns];
    yesterdayItems.sort((a, b) {
      final DateTime timeA = a is LogEntry ? a.timestamp : (a as CheckIn).timestamp;
      final DateTime timeB = b is LogEntry ? b.timestamp : (b as CheckIn).timestamp;
      return timeB.compareTo(timeA);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODAY SECTION
          _buildSectionHeader('Today', now),
          const VGapMd(),
          if (todayItems.isEmpty)
            _buildEmptyDayState('No entries or check-ins completed today.')
          else ...[
            ...todayItems.map((item) {
              if (item is LogEntry) {
                return _buildJournalCard(item);
              } else if (item is CheckIn) {
                return _buildCheckInTile(item, activities);
              }
              return const SizedBox.shrink();
            }),
          ],
          const VGapLg(),

          // YESTERDAY SECTION
          _buildSectionHeader('Yesterday', yesterday),
          const VGapMd(),
          if (yesterdayItems.isEmpty)
            _buildEmptyDayState('No entries or check-ins completed yesterday.')
          else ...[
            ...yesterdayItems.map((item) {
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
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 16),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary.withOpacity(0.6),
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
        margin: const EdgeInsets.only(bottom: 8, left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
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
                        color: Colors.white.withOpacity(0.7),
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
              top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
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
                    color: Colors.white.withOpacity(0.2),
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

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$label',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
      ),
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
      margin: const EdgeInsets.only(bottom: 8, left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.2),
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
                          color: Colors.white.withOpacity(0.7),
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
