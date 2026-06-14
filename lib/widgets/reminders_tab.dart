import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'glass_modal_sheet.dart';
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
  late PageController _pageController;
  bool _groupByActivity = false;
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

  void _setTimelineView(bool selected) {
    if (selected) {
      setState(() => _groupByActivity = false);
    }
  }

  void _setActivityView(bool selected) {
    if (selected) {
      setState(() => _groupByActivity = true);
    }
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

  Widget? _buildTrailingTimeIndicator(UpcomingReminder reminder, bool isPassed) {
    if (isPassed) return null;
    
    final now = DateTime.now();
    final diff = reminder.scheduledDateTime.difference(now);
    
    if (diff.isNegative) return null;
    
    final totalMinutes = diff.inMinutes;
    if (totalMinutes > 0 && totalMinutes <= 180) {
      final String timeLabel;
      if (totalMinutes < 60) {
        timeLabel = '${totalMinutes}m';
      } else {
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        if (mins == 0) {
          timeLabel = '${hours}h';
        } else {
          timeLabel = '${hours}h ${mins}m';
        }
      }
      
      // Determine aesthetic colors & icon based on urgency level
      final Color badgeBg;
      final Color badgeBorder;
      final Color badgeText;
      final IconData badgeIcon;

      if (totalMinutes <= 15) {
        // High Urgency (<= 15 mins) - Glowing Rose
        badgeBg = AppTheme.errorColor.withValues(alpha: 0.15);
        badgeBorder = AppTheme.errorColor.withValues(alpha: 0.35);
        badgeText = AppTheme.errorColor;
        badgeIcon = Icons.bolt_rounded;
      } else if (totalMinutes <= 60) {
        // Medium Urgency (16-60 mins) - Warm Amber
        badgeBg = AppTheme.warningColor.withValues(alpha: 0.15);
        badgeBorder = AppTheme.warningColor.withValues(alpha: 0.35);
        badgeText = AppTheme.warningColor;
        badgeIcon = Icons.hourglass_bottom_rounded;
      } else {
        // Normal Urgency (61-180 mins) - Sleek Violet
        badgeBg = AppTheme.primaryColor.withValues(alpha: 0.15);
        badgeBorder = AppTheme.primaryColor.withValues(alpha: 0.35);
        badgeText = AppTheme.primaryLight;
        badgeIcon = Icons.access_time_filled_rounded;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: badgeBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeText.withValues(alpha: 0.08),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badgeIcon,
              size: 12,
              color: badgeText,
            ),
            const SizedBox(width: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: badgeText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }
    
    return null;
  }

  Widget _buildReminderList(
    BuildContext context,
    List<UpcomingReminder> reminders,
    RemindersController controller, {
    bool isPassed = false,
    bool showActivityName = true,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        final timeStr = _formatReminderTime(reminder.scheduledDateTime);
        
        String displayTitle = reminder.title;
        if (!showActivityName) {
          if (reminder.type == 'subtask' && reminder.subTaskTitle != null) {
            displayTitle = reminder.subTaskTitle!;
          } else if (reminder.type == 'task' && reminder.task != null) {
            displayTitle = reminder.task!.taskName;
          }
        }

        return Card(
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            dense: true,
            onTap: () => _showReminderActionsSheet(context, reminder, controller),
            leading: Icon(
              isPassed ? Icons.notification_important_rounded : Icons.notifications_active_rounded,
              color: isPassed ? AppTheme.warningColor : AppTheme.primaryLight,
            ),
            title: Text(
              displayTitle,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isPassed
                  ? '$timeStr (Passed) • ${reminder.subtitle}'
                  : '$timeStr • ${reminder.subtitle}',
              style: TextStyle(
                color: isPassed
                    ? AppTheme.warningColor.withValues(alpha: 0.8)
                    : AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            trailing: _buildTrailingTimeIndicator(reminder, isPassed),
          ),
        );
      },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChoiceChip(
                  label: const Text('Timeline'),
                  selected: !_groupByActivity,
                  onSelected: _setTimelineView,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: !_groupByActivity ? AppTheme.primaryLight : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const HGapSm(),
                ChoiceChip(
                  label: const Text('By Activity'),
                  selected: _groupByActivity,
                  onSelected: _setActivityView,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  backgroundColor: Colors.transparent,
                  labelStyle: TextStyle(
                    color: _groupByActivity ? AppTheme.primaryLight : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const VGapSm(),
            if (_groupByActivity) ...[
              ...controller.remindersByActivity.entries.map((entry) {
                final activityName = entry.key;
                final list = entry.value;

                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final tomorrow = today.add(const Duration(days: 1));

                final activeToday = list.where((r) =>
                    r.scheduledDateTime.year == today.year &&
                    r.scheduledDateTime.month == today.month &&
                    r.scheduledDateTime.day == today.day &&
                    !r.scheduledDateTime.isBefore(now)
                ).toList();

                final activeTomorrow = list.where((r) =>
                    r.scheduledDateTime.year == tomorrow.year &&
                    r.scheduledDateTime.month == tomorrow.month &&
                    r.scheduledDateTime.day == tomorrow.day
                ).toList();

                if (activeToday.isEmpty && activeTomorrow.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activityName, style: AppTheme.headingSmall),
                    const VGapSm(),
                    if (activeToday.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                        child: Text("Today", style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
                      ),
                      _buildReminderList(context, activeToday, controller, showActivityName: false),
                      const VGapSm(),
                    ],
                    if (activeTomorrow.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                        child: Text("Tomorrow", style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                      _buildReminderList(context, activeTomorrow, controller, showActivityName: false),
                      const VGapSm(),
                    ],
                    const VGapMd(),
                  ],
                );
              }),
              if (controller.passedReminders.isNotEmpty) ...[
                Text("Passed Today", style: AppTheme.headingSmall.copyWith(color: AppTheme.warningColor)),
                const VGapSm(),
                _buildReminderList(context, controller.passedReminders, controller, isPassed: true, showActivityName: true),
                const VGapMd(),
              ],
            ] else ...[
              if (controller.todayReminders.isNotEmpty) ...[
                Text("Today's Reminders", style: AppTheme.headingSmall),
                const VGapSm(),
                _buildReminderList(context, controller.todayReminders, controller),
                const VGapMd(),
              ],
              if (controller.passedReminders.isNotEmpty) ...[
                Text("Passed Today", style: AppTheme.headingSmall.copyWith(color: AppTheme.warningColor)),
                const VGapSm(),
                _buildReminderList(context, controller.passedReminders, controller, isPassed: true),
                const VGapMd(),
              ],
              if (controller.tomorrowReminders.isNotEmpty) ...[
                Text("Tomorrow's Reminders", style: AppTheme.headingSmall),
                const VGapSm(),
                _buildReminderList(context, controller.tomorrowReminders, controller),
                const VGapMd(),
              ],
            ],
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
