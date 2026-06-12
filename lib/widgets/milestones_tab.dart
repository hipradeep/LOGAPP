import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'app_spacers.dart';
import 'task_card.dart';

class MilestonesTab extends StatefulWidget {
  final List<Activity> milestoneActivities;
  final Activity? selectedActivity;
  final List<Task> subTasks;
  final Function(Activity?) onActivitySelected;
  final Function(Task, bool) onToggleSubTask;
  final bool isLoadingSubTasks;
  
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
    required this.milestoneActivities,
    required this.selectedActivity,
    required this.subTasks,
    required this.onActivitySelected,
    required this.onToggleSubTask,
    this.isLoadingSubTasks = false,
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
  String _selectedCategory = 'All';
  String? _expandedSubTaskId;

  // Accordion open/close state
  bool _todayExpanded = true;
  bool _futureExpanded = true;
  bool _completedExpanded = true;

  @override
  Widget build(BuildContext context) {
    // 1. Dynamic Category Tags from milestone activities
    final Set<String> uniqueActivityNames = widget.milestoneActivities.map((a) => a.name).toSet();
    final List<String> categories = ['All', ...uniqueActivityNames];

    // Ensure selected category is still valid
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    // 2. Filter Subtasks by Category selection
    final List<Task> filteredSubTasks = widget.subTasks.where((st) {
      // Find parent activity
      final parent = widget.milestoneActivities.firstWhere(
        (a) => a.id == st.activityId,
        orElse: () => Activity(
          id: '',
          name: '',
          checked: false,
          timestamp: DateTime.now(),
        ),
      );
      if (parent.id.isEmpty) return false;
      if (_selectedCategory == 'All') return true;
      return parent.name == _selectedCategory;
    }).toList();

    // 3. Classify Subtasks
    final List<Task> todayTasks = [];
    final List<Task> futureTasks = [];
    final List<Task> completedTasks = [];

    for (var st in filteredSubTasks) {
      if (_isToday(st.timestamp)) {
        todayTasks.add(st);
      } else if (st.checked) {
        completedTasks.add(st);
      } else {
        futureTasks.add(st);
      }
    }

    // Sort sections (Today: completed/checked tasks on top first)
    todayTasks.sort((a, b) {
      if (a.checked && !b.checked) return -1;
      if (!a.checked && b.checked) return 1;
      return a.timestamp.compareTo(b.timestamp);
    });
    
    futureTasks.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    completedTasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Activity? activeActivity = _selectedCategory == 'All'
        ? null
        : widget.milestoneActivities.firstWhere(
            (a) => a.name == _selectedCategory,
            orElse: () => Activity(id: '', name: '', checked: false, timestamp: DateTime.now()),
          );

    final List<Widget> sectionWidgets = [];

    if (widget.isLoadingSubTasks) {
      sectionWidgets.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    } else if (filteredSubTasks.isEmpty) {
      sectionWidgets.add(_buildEmptyState('No tasks found. Tap the FAB (+) to add a task!'));
    } else {
      if (todayTasks.isNotEmpty) {
        sectionWidgets.add(
          _buildSectionHeader(
            title: 'Today',
            count: todayTasks.length,
            isExpanded: _todayExpanded,
            onToggle: () => setState(() => _todayExpanded = !_todayExpanded),
          ),
        );
        if (_todayExpanded) {
          sectionWidgets.add(
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayTasks.length,
              itemBuilder: (context, idx) => _buildTaskCardItem(todayTasks[idx]),
            ),
          );
        }
      }

      if (futureTasks.isNotEmpty) {
        if (sectionWidgets.isNotEmpty && todayTasks.isNotEmpty) {
          sectionWidgets.add(const VGapMd());
        }
        sectionWidgets.add(
          _buildSectionHeader(
            title: 'Future',
            count: futureTasks.length,
            isExpanded: _futureExpanded,
            onToggle: () => setState(() => _futureExpanded = !_futureExpanded),
          ),
        );
        if (_futureExpanded) {
          sectionWidgets.add(
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: futureTasks.length,
              itemBuilder: (context, idx) => _buildTaskCardItem(futureTasks[idx]),
            ),
          );
        }
      }

      if (completedTasks.isNotEmpty) {
        if (sectionWidgets.isNotEmpty && (todayTasks.isNotEmpty || futureTasks.isNotEmpty)) {
          sectionWidgets.add(const VGapMd());
        }
        sectionWidgets.add(
          _buildSectionHeader(
            title: 'Completed',
            count: completedTasks.length,
            isExpanded: _completedExpanded,
            onToggle: () => setState(() => _completedExpanded = !_completedExpanded),
          ),
        );
        if (_completedExpanded) {
          sectionWidgets.add(
            ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedTasks.length,
              itemBuilder: (context, idx) => _buildTaskCardItem(completedTasks[idx]),
            ),
          );
        }
      }

      // Check all completed tasks link
      sectionWidgets.add(const VGapMd());
      sectionWidgets.add(
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'All';
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
        _buildCategoryBar(categories),
        const VGapMd(),

        if (activeActivity != null && activeActivity.id.isNotEmpty) ...[
          _buildMilestoneHeaderCard(activeActivity),
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

  Widget _buildCategoryBar(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
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
                  setState(() {
                    _selectedCategory = cat;
                    // Also update active activity in parent screen if matches
                    if (cat != 'All') {
                      final act = widget.milestoneActivities.firstWhere((a) => a.name == cat);
                      widget.onActivitySelected(act);
                    } else {
                      widget.onActivitySelected(null);
                    }
                  });
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

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
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
                '$count',
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

  Widget _buildTaskCardItem(Task st) {
    final parent = widget.milestoneActivities.firstWhere(
      (a) => a.id == st.activityId,
      orElse: () => Activity(
        id: '',
        name: '',
        checked: false,
        timestamp: DateTime.now(),
      ),
    );

    return TaskCard(
      task: st,
      milestoneActivities: widget.milestoneActivities,
      isExpanded: _expandedSubTaskId == st.id,
      onTap: () {
        setState(() {
          if (_expandedSubTaskId == st.id) {
            _expandedSubTaskId = null;
          } else {
            _expandedSubTaskId = st.id;
            if (parent.id.isNotEmpty) {
              widget.onActivitySelected(parent);
            }
          }
        });
      },
      onActivitySelected: widget.onActivitySelected,
      onToggleSubTask: widget.onToggleSubTask,
      onEditSubTask: widget.onEditSubTask,
      onUpdateSubTaskSymbols: widget.onUpdateSubTaskSymbols,
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
