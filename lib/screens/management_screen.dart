import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../models/budget_item.dart';
import '../widgets/budget_tab.dart';
import '../widgets/milestones_tab.dart';
import '../widgets/add_milestone_task_sheet.dart';
import '../widgets/add_transaction_sheet.dart';
import '../services/activity_service.dart';
import '../services/budget_service.dart';

// ==================== LOCAL DATA MODELS ====================

class DietItem {
  String foodName;
  int calories;
  String mealType;

  DietItem({
    required this.foodName,
    required this.calories,
    required this.mealType,
  });
}

class ReminderItem {
  String title;
  String time;
  bool isActive;

  ReminderItem({
    required this.title,
    required this.time,
    this.isActive = true,
  });
}

class StudySession {
  String topic;
  int durationMinutes;
  DateTime date;

  StudySession({
    required this.topic,
    required this.durationMinutes,
    required this.date,
  });
}

// ==================== MANAGEMENT SCREEN ====================

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final ActivityService _activityService = ActivityService();
  final BudgetService _budgetService = BudgetService();

  // Current active category (0: Milestones, 1: Budget, 2: Diet, 3: Reminders, 4: Study)
  int _activeCategoryIndex = 0;
  bool _isMenuOpen = false;

  // Selected milestone activity
  Activity? _selectedMilestoneActivity;
  List<Activity> _milestoneActivities = [];
  bool _shouldSelectDefaultMilestone = true;

  // Selected budget category
  BudgetItem? _selectedBudget;

  late final Stream<List<Activity>> _activitiesStream = _activityService.getActivitiesStream();

  final List<DietItem> _dietItems = [
    DietItem(foodName: 'Oatmeal with Berries', calories: 350, mealType: 'Breakfast'),
    DietItem(foodName: 'Grilled Chicken Salad', calories: 450, mealType: 'Lunch'),
    DietItem(foodName: 'Protein Shake', calories: 200, mealType: 'Snack'),
  ];

  final List<ReminderItem> _reminders = [
    ReminderItem(title: 'Drink water', time: '08:00 AM', isActive: true),
    ReminderItem(title: 'Gym session', time: '06:00 PM', isActive: false),
    ReminderItem(title: 'Take vitamins', time: '09:00 PM', isActive: true),
  ];

  final List<StudySession> _studySessions = [
    StudySession(topic: 'Algorithms (Trees & Graphs)', durationMinutes: 90, date: DateTime.now().subtract(const Duration(days: 1))),
    StudySession(topic: 'Flutter State Management', durationMinutes: 60, date: DateTime.now()),
  ];

  // Category Configuration
  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'Milestones',
      'icon': Icons.flag_outlined,
      'activeIcon': Icons.flag,
    },
    {
      'label': 'Budget',
      'icon': Icons.account_balance_wallet_outlined,
      'activeIcon': Icons.account_balance_wallet,
    },
    {
      'label': 'Diet',
      'icon': Icons.restaurant_outlined,
      'activeIcon': Icons.restaurant,
    },
    {
      'label': 'Reminders',
      'icon': Icons.notifications_active_outlined,
      'activeIcon': Icons.notifications_active,
    },
    {
      'label': 'Study',
      'icon': Icons.school_outlined,
      'activeIcon': Icons.school,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: false,
        title: 'Manage Life',
        padding: EdgeInsets.zero,
        actions: [
          _buildMenuToggleButton(),
        ],
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Scrollable Active Content
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 16,
                      bottom: bottomPadding + 100,
                    ),
                    child: _buildActiveContent(),
                  ),
                ),
                
                // 2. Tap-to-Close Menu Barrier
                if (_isMenuOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _isMenuOpen = false;
                        });
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                
                // 3. Overlaid Collapsible Category Menu
                Positioned(
                  top: -16,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleCategoryMenu(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _activeCategoryIndex == 0 && _selectedMilestoneActivity != null
          ? Padding(
              padding: EdgeInsets.only(bottom: bottomPadding + 16),
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: () => _showAddSubTaskSheet(context),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            )
          : (_activeCategoryIndex == 1 && _selectedBudget != null)
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding + 16),
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () => _showAddTransactionSheet(context),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                )
              : null,
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMenuToggleButton() {
    final selectedCategory = _categories[_activeCategoryIndex];

    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isMenuOpen
              ? AppTheme.primaryColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: _isMenuOpen
                ? AppTheme.primaryColor.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              selectedCategory['activeIcon'] as IconData,
              color: _isMenuOpen ? AppTheme.primaryLight : Colors.white,
              size: 20,
            ),
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceColor,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isMenuOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleCategoryMenu() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: _isMenuOpen ? null : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: _isMenuOpen
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(
                    alpha: _isMenuOpen ? 0.85 : 0.0,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: _isMenuOpen ? 0.08 : 0.0,
                    ),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const VGapMd(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isMenuOpen ? 1.0 : 0.0,
                      child: _buildCategorySelector(),
                    ),
                    const VGapMd(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 16;
          final itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;

          return Wrap(
            spacing: spacing,
            runSpacing: 14,
            children: List.generate(_categories.length, (index) {
              final isSelected = _activeCategoryIndex == index;
              final cat = _categories[index];
              return SizedBox(
                width: itemWidth,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _activeCategoryIndex = index;
                    if (index == 0) {
                      _shouldSelectDefaultMilestone = true;
                    }
                  }),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                        ),
                        child: Icon(
                           isSelected ? cat['activeIcon'] : cat['icon'],
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['label'],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildActiveContent() {
    switch (_activeCategoryIndex) {
      case 0:
        return _buildMilestonesContent();
      case 1:
        return BudgetTab(
          selectedBudgetId: _selectedBudget?.id,
          onBudgetChanged: (budget) {
            setState(() {
              _selectedBudget = budget;
            });
          },
        );
      case 2:
        return _buildDietContent();
      case 3:
        return _buildRemindersContent();
      case 4:
        return _buildStudyContent();
      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------- 1. MILESTONES --------------------

  Widget _buildMilestonesContent() {
    return StreamBuilder<List<Activity>>(
      stream: _activitiesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final allActivities = snapshot.data ?? [];
        _milestoneActivities = allActivities
            .where((a) => a.trackingType == 'milestone')
            .toList();
        final milestoneActivities = _milestoneActivities;
        
        final activeMilestones = milestoneActivities.where((a) => a.checked).toList();
        final selectedActivity = _getDefaultMilestoneActivity(activeMilestones);

        if (selectedActivity != null &&
            _selectedMilestoneActivity?.id != selectedActivity.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedMilestoneActivity = selectedActivity;
                _shouldSelectDefaultMilestone = false;
              });
            }
          });
        }

        return StreamBuilder<List<Task>>(
          stream: _activityService.getSubTasksStream(),
          builder: (context, subtaskSnapshot) {
            final subTasks = subtaskSnapshot.data ?? [];

            return MilestonesTab(
              milestoneActivities: milestoneActivities,
              selectedActivity: _selectedMilestoneActivity,
              subTasks: subTasks,
              isLoadingSubTasks: subtaskSnapshot.connectionState == ConnectionState.waiting && !subtaskSnapshot.hasData,
              onActivitySelected: (activity) {
                setState(() {
                  _selectedMilestoneActivity = activity;
                  _shouldSelectDefaultMilestone = false;
                });
              },
              onToggleSubTask: _toggleSubTask,
              onToggleActivity: (activity, checked) async {
                await _activityService.toggleActivity(activity.id, checked);
              },
              onUpdateActivitySymbols: (activity, symbolType, symbolValue, category) async {
                await _activityService.updateActivitySymbols(
                  activity.id,
                  symbolType: symbolType,
                  symbolValue: symbolValue,
                  category: category,
                );
              },
              onAddSubTask: (activity, name, timestamp) async {
                await _activityService.createSubTask(activity.id, name, timestamp, false);
              },
              onDeleteSubTask: (task) async {
                await _activityService.deleteSubTask(task.id);
              },
              onEditSubTask: (task) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddMilestoneSubTaskSheet(
                    milestones: _milestoneActivities,
                    editTask: task,
                    onEditSubTask: (updatedTask) async {
                      await _activityService.updateSubTask(updatedTask);
                    },
                  ),
                );
              },
              onUpdateSubTaskSymbols: (task, symbolType, symbolValue) async {
                await _activityService.updateSubTaskSymbols(
                  task.id,
                  symbolType: symbolType,
                  symbolValue: symbolValue,
                );
              },
            );
          },
        );
      },
    );
  }

  Activity? _getDefaultMilestoneActivity(List<Activity> milestoneActivities) {
    if (milestoneActivities.isEmpty) {
      return null;
    }

    if (_shouldSelectDefaultMilestone) {
      return milestoneActivities.first;
    }

    for (final activity in milestoneActivities) {
      if (activity.id == _selectedMilestoneActivity?.id) {
        return activity;
      }
    }

    return milestoneActivities.first;
  }

  Future<void> _addMilestoneSubTask(Activity activity, String subTaskName, DateTime timestamp) async {
    await _activityService.createSubTask(
      activity.id,
      subTaskName,
      timestamp,
      false,
    );
  }

  Future<void> _toggleSubTask(Task task, bool checked) async {
    List<SubTask> updatedSubTasks = task.subTasks;
    if (checked != task.checked) {
      updatedSubTasks = task.subTasks
          .map((subTask) => subTask.copyWith(checked: checked))
          .toList();
    }
    final updated = task.copyWith(
      checked: checked,
      completionTime: checked ? DateTime.now() : null,
      subTasks: updatedSubTasks,
    );
    await _activityService.updateSubTask(updated);
  }

  void _showAddSubTaskSheet(BuildContext context) {
    final activity = _selectedMilestoneActivity;
    if (activity == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMilestoneSubTaskSheet(
        milestones: _milestoneActivities,
        onAddSubTask: _addMilestoneSubTask,
      ),
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    final budget = _selectedBudget;
    if (budget == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        budgetId: budget.id,
        categoryName: budget.category,
        onAddTransaction: (tag, desc, amount, date) async {
          await _budgetService.addExpenseToBudget(budget.id, tag, desc, amount, timestamp: date);
        },
      ),
    );
  }

  // -------------------- 2. BUDGET (MODULARIZED OUT TO BUDGET_TAB) --------------------

  // -------------------- 3. DIET --------------------

  Widget _buildDietContent() {
    int totalCalories = 0;
    for (var d in _dietItems) {
      totalCalories += d.calories;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Diet & Nutrition Log', style: AppTheme.headingSmall),
            ElevatedButton.icon(
              onPressed: _showAddDietDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const VGapSm(),
        Card(
          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Calorie Intake', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$totalCalories kcal', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryLight)),
              ],
            ),
          ),
        ),
        const VGapSm(),
        if (_dietItems.isEmpty)
          _buildEmptyState('No diet logs added today.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dietItems.length,
            itemBuilder: (context, index) {
              final meal = _dietItems[index];
              return Card(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  dense: true,
                  title: Text(meal.foodName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(meal.mealType, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${meal.calories} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                        onPressed: () {
                          setState(() {
                            _dietItems.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddDietDialog() {
    final foodController = TextEditingController();
    final caloriesController = TextEditingController();
    String selectedMealType = 'Breakfast';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Log Food Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: foodController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Apple, Chicken Breast',
                      labelText: 'Food Name',
                    ),
                  ),
                  const VGapSm(),
                  TextField(
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Calories in kcal',
                      labelText: 'Calories',
                    ),
                  ),
                  const VGapSm(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Meal Type:', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        dropdownColor: AppTheme.surfaceColor,
                        value: selectedMealType,
                        items: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedMealType = val;
                            });
                          }
                        },
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
                    final cal = int.tryParse(caloriesController.text) ?? 0;
                    if (foodController.text.isNotEmpty && cal > 0) {
                      setState(() {
                        _dietItems.add(DietItem(
                          foodName: foodController.text,
                          calories: cal,
                          mealType: selectedMealType,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Log', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------- 4. REMINDERS --------------------

  Widget _buildRemindersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Reminders', style: AppTheme.headingSmall),
            ElevatedButton.icon(
              onPressed: _showAddReminderDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const VGapSm(),
        if (_reminders.isEmpty)
          _buildEmptyState('No reminders active.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reminders.length,
            itemBuilder: (context, index) {
              final reminder = _reminders[index];
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
                      color: Colors.white,
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
                          setState(() {
                            reminder.isActive = val;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                        onPressed: () {
                          setState(() {
                            _reminders.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
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
                      setState(() {
                        _reminders.add(ReminderItem(
                          title: titleController.text,
                          time: selectedTime.format(context),
                        ));
                      });
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

  // -------------------- 5. STUDY SESSIONS --------------------

  Widget _buildStudyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Study Sessions', style: AppTheme.headingSmall),
            ElevatedButton.icon(
              onPressed: _showAddStudyDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const VGapSm(),
        if (_studySessions.isEmpty)
          _buildEmptyState('No study sessions recorded.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _studySessions.length,
            itemBuilder: (context, index) {
              final session = _studySessions[index];
              return Card(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryLight),
                  title: Text(session.topic, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${DateFormat('yyyy-MM-dd').format(session.date)} • ${session.durationMinutes} mins',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                    onPressed: () {
                      setState(() {
                        _studySessions.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddStudyDialog() {
    final topicController = TextEditingController();
    final durationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Record Study Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Mathematics, Compiler Design',
                  labelText: 'Topic',
                ),
              ),
              const VGapSm(),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter duration in minutes',
                  labelText: 'Duration (mins)',
                ),
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
                final duration = int.tryParse(durationController.text) ?? 0;
                if (topicController.text.isNotEmpty && duration > 0) {
                  setState(() {
                    _studySessions.add(StudySession(
                      topic: topicController.text,
                      durationMinutes: duration,
                      date: DateTime.now(),
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Record', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // -------------------- HELPER EMPTY WIDGET --------------------

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
