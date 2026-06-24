import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../widgets/app_spacers.dart';
import '../widgets/milestone_section.dart';
import '../controllers/milestones_controller.dart';
import 'activity_details_screen.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_premium_fab.dart';
import '../widgets/app_provider.dart';
import 'add_milestone_task_screen.dart';
import '../widgets/app_empty_state.dart';
import 'add_activity_screen.dart';
import '../services/activity_service.dart';
import '../services/service_locator.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late final MilestonesController _controller;
  final Map<String, GlobalKey> _chipKeys = {};

  // Accordion open/close state
  bool _todayExpanded = true;
  bool _futureExpanded = true;
  bool _completedExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = MilestonesController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Register theme dependency to rebuild on theme switch
    
    return AppProvider<MilestonesController>(
      notifier: _controller,
      child: Stack(
        children: [
          Positioned.fill(
            child: FullScreenPage(
              showScaffold: false,
              isScrollable: false,
              title: 'Milestones',
              //headerSpacing: 48.0,
              padding: EdgeInsets.zero,
              backgroundWidgets: [
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
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.isLoading && _controller.errorMessage == null) {
                return AppPremiumFab(
                  right: 24,
                  onPressed: () {
                    if (_controller.milestoneActivities.isEmpty) {
                      _navigateToAddMilestoneActivity(context);
                    } else {
                      _navigateToNewTaskScreen(context);
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_controller.errorMessage != null) {
      return Center(
        child: Text(
          'Failed to load data:\n${_controller.errorMessage}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      );
    }

    if (_controller.milestoneActivities.isEmpty) {
      return AppEmptyState(
        icon: Icons.flag_outlined,
        title: 'No Milestone Activities',
        description: 'Create a milestone activity to start tracking your goals and subtasks.',
        actionLabel: 'Create Milestone',
        onActionPressed: () => _navigateToAddMilestoneActivity(context),
      );
    }

    // 1. Dynamic Category Tags from milestone activities
    final Set<String> uniqueActivityNames = _controller.milestoneActivities.map((a) => a.name).toSet();
    final List<String> categories = ['All', ...uniqueActivityNames];

    final List<Widget> sectionWidgets = [];

    // If tasks lists are all empty, show placeholder
    if (_controller.todayTasks.isEmpty &&
        _controller.futureTasks.isEmpty &&
        _controller.completedTasks.isEmpty) {
      sectionWidgets.add(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 64,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
              ),
              const VGapMd(),
              Text(
                'No tasks found',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const VGapSm(),
              Text(
                'Tap the FAB (+) to add a task for this milestone!',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Today Section
    if (_controller.todayTasks.isNotEmpty) {
      sectionWidgets.add(
        MilestoneSection(
          title: 'Today',
          tasks: _controller.todayTasks,
          isExpanded: _todayExpanded,
          onToggle: () => setState(() => _todayExpanded = !_todayExpanded),
          milestoneActivities: _controller.milestoneActivities,
          onEditTask: (task) => _showEditTaskSheet(context, task),
        ),
      );
    }

    // Future Section
    if (_controller.futureTasks.isNotEmpty) {
      if (sectionWidgets.isNotEmpty && _controller.todayTasks.isNotEmpty) {
        sectionWidgets.add(const VGapMd());
      }
      sectionWidgets.add(
        MilestoneSection(
          title: 'Future',
          tasks: _controller.futureTasks,
          isExpanded: _futureExpanded,
          onToggle: () => setState(() => _futureExpanded = !_futureExpanded),
          milestoneActivities: _controller.milestoneActivities,
          onEditTask: (task) => _showEditTaskSheet(context, task),
        ),
      );
    }

    // Completed Section
    if (_controller.completedTasks.isNotEmpty) {
      if (sectionWidgets.isNotEmpty &&
          (_controller.todayTasks.isNotEmpty || _controller.futureTasks.isNotEmpty)) {
        sectionWidgets.add(const VGapMd());
      }
      sectionWidgets.add(
        MilestoneSection(
          title: 'Completed',
          tasks: _controller.completedTasks,
          isExpanded: _completedExpanded,
          onToggle: () => setState(() => _completedExpanded = !_completedExpanded),
          milestoneActivities: _controller.milestoneActivities,
          onEditTask: (task) => _showEditTaskSheet(context, task),
        ),
      );
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () => _navigateToNewTaskScreen(context),
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        final currentIndex = categories.indexOf(_controller.selectedCategory);
        if (currentIndex == -1) return;

        if (details.primaryVelocity! < 0) {
          // Swipe left -> Next category
          if (currentIndex < categories.length - 1) {
            _selectCategory(categories[currentIndex + 1]);
          }
        } else if (details.primaryVelocity! > 0) {
          // Swipe right -> Previous category
          if (currentIndex > 0) {
            _selectCategory(categories[currentIndex - 1]);
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildCategoryBar(categories),
              const VGapSm(),

              // SCROLLABLE task sections
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: bottomPadding + 100 + viewInsetsBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_controller.selectedCategory != 'All' &&
                            _controller.selectedMilestoneActivity != null &&
                            _controller.selectedMilestoneActivity!.id.isNotEmpty) ...[
                          _buildMilestoneHeaderCard(context, _controller.selectedMilestoneActivity!),
                          const VGapMd(),
                        ],
                        ...sectionWidgets,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _selectCategory(String cat) {
    if (cat != 'All') {
      final act = _controller.milestoneActivities.firstWhere((a) => a.name == cat);
      _controller.selectActivity(act);
    } else {
      _controller.selectActivity(null);
    }

    // Scroll the selected capsule chip into view if it is scrolled off screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _chipKeys[cat];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _showEditTaskSheet(BuildContext context, Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMilestoneTaskScreen(
          milestones: _controller.milestoneActivities,
          editTask: task,
          onEditTask: (updatedTask) async {
            await _controller.updateTask(updatedTask);
          },
          onDeleteTask: (taskToDelete) async {
            await _controller.deleteTask(taskToDelete);
          },
        ),
      ),
    );
  }

  void _navigateToNewTaskScreen(BuildContext context) {
    final String? initialId;
    if (_controller.selectedCategory == 'All') {
      initialId = null;
    } else {
      initialId = _controller.milestoneActivities
          .where((a) => a.name == _controller.selectedCategory)
          .map((a) => a.id)
          .firstOrNull;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMilestoneTaskScreen(
          milestones: _controller.milestoneActivities,
          initialActivityId: initialId,
          onAddTask: (activity, taskName, timestamp, subTasks, symbolType, symbolValue, notes) async {
            return await _controller.createTask(
              activity,
              taskName,
              timestamp,
              subTasks: subTasks,
              symbolType: symbolType,
              symbolValue: symbolValue,
              notes: notes,
            );
          },
        ),
      ),
    );
  }

  void _navigateToAddMilestoneActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          initialTrackingType: 'milestone',
          onAdd: (name, trackingType, targetCount, {
            List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
            String? scheduledTime,
            DateTime? startDate,
            DateTime? endDate,
            List<String> subTaskTemplates = const [],
            String? description,
            bool skippable = false,
            bool reminderEnabled = true,
            double weight = 1.0,
            int points = 10,
            int focusDuration = 25,
            bool isPomodoroFocusEnabled = false,
          }) async {
            await getIt<ActivityService>().createActivity(
              name,
              trackingType: trackingType,
              targetCount: targetCount,
              repeatDays: repeatDays,
              scheduledTime: scheduledTime,
              startDate: startDate,
              endDate: endDate,
              subTaskTemplates: subTaskTemplates,
              description: description ?? '',
              skippable: skippable,
              reminderEnabled: reminderEnabled,
              weight: weight,
              points: points,
              focusDuration: focusDuration,
              isPomodoroFocusEnabled: isPomodoroFocusEnabled,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMilestoneHeaderCard(BuildContext context, Activity activity) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left Icon with Background Glow
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.warningColor, AppTheme.warningColor.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.flag_rounded, color: AppTheme.textPrimary, size: 20),
          ),
          const HGapMd(),
          
          // Middle Details Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: AppTheme.headingSmall.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapXs(),
                Text(
                  'View trends, consistency, & history',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const HGapSm(),
          
          // Right Arrow Button
          GestureDetector(
            onTap: () {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  HGapXs(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppTheme.warningColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _controller.selectedCategory == cat;
          final key = _chipKeys.putIfAbsent(cat, () => GlobalKey());
          return Padding(
            key: key,
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.selectedChipTextColor(context)
                      : AppTheme.textSecondaryColor(context),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  _selectCategory(cat);
                }
              },
              selectedColor: AppTheme.secondaryColor,
              backgroundColor: AppTheme.surface(context).withValues(alpha: 0.4),
              showCheckmark: false,
              elevation: 0,
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected 
                      ? AppTheme.secondaryColor.withValues(alpha: 0.5) 
                      : AppTheme.borderColor(context),
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
