import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/sub_task.dart';
import 'app_spacers.dart';

class MilestonesTab extends StatelessWidget {
  final List<Activity> milestoneActivities;
  final Activity? selectedActivity;
  final List<SubTask> subTasks;
  final Function(Activity?) onActivitySelected;

  const MilestonesTab({
    super.key,
    required this.milestoneActivities,
    required this.selectedActivity,
    required this.subTasks,
    required this.onActivitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown to select a milestone activity
        _buildActivityDropdown(context),
        const VGapMd(),
        // Subtasks list for the selected activity
        if (selectedActivity == null)
          _buildEmptyState('Select a milestone activity above.')
        else if (subTasks.isEmpty)
          _buildEmptyState('No subtasks recorded for "${selectedActivity!.name}".')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subTasks.length,
            itemBuilder: (context, index) {
              final st = subTasks[index];
              return Card(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    st.checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: st.checked ? AppTheme.successColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  title: Text(
                    st.subTaskName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      decoration: st.checked ? TextDecoration.lineThrough : null,
                      decorationColor: AppTheme.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy – hh:mm a').format(st.timestamp),
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActivityDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: AppTheme.primaryColor.withValues(alpha: 0.7), size: 20),
          const HGapSm(),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: AppTheme.surfaceColor,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                value: selectedActivity?.id,
                hint: Text(
                  milestoneActivities.isEmpty ? 'No milestone activities' : 'Select a milestone activity',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                items: milestoneActivities.map((activity) {
                  return DropdownMenuItem<String>(
                    value: activity.id,
                    child: Text(
                      activity.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    final activity = milestoneActivities.firstWhere((a) => a.id == id);
                    onActivitySelected(activity);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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
