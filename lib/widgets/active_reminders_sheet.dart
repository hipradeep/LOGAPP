import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/cache_service.dart';
import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../models/activity.dart';
import 'app_spacers.dart';

class ActiveRemindersSheet extends StatefulWidget {
  const ActiveRemindersSheet({super.key});

  @override
  State<ActiveRemindersSheet> createState() => _ActiveRemindersSheetState();
}

class _ActiveRemindersSheetState extends State<ActiveRemindersSheet> {
  final CacheService _cacheService = CacheService();
  final ActivityService _activityService = ActivityService();
  
  bool _dailyReminder = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    final val = await _cacheService.getDailyReminder();
    if (mounted) {
      setState(() {
        _dailyReminder = val;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleReminder(bool val) async {
    await _cacheService.saveDailyReminder(val);
    if (val) {
      await NotificationService.scheduleDailyNotification(
        id: 999,
        title: 'Daily Journal Reminder 📝',
        body: 'Time to record your daily thoughts and update your log!',
        timeString: '09:00 PM',
      );
    } else {
      await NotificationService.cancelNotification(999);
    }
    setState(() {
      _dailyReminder = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const VGapMd(),
                  Text('Active Reminders ⏰', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
                  const VGapMd(),
                  
                  // Daily note Reminder Toggle Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryLight, size: 20),
                        ),
                        const HGapMd(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily note Reminder', style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                              const VGapXs(),
                              Text('Daily nudge to record your thoughts', style: AppTheme.bodySmall.copyWith(fontSize: 10)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _dailyReminder,
                          activeThumbColor: AppTheme.primaryColor,
                          activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                          inactiveThumbColor: AppTheme.textSecondary,
                          inactiveTrackColor: Colors.white12,
                          onChanged: _toggleReminder,
                        ),
                      ],
                    ),
                  ),
                  const VGapMd(),
                  
                  // Pending activities count
                  StreamBuilder<List<Activity>>(
                    stream: _activityService.getCheckedActivitiesStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.successColor, size: 20),
                            ),
                            const HGapMd(),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Daily Attendance Tracker', style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const VGapXs(),
                                  Text('You have $count active habits configured for today.', style: AppTheme.bodySmall.copyWith(fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const VGapLg(),
                  SizedBox(
                    width: double.infinity,
                    height: AppTheme.buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
