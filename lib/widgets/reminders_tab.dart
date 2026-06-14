import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'glass_modal_sheet.dart';
import '../models/reminder_item.dart';
import '../models/upcoming_reminder.dart';
import '../models/activity.dart';
import '../controllers/reminders_controller.dart';
import 'base_management_tab.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  late RemindersController _controller;
  late PageController _pageController;
  int _activeFragment = 0; // 0 = Alarm (Custom), 1 = Reminders

  @override
  void initState() {
    super.initState();
    _controller = RemindersController();
    _pageController = PageController(initialPage: _activeFragment);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }


  void _switchToCustomAlarms() {
    setState(() => _activeFragment = 0);
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _switchToReminders() {
    setState(() => _activeFragment = 1);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageChanged(int index) {
    setState(() => _activeFragment = index);
  }

  Future<void> _handleRefresh() async {
    await _controller.refresh();
  }

  void _toggleReminder(int index, bool value) {
    _controller.toggleReminderActive(index, value);
  }

  void _deleteReminder(int index) {
    _controller.removeReminder(index);
  }


  Widget _buildActivityGroupCard(
    BuildContext context,
    Activity activity,
    List<UpcomingReminder> reminders,
    RemindersController controller,
  ) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    final symbol = activity.symbolValue ?? '🔔';
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      color: AppTheme.surfaceColor.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.05),
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
                      color: AppTheme.textPrimary.withValues(alpha: 0.9),
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
                          ? AppTheme.primaryLight
                          : AppTheme.textSecondary.withValues(alpha: 0.25),
                    ),
                  ),
                );
              }),
            ),
            const VGapMd(),

            // Header Divider
            const Divider(color: Colors.white10, height: 1),
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
                    const Divider(color: Colors.white10, height: 1),
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
    final timeStr = DateFormat('HH:mm').format(reminder.scheduledDateTime);
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
        ? Colors.white
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
                        color: AppTheme.primaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

  Widget _buildSelectorBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _switchToCustomAlarms,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeFragment == 0
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Alarm (Custom)',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _activeFragment == 0
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _switchToReminders,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeFragment == 1
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reminders',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _activeFragment == 1
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAlarmsTab(double bottomPadding, double viewInsetsBottom, RemindersController controller) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.reminders.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VGapXxl(),
                  VGapXxl(),
                  Icon(Icons.alarm_off_rounded, size: 64, color: AppTheme.textSecondary),
                  VGapMd(),
                  Text(
                    'No custom alarms',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  VGapSm(),
                  Text(
                    'Tap the + button to create a custom alarm.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            Text('Quick Reminders', style: AppTheme.headingSmall),
            const VGapSm(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: controller.reminders.length,
              itemBuilder: (context, index) {
                final reminder = controller.reminders[index];
                return Card(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      reminder.isActive ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                      color: reminder.isActive ? AppTheme.primaryLight : AppTheme.textSecondary,
                    ),
                    title: Text(
                      reminder.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        decoration: !reminder.isActive ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(reminder.time, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: reminder.isActive,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (val) => _toggleReminder(index, val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                          onPressed: () => _deleteReminder(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
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
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VGapXxl(),
                  VGapXxl(),
                  Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary),
                  VGapMd(),
                  Text(
                    'No active reminders',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  VGapSm(),
                  Text(
                    'Enable activities or milestone tasks to set reminders.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            ...controller.remindersByActivity.entries.where((entry) {
              final activity = controller.activities.firstWhere(
                (a) => a.name == entry.key,
                orElse: () => Activity(id: '', name: entry.key, isActive: false, timestamp: DateTime.now()),
              );
              return activity.isActive;
            }).map((entry) {
              final activityName = entry.key;
              final list = entry.value;

              final activity = controller.activities.firstWhere(
                (a) => a.name == activityName,
              );

              return _buildActivityGroupCard(context, activity, list, controller);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, RemindersController controller) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      children: [
        _buildSelectorBar(),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            children: [
              _buildCustomAlarmsTab(bottomPadding, viewInsetsBottom, controller),
              _buildRemindersTab(bottomPadding, viewInsetsBottom, controller),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<RemindersController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => false,
      emptyIcon: Icons.notifications_none,
      emptyMessage: 'No reminders active.',
      onRefresh: _handleRefresh,
      onFabPressed: _showAddReminderDialog,
      showFab: _activeFragment == 0,
      builder: _buildTabContent,
    );
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Reminder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Walk dog, Meditate',
                      labelText: 'Task',
                    ),
                  ),
                  const VGapMd(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time: ${selectedTime.format(context)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: const Text('Pick Time', style: TextStyle(color: AppTheme.primaryLight)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      _controller.addReminder(ReminderItem(
                        title: titleController.text,
                        time: selectedTime.format(context),
                      ));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
              title: const Text('Skip for Today', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () {
                controller.skipReminderForToday(reminder);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.snooze_rounded, color: AppTheme.primaryLight),
              title: const Text('Snooze 10 Minutes', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                controller.snoozeReminder(reminder, 10);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.snooze_rounded, color: AppTheme.primaryLight),
              title: const Text('Snooze 20 Minutes', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                controller.snoozeReminder(reminder, 20);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: const Icon(Icons.snooze_rounded, color: AppTheme.primaryLight),
              title: const Text('Snooze 30 Minutes', style: TextStyle(color: AppTheme.textPrimary)),
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
