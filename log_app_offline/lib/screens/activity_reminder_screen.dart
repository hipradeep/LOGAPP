import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glass_modal_sheet.dart';
import '../models/upcoming_reminder.dart';
import '../models/activity.dart';
import '../controllers/reminders_controller.dart';
import '../widgets/app_provider.dart';
import '../widgets/full_screen_page.dart';

class ActivityReminderScreen extends StatefulWidget {
  const ActivityReminderScreen({super.key});

  @override
  State<ActivityReminderScreen> createState() => _ActivityReminderScreenState();
}

class _ActivityReminderScreenState extends State<ActivityReminderScreen> {
  late RemindersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RemindersController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<RemindersController>(
      notifier: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return FullScreenPage(
            isScrollable: false,
            title: 'Activity Reminder',
            showBackButton: true,

            children: [
              Expanded(
                child: _buildBody(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final error = _controller.errorMessage;
    if (error != null) {
      return Center(
        child: Text(
          'Failed to load data:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.errorColor),
        ),
      );
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surface(context),
      child: _buildRemindersTab(bottomPadding, viewInsetsBottom, _controller),
    );
  }

  Widget _buildRemindersTab(double bottomPadding, double viewInsetsBottom, RemindersController controller) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.upcomingReminders.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const VGapXxl(),
                  const VGapXxl(),
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  const VGapMd(),
                  Text(
                    'No active reminders',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const VGapSm(),
                  Text(
                    'Enable activities or milestone tasks to set reminders.',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...controller.remindersByActivity.entries.where((entry) {
              final activity = controller.activities.firstWhere(
                (a) => a.id == entry.key,
                orElse: () => Activity(id: '', name: 'Unknown', isActive: false, timestamp: DateTime.now()),
              );
              return activity.isActive;
            }).map((entry) {
              final activityId = entry.key;
              final list = entry.value;

              final activity = controller.activities.firstWhere(
                (a) => a.id == activityId,
                orElse: () => Activity(id: '', name: 'Unknown', isActive: false, timestamp: DateTime.now()),
              );

              return ActivityGroupCard(
                activity: activity,
                reminders: list,
                controller: controller,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class ActivityGroupCard extends StatelessWidget {
  final Activity activity;
  final List<UpcomingReminder> reminders;
  final RemindersController controller;

  const ActivityGroupCard({
    super.key,
    required this.activity,
    required this.reminders,
    required this.controller,
  });

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Crucial Flutter theme gotcha register

    if (reminders.isEmpty) return const SizedBox.shrink();

    final symbol = activity.symbolValue ?? '🔔';

    return Card(
      color: AppTheme.surface(context).withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Header: Symbol + Name
            Row(
              children: [
                Text(
                  symbol,
                  style: const TextStyle(fontSize: 16),
                ),
                const HGapSm(),
                Expanded(
                  child: Text(
                    activity.name.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const VGapSm(),

            // Weekdays Repeat Schedule Row (with tiny circular backgrounds)
            Row(
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isRepeat = activity.repeatDays.contains(dayNum);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isRepeat
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRepeat
                          ? AppTheme.primaryAccentColor(context).withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _weekdays[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isRepeat
                          ? AppTheme.primaryAccentColor(context)
                          : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
            ),
            const VGapMd(),

            // Header Divider
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapMd(),

            // Nested Task Reminder Rows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskItemRow(
                      activity: activity,
                      reminder: reminder,
                      controller: controller,
                    ),
                    if (index < reminders.length - 1) ...[
                      const VGapMd(),
                      Divider(color: AppTheme.borderColor(context), height: 1),
                      const VGapMd(),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TaskItemRow extends StatelessWidget {
  final Activity activity;
  final UpcomingReminder reminder;
  final RemindersController controller;

  const TaskItemRow({
    super.key,
    required this.activity,
    required this.reminder,
    required this.controller,
  });

  static final _timeFormatter = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Crucial Flutter theme gotcha register

    final timeStr = _timeFormatter.format(reminder.scheduledDateTime);
    final displayTitle = reminder.subTaskTitle ??
        (reminder.type == 'task' && reminder.task != null
            ? reminder.task!.taskName
            : reminder.title);

    final IconData pillIcon;
    if (reminder.type == 'subtask') {
      pillIcon = Icons.task_alt_rounded;
    } else if (reminder.type == 'task') {
      pillIcon = Icons.star_rounded;
    } else {
      pillIcon = Icons.notifications_active_rounded;
    }

    final Color timeColor = activity.reminderEnabled
        ? AppTheme.textPrimaryColor(context)
        : AppTheme.textSecondaryColor(context).withValues(alpha: 0.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Clickable Task Info
        Expanded(
          child: InkWell(
            onTap: () => _showReminderActionsSheet(context, reminder, controller),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Time
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: timeColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const HGapMd(),
                  // Pill Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pillIcon,
                            size: 11,
                            color: AppTheme.primaryAccentColor(context),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              displayTitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.pillBadgeTextColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const HGapMd(),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: activity.reminderEnabled,
            activeThumbColor: AppTheme.successColor,
            activeTrackColor: AppTheme.successColor.withValues(alpha: 0.4),
            inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
            inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) {
              controller.toggleReminderEnabled(activity, val);
            },
          ),
        ),
      ],
    );
  }

  void _showReminderActionsSheet(
    BuildContext context,
    UpcomingReminder reminder,
    RemindersController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassModalSheet(
          title: reminder.title,
          subtitle: 'Reminder Action',
          children: [
            ListTile(
              leading: Icon(Icons.next_plan_rounded, color: AppTheme.warningColor),
              title: Text(
                'Skip for Today',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                controller.skipReminderForToday(reminder);
                Navigator.pop(context);
              },
            ),
            Divider(color: AppTheme.borderColor(context), height: 1),
            ListTile(
              leading: Icon(
                Icons.snooze_rounded,
                color: AppTheme.primaryAccentColor(context),
              ),
              title: Text(
                'Snooze 10 Minutes',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              onTap: () {
                controller.snoozeReminder(reminder, 10);
                Navigator.pop(context);
              },
            ),
            Divider(color: AppTheme.borderColor(context), height: 1),
            ListTile(
              leading: Icon(
                Icons.snooze_rounded,
                color: AppTheme.primaryAccentColor(context),
              ),
              title: Text(
                'Snooze 20 Minutes',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              onTap: () {
                controller.snoozeReminder(reminder, 20);
                Navigator.pop(context);
              },
            ),
            Divider(color: AppTheme.borderColor(context), height: 1),
            ListTile(
              leading: Icon(
                Icons.snooze_rounded,
                color: AppTheme.primaryAccentColor(context),
              ),
              title: Text(
                'Snooze 30 Minutes',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              onTap: () {
                controller.snoozeReminder(reminder, 30);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
