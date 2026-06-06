import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../models/activity.dart';
import '../models/sub_task.dart';
import '../services/firebase_service.dart';
import '../widgets/milestones_tab.dart';

// ==================== LOCAL DATA MODELS ====================

class BudgetItem {
  String category;
  double limit;
  double spent;

  BudgetItem({
    required this.category,
    required this.limit,
    required this.spent,
  });
}

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
  final FirebaseService _firebaseService = FirebaseService();

  // Current active category (0: Milestones, 1: Budget, 2: Diet, 3: Reminders, 4: Study)
  int _activeCategoryIndex = 0;

  // Selected milestone activity
  Activity? _selectedMilestoneActivity;

  final List<BudgetItem> _budgets = [
    BudgetItem(category: 'Food & Groceries', limit: 200, spent: 145),
    BudgetItem(category: 'Transport', limit: 80, spent: 40),
    BudgetItem(category: 'Entertainment', limit: 100, spent: 110),
  ];

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
        isScrollable: true,
        title: 'Manage Life',
        padding: EdgeInsets.zero,
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
          // Horizontal Selector Bar (Circular Buttons)
          _buildCategorySelector(),
          const VGapMd(),
          
          // Active List Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildActiveContent(),
          ),
          
          // Padding to avoid overlap with bottom navigation bar
          SizedBox(height: bottomPadding + 100),
        ],
      ),
    );
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _activeCategoryIndex == index;
          final cat = _categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeCategoryIndex = index),
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
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label'],
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
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
        return _buildBudgetContent();
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
      stream: _firebaseService.getActivitiesStream(),
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
        final milestoneActivities = allActivities
            .where((a) => a.trackingType == 'milestone')
            .toList();

        // Auto-select first milestone activity if none selected
        if (_selectedMilestoneActivity == null && milestoneActivities.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedMilestoneActivity = milestoneActivities.first;
              });
            }
          });
        }

        // Fetch subtasks for the selected activity
        if (_selectedMilestoneActivity != null) {
          return StreamBuilder<List<SubTask>>(
            stream: _firebaseService.getSubTasksForActivityStream(_selectedMilestoneActivity!.id),
            builder: (context, subtaskSnapshot) {
              final subTasks = subtaskSnapshot.data ?? [];

              return MilestonesTab(
                milestoneActivities: milestoneActivities,
                selectedActivity: _selectedMilestoneActivity,
                subTasks: subTasks,
                onActivitySelected: (activity) {
                  setState(() {
                    _selectedMilestoneActivity = activity;
                  });
                },
              );
            },
          );
        }

        return MilestonesTab(
          milestoneActivities: milestoneActivities,
          selectedActivity: _selectedMilestoneActivity,
          subTasks: const [],
          onActivitySelected: (activity) {
            setState(() {
              _selectedMilestoneActivity = activity;
            });
          },
        );
      },
    );
  }

  // -------------------- 2. BUDGET --------------------

  Widget _buildBudgetContent() {
    double totalLimit = 0;
    double totalSpent = 0;
    for (var b in _budgets) {
      totalLimit += b.limit;
      totalSpent += b.spent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Budget', style: AppTheme.headingSmall),
            ElevatedButton.icon(
              onPressed: _showAddBudgetDialog,
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
        // Total Summary Card
        Card(
          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spent', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('\$${totalSpent.toStringAsFixed(1)}', style: AppTheme.headingMedium),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Limit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('\$${totalLimit.toStringAsFixed(1)}', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryLight)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const VGapSm(),
        if (_budgets.isEmpty)
          _buildEmptyState('No budget limits added yet.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _budgets.length,
            itemBuilder: (context, index) {
              final budget = _budgets[index];
              final percent = budget.limit > 0 ? (budget.spent / budget.limit).clamp(0.0, 1.0) : 0.0;
              final isOverBudget = budget.spent > budget.limit;

              return Card(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(budget.category, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                            onPressed: () {
                              setState(() {
                                _budgets.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent: \$${budget.spent.toStringAsFixed(1)}',
                            style: TextStyle(color: isOverBudget ? AppTheme.errorColor : AppTheme.textSecondary, fontSize: 12),
                          ),
                          Text(
                            'Limit: \$${budget.limit.toStringAsFixed(1)}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget ? AppTheme.errorColor : AppTheme.primaryColor,
                          ),
                          minHeight: 6,
                        ),
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

  void _showAddBudgetDialog() {
    final catController = TextEditingController();
    final limitController = TextEditingController();
    final spentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Budget Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: catController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Groceries, Transport',
                  labelText: 'Category Name',
                ),
              ),
              const VGapSm(),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter limit (e.g. 150)',
                  labelText: 'Budget Limit',
                ),
              ),
              const VGapSm(),
              TextField(
                controller: spentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter spent amount (e.g. 50)',
                  labelText: 'Already Spent',
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
                final limit = double.tryParse(limitController.text) ?? 0.0;
                final spent = double.tryParse(spentController.text) ?? 0.0;
                if (catController.text.isNotEmpty && limit > 0) {
                  setState(() {
                    _budgets.add(BudgetItem(
                      category: catController.text,
                      limit: limit,
                      spent: spent,
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
  }

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
