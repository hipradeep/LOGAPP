import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_provider.dart';
import '../widgets/full_screen_page.dart';
import '../controllers/water_log_controller.dart';
import '../services/notification_service.dart';

class WaterLogScreen extends StatefulWidget {
  const WaterLogScreen({super.key});

  @override
  State<WaterLogScreen> createState() => _WaterLogScreenState();
}

class _WaterLogScreenState extends State<WaterLogScreen> {
  int _selectedTab = 0;
  late final WaterLogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WaterLogController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<WaterLogController>(
      notifier: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FullScreenPage(
            title: 'Water Log',
            showBackButton: true,
            children: [
              _buildCircularTabs(context),
              const VGapMd(),
              if (_controller.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildActiveTab(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircularTabs(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildTabButton(0, Icons.local_drink_rounded, 'Intake'),
        const HGapMd(),
        _buildTabButton(1, Icons.history_rounded, 'History'),
        const HGapMd(),
        _buildTabButton(2, Icons.notifications_rounded, 'Reminders'),
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isActive = _selectedTab == index;
    final primaryAccent = AppTheme.primaryAccentColor(context);
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.primaryColor
                  : AppTheme.surface(context).withValues(alpha: 0.35),
              border: Border.all(
                color: isActive
                    ? primaryAccent.withValues(alpha: 0.6)
                    : AppTheme.borderColor(context),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppTheme.textSecondaryColor(context),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.bodyMicro.copyWith(
              color: isActive ? primaryAccent : AppTheme.textSecondaryColor(context),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context) {
    return IndexedStack(
      index: _selectedTab,
      children: const [
        _WaterIntakeTab(),
        _WaterHistoryTab(),
        _WaterRemindersTab(),
      ],
    );
  }
}

// ==================== TABS DEFINITIONS ====================

class _WaterIntakeTab extends StatelessWidget {
  const _WaterIntakeTab();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return const Column(
      children: [
        VGapMd(),
        _WaterGoalHeader(),
        VGapSm(),
        _WaterGoalRing(),
        VGapLg(),
        _WaterGoalControls(),
        VGapXl(),
      ],
    );
  }
}

class _WaterGoalHeader extends StatelessWidget {
  const _WaterGoalHeader();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      'Daily Hydration Goal'.toUpperCase(),
      style: AppTheme.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
      ),
    );
  }
}

class _WaterGoalRing extends StatelessWidget {
  const _WaterGoalRing();

  void _showChangeGoalDialog(BuildContext context, WaterLogController controller) {
    final textController = TextEditingController(text: controller.settings.dailyGoal.toInt().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Set Daily Goal',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. 2000',
            suffixText: 'ml',
            filled: true,
            fillColor: AppTheme.subtleFillColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(textController.text);
              if (amount != null && amount > 0) {
                controller.updateGoal(amount);
              }
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryAccentColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final controller = AppProvider.watch<WaterLogController>(context);

    return Center(
      child: Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surface(context).withValues(alpha: 0.15),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glowing background circle
            Container(
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.borderColor(context).withValues(alpha: 0.2),
                  width: 14,
                ),
              ),
            ),
            // Circular Progress
            SizedBox(
              width: 210,
              height: 210,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 14,
                backgroundColor: Colors.transparent,
                color: Colors.blue.shade400,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Inner information Column
            GestureDetector(
              onTap: () => _showChangeGoalDialog(context, controller),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '💧',
                    style: TextStyle(fontSize: 44),
                  ),
                  const VGapXs(),
                  Text(
                    '${controller.settings.dailyGoal.toInt()} ml',
                    style: AppTheme.headingMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterGoalControls extends StatelessWidget {
  const _WaterGoalControls();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final controller = AppProvider.watch<WaterLogController>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Minus circular button
        GestureDetector(
          onTap: () {
            final currentGoal = controller.settings.dailyGoal;
            if (currentGoal > 250) {
              final newGoal = currentGoal - 250;
              controller.updateGoal(newGoal);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Decreased daily target goal to ${newGoal.toInt()} ml.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Daily target goal cannot be less than 250 ml.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.waterLogMinusButtonColor(context),
              border: Border.all(
                color: Colors.blue.shade200.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.remove_rounded,
              color: Colors.blue,
              size: 24,
            ),
          ),
        ),
        const HGapMd(),
        // Plus 250ml pill button
        GestureDetector(
          onTap: () {
            final currentGoal = controller.settings.dailyGoal;
            final newGoal = currentGoal + 250;
            controller.updateGoal(newGoal);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Increased daily target goal to ${newGoal.toInt()} ml.'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade400.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '+ 250 ml',
              style: AppTheme.headingSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaterHistoryTab extends StatefulWidget {
  const _WaterHistoryTab();

  @override
  State<_WaterHistoryTab> createState() => _WaterHistoryTabState();
}

class _WaterHistoryTabState extends State<_WaterHistoryTab> {
  late DateTime _selectedDate;
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentPage = 2; // Start on the newest month (June, index 2)
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final controller = AppProvider.watch<WaterLogController>(context);

    // Get current month, and 2 months prior (3 months total) in chronological order
    final now = DateTime.now();
    final List<DateTime> monthsToRender = [];
    for (int i = 2; i >= 0; i--) {
      monthsToRender.add(DateTime(now.year, now.month - i, 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VGapMd(),
        _HistoryCalendarPageView(
          pageController: _pageController,
          currentPage: _currentPage,
          monthsToRender: monthsToRender,
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
            });
          },
          dailyTotals: controller.dailyTotals,
          dailyGoal: controller.settings.dailyGoal,
        ),
        const VGapLg(),
        _SelectedDayLogsSection(
          selectedDate: _selectedDate,
          controller: controller,
        ),
      ],
    );
  }
}

class _HistoryCalendarPageView extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final List<DateTime> monthsToRender;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onPageChanged;
  final Map<String, double> dailyTotals;
  final double dailyGoal;

  const _HistoryCalendarPageView({
    required this.pageController,
    required this.currentPage,
    required this.monthsToRender,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPageChanged,
    required this.dailyTotals,
    required this.dailyGoal,
  });

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getFirstDayOffset(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday - 1;
  }

  int _getWeeksInMonth(int year, int month) {
    final days = _getDaysInMonth(year, month);
    final offset = _getFirstDayOffset(year, month);
    return ((days + offset) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return ListenableBuilder(
      listenable: pageController,
      builder: (context, _) {
        final double page = pageController.hasClients
            ? (pageController.page ?? currentPage.toDouble())
            : currentPage.toDouble();

        final int index1 = page.floor().clamp(0, monthsToRender.length - 1);
        final int index2 = page.ceil().clamp(0, monthsToRender.length - 1);

        final int weeks1 = _getWeeksInMonth(monthsToRender[index1].year, monthsToRender[index1].month);
        final int weeks2 = _getWeeksInMonth(monthsToRender[index2].year, monthsToRender[index2].month);
        final int weeks = weeks1 > weeks2 ? weeks1 : weeks2;
        final double dynamicHeight = 160.0 + (weeks * 36.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: dynamicHeight,
              child: PageView.builder(
                controller: pageController,
                onPageChanged: onPageChanged,
                itemCount: monthsToRender.length,
                itemBuilder: (context, index) {
                  final monthDate = monthsToRender[index];
                  return _buildCalendarGrid(context, monthDate.year, monthDate.month);
                },
              ),
            ),
            const VGapSm(),
            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(monthsToRender.length, (idx) {
                final isActive = currentPage == idx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 12 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive
                        ? AppTheme.primaryAccentColor(context)
                        : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    int year,
    int month,
  ) {
    final daysInMonth = _getDaysInMonth(year, month);
    final offset = _getFirstDayOffset(year, month);
    final totalItems = daysInMonth + offset;
    final textSecondary = AppTheme.textSecondaryColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime(year, month)),
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  onPressed: currentPage > 0
                      ? () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: currentPage > 0
                      ? AppTheme.primaryAccentColor(context)
                      : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
                const HGapMd(),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  onPressed: currentPage < 2
                      ? () {
                          pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: currentPage < 2
                      ? AppTheme.primaryAccentColor(context)
                      : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ),
        const VGapMd(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Center(child: Text('Mo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('Tu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('We', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('Th', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('Fr', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('Sa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
            Expanded(child: Center(child: Text('Su', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)))),
          ],
        ),
        const VGapSm(),
        Column(
          children: List.generate((totalItems / 7).ceil(), (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (dayIndex) {
                  final index = weekIndex * 7 + dayIndex;
                  if (index >= totalItems || index < offset) {
                    return const Expanded(child: SizedBox.shrink());
                  }
                  final day = index - offset + 1;
                  final date = DateTime(year, month, day);
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  final total = dailyTotals[key] ?? 0.0;

                  final bool isSelected = selectedDate.day == day &&
                      selectedDate.month == month &&
                      selectedDate.year == year;
                  final bool isToday = date.day == DateTime.now().day &&
                      date.month == DateTime.now().month &&
                      date.year == DateTime.now().year;

                  final progress = (total / dailyGoal).clamp(0.0, 1.0);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onDateSelected(date),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Circular progress indicator background & value
                              if (total > 0.0)
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2.5,
                                    backgroundColor: AppTheme.borderColor(context).withValues(alpha: 0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      total >= dailyGoal
                                          ? AppTheme.successColor
                                          : AppTheme.primaryAccentColor(context),
                                    ),
                                  ),
                                )
                              else
                                // Empty state circle border
                                SizedBox.expand(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isToday
                                            ? AppTheme.primaryAccentColor(context)
                                            : AppTheme.borderColor(context).withValues(alpha: 0.5),
                                        width: isToday ? 1.5 : 1,
                                      ),
                                    ),
                                  ),
                                ),
                              // Active Selection Ring
                              if (isSelected)
                                SizedBox.expand(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primaryColor,
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                ),
                              // Day Number Text
                              Text(
                                day.toString(),
                                style: AppTheme.bodyMicro.copyWith(
                                  fontWeight: (isToday || isSelected || total > 0.0)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : (isToday
                                          ? AppTheme.primaryAccentColor(context)
                                          : AppTheme.textPrimaryColor(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SelectedDayLogsSection extends StatelessWidget {
  final DateTime selectedDate;
  final WaterLogController controller;

  const _SelectedDayLogsSection({
    required this.selectedDate,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final dailyGoal = controller.settings.dailyGoal;
    final selectedDayLogs = controller.logs.where((entry) {
      return entry.timestamp.year == selectedDate.year &&
             entry.timestamp.month == selectedDate.month &&
             entry.timestamp.day == selectedDate.day;
    }).toList();
    final selectedDaySum = selectedDayLogs.fold<double>(0.0, (sum, entry) => sum + entry.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LOGS FOR ${DateFormat('MMMM d, yyyy').format(selectedDate).toUpperCase()}',
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
          ),
        ),
        const VGapMd(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Total:',
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${selectedDaySum.toInt()} / ${dailyGoal.toInt()} ml',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selectedDaySum >= dailyGoal ? AppTheme.successColor : Colors.blue.shade300,
                    ),
                  ),
                ],
              ),
              if (selectedDayLogs.isEmpty) ...[
                const VGapMd(),
                Center(
                  child: Text(
                    'No intake logged on this day.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ] else ...[
                const VGapMd(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero, // CRITICAL: Avoid nested padding gap
                  itemCount: selectedDayLogs.length,
                  itemBuilder: (context, idx) {
                    final entry = selectedDayLogs[idx];
                    final timeStr = DateFormat.jm().format(entry.timestamp);
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: idx == 0
                              ? BorderSide.none
                              : BorderSide(
                                  color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                                ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop, size: 14, color: Colors.blue),
                              const HGapSm(),
                              Text(timeStr, style: AppTheme.bodyMedium),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${entry.amount.toInt()} ml',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              const HGapSm(),
                              GestureDetector(
                                onTap: () => controller.deleteIntake(entry.id),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppTheme.errorColor,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const VGapXl(),
      ],
    );
  }
}

class _WaterRemindersTab extends StatelessWidget {
  const _WaterRemindersTab();

  Future<void> _selectReminderTime(BuildContext context, WaterLogController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formattedTime = DateFormat.jm().format(dt);
      controller.addReminderTime(formattedTime);
    }
  }

  Widget _buildFrequencyChip(
    BuildContext context,
    WaterLogController controller,
    int value,
    String label,
  ) {
    final isSelected = controller.settings.hourlyInterval == value;
    final primaryAccent = AppTheme.primaryAccentColor(context);
    return ChoiceChip(
      label: Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          color: isSelected ? Colors.white : AppTheme.textSecondaryColor(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          controller.updateHourlyInterval(value);
        } else {
          controller.updateHourlyInterval(0); // Deselect back to Custom/None
        }
      },
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surface(context).withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primaryAccent.withValues(alpha: 0.5) : AppTheme.borderColor(context),
        ),
      ),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final controller = AppProvider.watch<WaterLogController>(context);
    final settings = controller.settings;

    // Generate active interval times to filter them out of the custom list display
    final List<String> generatedIntervalTimes = [];
    if (settings.hourlyInterval > 0) {
      final startHour = 8; // 8:00 AM
      final endHour = 20; // 8:00 PM
      for (int hour = startHour; hour <= endHour; hour += 1) {
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, hour, 0);
        generatedIntervalTimes.add(DateFormat('hh:mm a').format(dt));
      }
    }

    String normalize(String t) {
      try {
        final parsed = NotificationService.parseTimeString(t);
        return DateFormat('hh:mm a').format(parsed);
      } catch (_) {
        return t;
      }
    }

    // Filter display list to only show custom (non-interval-generated) alarms
    final displayTimes = settings.reminderTimes
        .where((time) => !generatedIntervalTimes.contains(normalize(time)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VGapMd(),
        // Global toggle card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: Colors.blue),
                    const HGapMd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Drink Water Alerts',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Receive reminders during the day',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const HGapMd(),
              Switch(
                value: settings.notificationsEnabled,
                activeThumbColor: AppTheme.primaryAccentColor(context),
                onChanged: controller.toggleNotifications,
              ),
            ],
          ),
        ),
        if (settings.notificationsEnabled) ...[
          const VGapLg(),
          Text(
            'ALERT INTERVAL FREQUENCY',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
            ),
          ),
          const VGapSm(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFrequencyChip(context, controller, 1, 'Every 1 Hour'),
                const HGapSm(),
                _buildFrequencyChip(context, controller, 2, 'Every 2 Hours'),
                const HGapSm(),
                _buildFrequencyChip(context, controller, 3, 'Every 3 Hours'),
              ],
            ),
          ),
          if (settings.hourlyInterval > 0) ...[
            const VGapMd(),
            // Auto-alert card for interval alerts
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface(context).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                  const HGapMd(),
                  Expanded(
                    child: Text(
                      'Alerts will automatically trigger every ${settings.hourlyInterval} hour${settings.hourlyInterval > 1 ? "s" : ""} between 8:00 AM and 8:00 PM in addition to your custom times.',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const VGapMd(),
          // Alerts list title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALERT TIMES',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          if (displayTimes.isEmpty) ...[
            const VGapMd(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alarm_off_rounded,
                    size: 48,
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.35),
                  ),
                  const VGapSm(),
                  Text(
                    'No custom alerts scheduled.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                    ),
                  ),
                  const VGapLg(),
                  OutlinedButton.icon(
                    onPressed: () => _selectReminderTime(context, controller),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Custom Time'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryAccentColor(context),
                      side: BorderSide(color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const VGapSm(),
            // Alerts ListView
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: displayTimes.length,
              itemBuilder: (context, index) {
                final time = displayTimes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.blue, size: 20),
                          const HGapMd(),
                          Text(
                            time,
                            style: AppTheme.headingSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                        onPressed: () => controller.removeReminderTime(time),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
            const VGapMd(),
            // The Add Custom button always goes at the bottom of the section
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _selectReminderTime(context, controller),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Custom Time'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryAccentColor(context),
                  side: BorderSide(color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],

        ] else ...[
          const VGapLg(),
          // Warnings if alerts are disabled
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                const HGapMd(),
                Expanded(
                  child: Text(
                    'Reminders are currently turned off. Toggle the switch above to activate your daily alerts.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.amber.shade200,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const VGapXl(),
      ],
    );
  }
}
