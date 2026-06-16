import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glass_modal_sheet.dart';
import '../models/upcoming_reminder.dart';
import '../models/activity.dart';
import '../controllers/reminders_controller.dart';
import '../widgets/base_management_tab.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';

class ActivityReminderScreen extends StatefulWidget {
  const ActivityReminderScreen({super.key});

  @override
  State<ActivityReminderScreen> createState() => _ActivityReminderScreenState();
}

class _ActivityReminderScreenState extends State<ActivityReminderScreen> {
  static final _timeFormatter = DateFormat('HH:mm');
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
    return FullScreenPage(
      isScrollable: false,
      title: 'Activity Reminder',
      showBackButton: true,
      backgroundWidgets: const [
        GlowBlob(
          top: -40,
          left: -40,
          size: 220,
          color: AppTheme.primaryColor,
          opacity: 0.08,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 260,
          color: AppTheme.secondaryColor,
          opacity: 0.05,
        ),
      ],
      children: [
        Expanded(
          child: BaseManagementTab<RemindersController>(
            controller: _controller,
            isLoading: (ctrl) => ctrl.isLoading,
            errorMessage: (ctrl) => ctrl.errorMessage,
            isEmpty: (ctrl) => false,
            emptyIcon: Icons.notifications_none,
            emptyMessage: 'No reminders active.',
            onRefresh: _handleRefresh,
            onFabPressed: () {},
            showFab: false,
            builder: (context, controller) {
              final bottomPadding = MediaQuery.of(context).padding.bottom;
              final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
              return _buildRemindersTab(bottomPadding, viewInsetsBottom, controller);
            },
          ),
        ),
      ],
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

              return _buildActivityGroupCard(context, activity, list, controller);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityGroupCard(
    BuildContext context,
    Activity activity,
    List<UpcomingReminder> reminders,
    RemindersController controller,
  ) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    final symbol = activity.symbolValue ?? '🔔';
    final weekdays = _weekdays;

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

            // Weekdays Repeat Schedule Row (once per activity container card)
            Row(
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isRepeat = activity.repeatDays.contains(dayNum);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    weekdays[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRepeat
                          ? AppTheme.primaryAccentColor(context)
                          : AppTheme.textSecondaryColor(context).withValues(alpha: 0.25),
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
                    _buildTaskItemRow(context, activity, reminder, controller),
                    const VGapMd(),
                    Divider(color: AppTheme.borderColor(context), height: 1),
                    if (index < reminders.length - 1) const VGapMd(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItemRow(
    BuildContext context,
    Activity activity,
    UpcomingReminder reminder,
    RemindersController controller,
  ) {
    final timeStr = _timeFormatter.format(reminder.scheduledDateTime);
    final displayTitle = reminder.subTaskTitle ?? (reminder.type == 'task' && reminder.task != null ? reminder.task!.taskName : reminder.title);

    final IconData pillIcon;
    if (reminder.type == 'subtask') {
      pillIcon = Icons.task_alt_rounded;
    } else if (reminder.type == 'task') {
      pillIcon = Icons.star_rounded;
    } else {
      pillIcon = Icons.notifications_active_rounded;
    }

    final Color timeColor = activity.reminderEnabled
        ? Theme.of(context).textTheme.bodyLarge!.color!
        : AppTheme.textSecondary.withValues(alpha: 0.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Clickable Task Info
        Expanded(
          child: InkWell(
            onTap: () => _showReminderActionsSheet(context, reminder, controller),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: timeColor,
                    letterSpacing: -1.0,
                  ),
                ),
                const VGapSm(),
                // Pill Badge
                Container(
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
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.pillBadgeTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const HGapMd(),
        Switch(
          value: activity.reminderEnabled,
          activeThumbColor: AppTheme.successColor,
          activeTrackColor: AppTheme.successColor.withValues(alpha: 0.4),
          onChanged: (val) {
            controller.toggleReminderEnabled(activity, val);
          },
        ),
      ],
    );
  }

  void _showReminderActionsSheet(BuildContext context, UpcomingReminder reminder, RemindersController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassModalSheet(
          title: reminder.title,
          subtitle: 'Reminder Action',
          children: [
            ListTile(
              leading: const Icon(Icons.next_plan_rounded, color: AppTheme.warningColor),
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
