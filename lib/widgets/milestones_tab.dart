import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'app_spacers.dart';
import 'milestone_section.dart';
import '../controllers/milestones_controller.dart';
import 'add_milestone_task_sheet.dart';
import '../screens/activity_details_screen.dart';
import 'base_management_tab.dart';

class MilestonesTab extends StatefulWidget {
  const MilestonesTab({super.key});

  @override
  State<MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<MilestonesTab> {
  late final MilestonesController _controller;
  String? _expandedTaskId;
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
    return BaseManagementTab<MilestonesController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.milestoneActivities.isEmpty,
      emptyIcon: Icons.flag_outlined,
      emptyMessage: 'No milestone activities active.',
      onRefresh: () async => await _controller.refresh(),
      onFabPressed: () {
        if (_controller.milestoneActivities.isNotEmpty) {
          _showAddTaskSheet(context, _controller);
        }
      },
      builder: (context, controller) {
        // 1. Dynamic Category Tags from milestone activities
        final Set<String> uniqueActivityNames = controller.milestoneActivities.map((a) => a.name).toSet();
        final List<String> categories = ['All', ...uniqueActivityNames];

        final List<Widget> sectionWidgets = [];

        // If tasks lists are all empty, show placeholder
        if (controller.todayTasks.isEmpty &&
            controller.futureTasks.isEmpty &&
            controller.completedTasks.isEmpty) {
          sectionWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
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
            ),
          );
        }

        // Today Section
        if (controller.todayTasks.isNotEmpty) {
          sectionWidgets.add(
            MilestoneSection(
              title: 'Today',
              tasks: controller.todayTasks,
              isExpanded: _todayExpanded,
              onToggle: () => setState(() => _todayExpanded = !_todayExpanded),
              expandedTaskId: _expandedTaskId,
              milestoneActivities: controller.milestoneActivities,
              onTaskExpansionChanged: (id) => setState(() => _expandedTaskId = id),
              onEditTask: (task) => _showEditTaskSheet(context, task, controller),
            ),
          );
        }

        // Future Section
        if (controller.futureTasks.isNotEmpty) {
          if (sectionWidgets.isNotEmpty && controller.todayTasks.isNotEmpty) {
            sectionWidgets.add(const VGapMd());
          }
          sectionWidgets.add(
            MilestoneSection(
              title: 'Future',
              tasks: controller.futureTasks,
              isExpanded: _futureExpanded,
              onToggle: () => setState(() => _futureExpanded = !_futureExpanded),
              expandedTaskId: _expandedTaskId,
              milestoneActivities: controller.milestoneActivities,
              onTaskExpansionChanged: (id) => setState(() => _expandedTaskId = id),
              onEditTask: (task) => _showEditTaskSheet(context, task, controller),
            ),
          );
        }

        // Completed Section
        if (controller.completedTasks.isNotEmpty) {
          if (sectionWidgets.isNotEmpty &&
              (controller.todayTasks.isNotEmpty || controller.futureTasks.isNotEmpty)) {
            sectionWidgets.add(const VGapMd());
          }
          sectionWidgets.add(
            MilestoneSection(
              title: 'Completed',
              tasks: controller.completedTasks,
              isExpanded: _completedExpanded,
              onToggle: () => setState(() => _completedExpanded = !_completedExpanded),
              expandedTaskId: _expandedTaskId,
              milestoneActivities: controller.milestoneActivities,
              onTaskExpansionChanged: (id) => setState(() => _expandedTaskId = id),
              onEditTask: (task) => _showEditTaskSheet(context, task, controller),
            ),
          );
        }



        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            final currentIndex = categories.indexOf(controller.selectedCategory);
            if (currentIndex == -1) return;

            if (details.primaryVelocity! < 0) {
              // Swipe left -> Next category
              if (currentIndex < categories.length - 1) {
                _selectCategory(categories[currentIndex + 1], controller);
              }
            } else if (details.primaryVelocity! > 0) {
              // Swipe right -> Previous category
              if (currentIndex > 0) {
                _selectCategory(categories[currentIndex - 1], controller);
              }
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Capsule list
                        _buildCategoryBar(categories, controller),
                        const VGapMd(),

                        if (controller.selectedCategory != 'All' &&
                            controller.selectedMilestoneActivity != null &&
                            controller.selectedMilestoneActivity!.id.isNotEmpty) ...[
                          _buildMilestoneHeaderCard(context, controller.selectedMilestoneActivity!),
                          const VGapMd(),
                        ],
                        ...sectionWidgets,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _selectCategory(String cat, MilestonesController controller) {
    if (cat != 'All') {
      final act = controller.milestoneActivities.firstWhere((a) => a.name == cat);
      controller.selectActivity(act);
    } else {
      controller.selectActivity(null);
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


  void _showAddTaskSheet(BuildContext context, MilestonesController controller) {
    // Derive initialId directly from selectedCategory:
    // - 'All' → null → sheet defaults to first milestone
    // - specific name → look up that activity's id from the list
    final String? initialId;
    if (controller.selectedCategory == 'All') {
      initialId = null;
    } else {
      initialId = controller.milestoneActivities
          .where((a) => a.name == controller.selectedCategory)
          .map((a) => a.id)
          .firstOrNull;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMilestoneTaskSheet(
        milestones: controller.milestoneActivities,
        initialActivityId: initialId,
        onAddTask: (activity, taskName, timestamp) async {
          await controller.createTask(activity, taskName, timestamp);
        },
      ),
    );
  }

  void _showEditTaskSheet(BuildContext context, Task task, MilestonesController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMilestoneTaskSheet(
        milestones: controller.milestoneActivities,
        editTask: task,
        onEditTask: (updatedTask) async {
          await controller.updateTask(updatedTask);
        },
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

  Widget _buildCategoryBar(List<String> categories, MilestonesController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = controller.selectedCategory == cat;
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
                  _selectCategory(cat, controller);
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
