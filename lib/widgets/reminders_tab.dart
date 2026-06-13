import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

import '../models/reminder_item.dart';
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

  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<RemindersController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.reminders.isEmpty,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Reminders', style: AppTheme.headingSmall),
              ],
            ),
            const VGapSm(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
