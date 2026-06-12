import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/cache_service.dart';
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
import 'activity_details_screen.dart';
import '../services/activity_service.dart';
import '../services/budget_service.dart';
import '../controllers/milestones_controller.dart';
import '../widgets/app_provider.dart';

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
  final CacheService _cacheService = CacheService();

  // Current active category (0: Milestones, 1: Budget, 2: Diet, 3: Reminders, 4: Study)
  int _activeCategoryIndex = 0;
  late final MilestonesController _milestonesController;

  @override
  void initState() {
    super.initState();
    _milestonesController = MilestonesController();
    _loadCachedTab();
  }

  @override
  void dispose() {
    _milestonesController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedTab() async {
    final cachedIndex = await _cacheService.getSelectedTab();
    if (mounted && cachedIndex >= 0 && cachedIndex < _categories.length) {
      setState(() {
        _activeCategoryIndex = cachedIndex;
      });
    }
  }

  bool _isMenuOpen = false;
  int? _hoveredCategoryIndex;
  double _accumulatedDragDelta = 0.0;
  bool _hasTriggeredDrag = false;

  // Selected milestone activity
  Activity? _selectedMilestoneActivity;
  List<Activity> _milestoneActivities = [];

  // Selected budget category
  BudgetItem? _selectedBudget;


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
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: false,
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
                      top: 88,
                      bottom: bottomPadding + 100 + viewInsetsBottom,
                    ),
                    child: _buildActiveContent(),
                  ),
                ),
                
                // 2. Custom App Bar / Header (drawn behind dropdown but on top of scrollable content)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCustomHeader(context),
                ),
                
                // 3. Tap-to-Close Menu Barrier
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
                
                // 4. Overlaid Collapsible Category Menu
                Positioned(
                  top: 5,
                  right: 17,
                  child: _buildCollapsibleCategoryMenu(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _activeCategoryIndex == 0 && _milestoneActivities.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(bottom: bottomPadding + 36),
              child: _buildPremiumFAB(
                onPressed: () => _showAddSubTaskSheet(context),
              ),
            )
          : (_activeCategoryIndex == 1 && _selectedBudget != null)
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding + 36),
                  child: _buildPremiumFAB(
                    onPressed: () => _showAddTransactionSheet(context),
                  ),
                )
              : null,
    );
  }

  Widget _buildPremiumFAB({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            12,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _categories[_activeCategoryIndex]['label'] as String,
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildMenuToggleButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePanUpdate(double globalY) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final capsuleTop = statusBarHeight + 5;
    final localY = globalY - capsuleTop;

    if (localY >= 61 && localY < 61 + _categories.length * 52) {
      final idx = (localY - 61) ~/ 52;
      if (idx >= 0 && idx < _categories.length) {
        if (_hoveredCategoryIndex != idx) {
          setState(() {
            _hoveredCategoryIndex = idx;
          });
        }
      }
    } else {
      if (_hoveredCategoryIndex != null) {
        setState(() {
          _hoveredCategoryIndex = null;
        });
      }
    }
  }

  void _setActiveCategory(int index) {
    if (_activeCategoryIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeCategoryIndex = index;
        if (index == 0) {
          _shouldSelectDefaultMilestone = true;
        }
      });
      _cacheService.saveSelectedTab(index);
    }
  }

  void _handlePanEnd() {
    if (_hoveredCategoryIndex != null) {
      _setActiveCategory(_hoveredCategoryIndex!);
      setState(() {
        _isMenuOpen = false;
        _hoveredCategoryIndex = null;
      });
    } else {
      setState(() {
        _hoveredCategoryIndex = null;
      });
    }
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMenuToggleButton() {
    final selectedCategory = _categories[_activeCategoryIndex];

    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
      onPanStart: (details) {
        if (!_isMenuOpen) {
          _accumulatedDragDelta = 0.0;
          _hasTriggeredDrag = false;
        } else {
          setState(() {
            _hoveredCategoryIndex = null;
          });
        }
      },
      onPanUpdate: (details) {
        if (!_isMenuOpen) {
          if (!_hasTriggeredDrag) {
            _accumulatedDragDelta += details.delta.dy;
            const double threshold = 25.0; // slightly lower threshold for quick snapping
            if (_accumulatedDragDelta >= threshold) {
              // Swipe down -> next tab
              final nextIdx = (_activeCategoryIndex + 1) % _categories.length;
              _setActiveCategory(nextIdx);
              _hasTriggeredDrag = true;
              _accumulatedDragDelta = 0.0;
            } else if (_accumulatedDragDelta <= -threshold) {
              // Swipe up -> previous tab
              final prevIdx = (_activeCategoryIndex - 1 + _categories.length) % _categories.length;
              _setActiveCategory(prevIdx);
              _hasTriggeredDrag = true;
              _accumulatedDragDelta = 0.0;
            }
          }
        } else {
          // Hover-select when menu is open
          _handlePanUpdate(details.globalPosition.dy);
        }
      },
      onPanEnd: (details) {
        if (!_isMenuOpen) {
          _accumulatedDragDelta = 0.0;
          _hasTriggeredDrag = false;
        } else {
          _handlePanEnd();
        }
      },
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
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _hoveredCategoryIndex = null;
        });
      },
      onPanUpdate: (details) {
        _handlePanUpdate(details.globalPosition.dy);
      },
      onPanEnd: (details) {
        _handlePanEnd();
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topRight,
        child: SizedBox(
          width: 56,
          height: _isMenuOpen ? null : 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isMenuOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(
                      alpha: _isMenuOpen ? 0.90 : 0.0,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: _isMenuOpen ? 0.12 : 0.0,
                      ),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 7),
                      Opacity(
                        opacity: _isMenuOpen ? 1.0 : 0.0,
                        child: _buildMenuToggleButton(),
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isMenuOpen ? 1.0 : 0.0,
                        child: _buildCategorySelector(),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_categories.length, (index) {
        final isSelected = _activeCategoryIndex == index;
        final isHovered = _hoveredCategoryIndex == index;
        final showActive = _hoveredCategoryIndex != null ? isHovered : isSelected;
        final cat = _categories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GestureDetector(
            onTap: () {
              _setActiveCategory(index);
              setState(() {
                _isMenuOpen = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showActive
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                border: Border.all(
                  color: showActive
                      ? AppTheme.primaryLight.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                showActive ? cat['activeIcon'] : cat['icon'],
                color: showActive ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActiveContent() {
    switch (_activeCategoryIndex) {
      case 0:
        return AppProvider<MilestonesController>(
          notifier: _milestonesController,
          child: Builder(
            builder: (context) => _buildMilestonesContent(context),
          ),
        );
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

  Widget _buildMilestonesContent(BuildContext context) {
    final controller = AppProvider.watch<MilestonesController>(context);

    // Keep the local variables in ManagementScreen updated for sheets and floating buttons
    _milestoneActivities = controller.milestoneActivities;
    _selectedMilestoneActivity = controller.selectedMilestoneActivity;

    return MilestonesTab(
      onActivitySelected: (activity) {
        controller.selectActivity(activity);
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
            milestones: controller.milestoneActivities,
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
      onOpenActivityDetails: (activity) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailsScreen(
              activityId: activity.id,
              showEditIcon: false,
            ),
          ),
        );
      },
    );
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
    if (_milestoneActivities.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMilestoneSubTaskSheet(
        milestones: _milestoneActivities,
        initialActivityId: _selectedMilestoneActivity?.id,
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
