import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/activity.dart';
import 'task_card.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../controllers/milestones_controller.dart';
import 'app_provider.dart';

class MilestoneSection extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? expandedSubTaskId;
  final List<Activity> milestoneActivities;
  final Function(String?) onSubTaskExpansionChanged;
  final Function(Task) onEditSubTask;

  const MilestoneSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.isExpanded,
    required this.onToggle,
    required this.expandedSubTaskId,
    required this.milestoneActivities,
    required this.onSubTaskExpansionChanged,
    required this.onEditSubTask,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final controller = AppProvider.read<MilestonesController>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionHeader(),
        if (isExpanded) ...[
          ListView.builder(
            key: ValueKey('${title}_list'),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, idx) {
              final st = tasks[idx];
              final parent = milestoneActivities.firstWhere(
                (a) => a.id == st.activityId,
                orElse: () => Activity(
                  id: '',
                  name: '',
                  checked: false,
                  timestamp: DateTime.now(),
                ),
              );

              return TaskCard(
                key: ValueKey(st.id),
                task: st,
                milestoneActivities: milestoneActivities,
                isExpanded: expandedSubTaskId == st.id,
                onTap: () {
                  if (expandedSubTaskId == st.id) {
                    onSubTaskExpansionChanged(null);
                  } else {
                    onSubTaskExpansionChanged(st.id);
                    if (parent.id.isNotEmpty) {
                      controller.selectActivity(parent);
                    }
                  }
                },
                onActivitySelected: (activity) {
                  controller.selectActivity(activity);
                },
                onToggleSubTask: (task, checked) {
                  controller.toggleSubTask(task, checked);
                },
                onEditSubTask: onEditSubTask,
                onUpdateSubTaskSymbols: (task, symbolType, symbolValue) {
                  controller.updateSubTaskSymbols(task, symbolType: symbolType, symbolValue: symbolValue);
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader() {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const HGapSm(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const HGapXs(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
