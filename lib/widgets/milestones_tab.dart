import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'app_spacers.dart';
import 'milestone_section.dart';
import '../controllers/milestones_controller.dart';
import 'app_provider.dart';

class MilestonesTab extends StatefulWidget {
  final Function(Activity?) onActivitySelected;
  final Function(Task, bool) onToggleSubTask;
  
  // Callback functions for interactivity
  final Function(Activity, bool) onToggleActivity;
  final Function(Activity, String?, String?, String?) onUpdateActivitySymbols;
  final Function(Activity, String, DateTime) onAddSubTask;
  final Function(Task) onDeleteSubTask;
  final Function(Task) onEditSubTask;
  final Function(Task, String?, String?) onUpdateSubTaskSymbols;
  final Function(Activity) onOpenActivityDetails;

  const MilestonesTab({
    super.key,
    required this.onActivitySelected,
    required this.onToggleSubTask,
    required this.onToggleActivity,
    required this.onUpdateActivitySymbols,
    required this.onAddSubTask,
    required this.onDeleteSubTask,
    required this.onEditSubTask,
    required this.onUpdateSubTaskSymbols,
    required this.onOpenActivityDetails,
  });

  @override
  State<MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<MilestonesTab> {
  String? _expandedSubTaskId;

  // Accordion open/close state
  bool _todayExpanded = true;
  bool _futureExpanded = true;
  bool _completedExpanded = true;

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<MilestonesController>(context);

    // 1. Dynamic Category Tags from milestone activities
    final Set<String> uniqueActivityNames = controller.milestoneActivities.map((a) => a.name).toSet();
    final List<String> categories = ['All', ...uniqueActivityNames];

    final List<Widget> sectionWidgets = [];

    if (controller.isLoading) {
      sectionWidgets.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    } else if (controller.todayTasks.isEmpty &&
        controller.futureTasks.isEmpty &&
        controller.completedTasks.isEmpty) {
      sectionWidgets.add(_buildEmptyState('No tasks found. Tap the FAB (+) to add a task!'));
    } else {
      // Today Section
      if (controller.todayTasks.isNotEmpty) {
        sectionWidgets.add(
          MilestoneSection(
            title: 'Today',
            tasks: controller.todayTasks,
            isExpanded: _todayExpanded,
            onToggle: () => setState(() => _todayExpanded = !_todayExpanded),
            expandedSubTaskId: _expandedSubTaskId,
            milestoneActivities: controller.milestoneActivities,
            onSubTaskExpansionChanged: (id) => setState(() => _expandedSubTaskId = id),
            onActivitySelected: widget.onActivitySelected,
            onToggleSubTask: widget.onToggleSubTask,
            onEditSubTask: widget.onEditSubTask,
            onUpdateSubTaskSymbols: widget.onUpdateSubTaskSymbols,
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
            expandedSubTaskId: _expandedSubTaskId,
            milestoneActivities: controller.milestoneActivities,
            onSubTaskExpansionChanged: (id) => setState(() => _expandedSubTaskId = id),
            onActivitySelected: widget.onActivitySelected,
            onToggleSubTask: widget.onToggleSubTask,
            onEditSubTask: widget.onEditSubTask,
            onUpdateSubTaskSymbols: widget.onUpdateSubTaskSymbols,
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
            expandedSubTaskId: _expandedSubTaskId,
            milestoneActivities: controller.milestoneActivities,
            onSubTaskExpansionChanged: (id) => setState(() => _expandedSubTaskId = id),
            onActivitySelected: widget.onActivitySelected,
            onToggleSubTask: widget.onToggleSubTask,
            onEditSubTask: widget.onEditSubTask,
            onUpdateSubTaskSymbols: widget.onUpdateSubTaskSymbols,
          ),
        );
      }

      // Check all completed tasks link
      sectionWidgets.add(const VGapMd());
      sectionWidgets.add(
        Center(
          child: TextButton(
            onPressed: () {
              controller.selectActivity(null);
              setState(() {
                _completedExpanded = true;
              });
            },
            child: Text(
              'Check all completed tasks',
              style: TextStyle(
                color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.secondaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Capsule list
        _buildCategoryBar(categories, controller),
        const VGapMd(),

        if (controller.selectedMilestoneActivity != null &&
            controller.selectedMilestoneActivity!.id.isNotEmpty) ...[
          _buildMilestoneHeaderCard(controller.selectedMilestoneActivity!),
          const VGapMd(),
        ],

        ...sectionWidgets,
      ],
    );
  }

  Widget _buildMilestoneHeaderCard(Activity activity) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.35),
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
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
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
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const HGapSm(),
          
          // Right Arrow Button
          GestureDetector(
            onTap: () => widget.onOpenActivityDetails(activity),
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
                  SizedBox(width: 4),
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
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  if (cat != 'All') {
                    final act = controller.milestoneActivities.firstWhere((a) => a.name == cat);
                    controller.selectActivity(act);
                    widget.onActivitySelected(act);
                  } else {
                    controller.selectActivity(null);
                    widget.onActivitySelected(null);
                  }
                }
              },
              selectedColor: AppTheme.secondaryColor,
              backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.4),
              showCheckmark: false,
              elevation: 0,
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected 
                      ? AppTheme.secondaryColor.withValues(alpha: 0.5) 
                      : Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.playlist_add_check_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
