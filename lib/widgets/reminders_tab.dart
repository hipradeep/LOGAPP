import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

import '../models/reminder_item.dart';
import '../models/upcoming_reminder.dart';
import '../controllers/reminders_controller.dart';
import 'base_management_tab.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
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

  String _formatReminderTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('h:mm a').format(dt);
    if (date == today) {
      return 'Today at $timeStr';
    } else if (date == tomorrow) {
      return 'Tomorrow at $timeStr';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<RemindersController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.reminders.isEmpty && ctrl.upcomingReminders.isEmpty,
      emptyIcon: Icons.notifications_none,
      emptyMessage: 'No reminders active.',
      onRefresh: () async => await _controller.refresh(),
      onFabPressed: _showAddReminderDialog,
      builder: (context, controller) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.upcomingReminders.isNotEmpty) ...[
                Text('Upcoming Reminders (Next 2 Days)', style: AppTheme.headingSmall),
                const VGapSm(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: controller.upcomingReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = controller.upcomingReminders[index];
                    final timeStr = _formatReminderTime(reminder.scheduledDateTime);
                    return Card(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.primaryLight,
                        ),
                        title: Text(
                          reminder.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$timeStr • ${reminder.subtitle}',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                          color: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) {
                            if (value == 'skip') {
                              controller.skipReminderForToday(reminder);
                            } else if (value == 'snooze_10') {
                              controller.snoozeReminder(reminder, 10);
                            } else if (value == 'snooze_20') {
                              controller.snoozeReminder(reminder, 20);
                            } else if (value == 'snooze_30') {
                              controller.snoozeReminder(reminder, 30);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'skip',
                              child: Row(
                                children: [
                                  Icon(Icons.next_plan_rounded, size: 18, color: AppTheme.warningColor),
                                  HGapSm(),
                                  Text('Skip for Today', style: TextStyle(color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'snooze_10',
                              child: Row(
                                children: [
                                  Icon(Icons.snooze_rounded, size: 18, color: AppTheme.primaryLight),
                                  HGapSm(),
                                  Text('Snooze 10 Min', style: TextStyle(color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'snooze_20',
                              child: Row(
                                children: [
                                  Icon(Icons.snooze_rounded, size: 18, color: AppTheme.primaryLight),
                                  HGapSm(),
                                  Text('Snooze 20 Min', style: TextStyle(color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'snooze_30',
                              child: Row(
                                children: [
                                  Icon(Icons.snooze_rounded, size: 18, color: AppTheme.primaryLight),
                                  HGapSm(),
                                  Text('Snooze 30 Min', style: TextStyle(color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const VGapMd(),
              ],
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
                            onChanged: (val) {
                              controller.toggleReminderActive(index, val);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                            onPressed: () {
                              controller.removeReminder(index);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
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

}
