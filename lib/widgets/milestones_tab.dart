import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'app_spacers.dart';

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
  final Map<String, TextEditingController> _nestedControllers = {};
  String? _deletingNestedItemId;
  final FocusNode _nestedFocusNode = FocusNode();
  bool _wasKeyboardVisible = false;

  // Accordion open/close state
  bool _todayExpanded = true;
  bool _futureExpanded = true;
  bool _completedExpanded = true;

  @override
  void dispose() {
    for (var controller in _nestedControllers.values) {
      controller.dispose();
    }
    _nestedFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_wasKeyboardVisible && !isKeyboardVisible && _nestedFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nestedFocusNode.unfocus();
        }
      });
    }
    _wasKeyboardVisible = isKeyboardVisible;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Capsule list
        _buildCategoryBar(categories),
        const VGapMd(),

        if (activeActivity != null && activeActivity.id.isNotEmpty) ...[
          _buildMilestoneHeaderCard(activeActivity),
          const VGapSm(),
        ],

        if (widget.isLoadingSubTasks)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          )
        else if (filteredSubTasks.isEmpty)
          _buildEmptyState('No tasks found. Tap the FAB (+) to add a task!')
        else ...[
          // Today section
          if (todayTasks.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Today',
              count: todayTasks.length,
              isExpanded: _todayExpanded,
              onToggle: () => setState(() => _todayExpanded = !_todayExpanded),
            ),
            if (_todayExpanded) ...[
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todayTasks.length,
                itemBuilder: (context, idx) => _buildTaskCard(todayTasks[idx]),
              ),
              const VGapMd(),
            ],
          ],

          // Future section
          if (futureTasks.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Future',
              count: futureTasks.length,
              isExpanded: _futureExpanded,
              onToggle: () => setState(() => _futureExpanded = !_futureExpanded),
            ),
            if (_futureExpanded) ...[
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: futureTasks.length,
                itemBuilder: (context, idx) => _buildTaskCard(futureTasks[idx]),
              ),
              const VGapMd(),
            ],
          ],

          // Completed section
          if (completedTasks.isNotEmpty) ...[
            _buildSectionHeader(
              title: 'Completed',
              count: completedTasks.length,
              isExpanded: _completedExpanded,
              onToggle: () => setState(() => _completedExpanded = !_completedExpanded),
            ),
            if (_completedExpanded) ...[
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completedTasks.length,
                itemBuilder: (context, idx) => _buildTaskCard(completedTasks[idx]),
              ),
              const VGapMd(),
            ],
          ],

          // Check all completed tasks link
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
        ],
      ],
    );
  }

  Widget _buildMilestoneHeaderCard(Activity activity) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const HGapSm(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white60,
              size: 16,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task st) {
    final parent = widget.milestoneActivities.firstWhere(
      (a) => a.id == st.activityId,
      orElse: () => Activity(
        id: '',
        name: '',
        checked: false,
        timestamp: DateTime.now(),
      ),
    );

    final isExpanded = _expandedSubTaskId == st.id;
    final totalCount = st.subTasks.length;
    final completedCount = st.subTasks.where((i) => i.checked).length;
    final totalDuration = st.subTasks
        .where((i) => i.durationMinutes != null)
        .fold<int>(0, (sum, i) => sum + i.durationMinutes!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: st.checked
            ? AppTheme.surfaceColor.withValues(alpha: 0.15)
            : AppTheme.surfaceColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSubTaskId = null;
                } else {
                  _expandedSubTaskId = st.id;
                  widget.onActivitySelected(parent);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Left Checkbox
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      onTap: () {
                        widget.onToggleSubTask(st, !st.checked);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: st.checked 
                              ? const Color(0xFF64748B) // Slate 500
                              : Colors.transparent,
                          border: Border.all(
                            color: st.checked 
                                ? const Color(0xFF64748B)
                                : Colors.white30,
                            width: 2,
                          ),
                        ),
                        child: st.checked
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // 2. Middle Content (Title + Subtitle)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.taskName,
                          style: TextStyle(
                            color: st.checked ? AppTheme.textSecondary.withValues(alpha: 0.5) : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: st.checked ? TextDecoration.lineThrough : null,
                            decorationColor: AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                        if (parent.repeatDays.length < 7 || totalCount > 0) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (totalCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.account_tree_outlined,
                                        size: 9,
                                        color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$completedCount/$totalCount',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (totalDuration > 0) ...[
                                        const SizedBox(width: 5),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 9,
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${totalDuration}m',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.secondaryColor.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              // Repeat arrows badge
                              if (parent.repeatDays.length < 7)
                                const Icon(
                                  Icons.repeat_rounded,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // 3. Right Symbol Indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: GestureDetector(
                      onTap: () => _showSymbolSelectionDialog(st),
                      child: _buildSymbolIndicator(st),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded panel showing nested items and actions
          if (isExpanded) ...[
            const Divider(color: Colors.white10, height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent milestone label
                  if (parent.name.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 9,
                            color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            parent.name,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.secondaryColor.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Nested Checklist items
                  if (st.subTasks.isNotEmpty) ...[
                    const Text(
                      'Checklist Items:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(st.subTasks.length, (idx) {
                      final item = st.subTasks[idx];
                      final isDeleting = _deletingNestedItemId == item.id;

                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            if (isDeleting) {
                              _deletingNestedItemId = null;
                            } else {
                              _deletingNestedItemId = item.id;
                            }
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            children: [
                              Checkbox(
                                value: item.checked,
                                activeColor: AppTheme.primaryColor,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  if (isDeleting) {
                                    setState(() {
                                      _deletingNestedItemId = null;
                                    });
                                  } else if (val != null) {
                                    _toggleNestedItem(st, idx, val);
                                  }
                                },
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (isDeleting) {
                                      setState(() {
                                        _deletingNestedItemId = null;
                                      });
                                    }
                                  },
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: item.checked ? AppTheme.textSecondary.withValues(alpha: 0.5) : Colors.white70,
                                      fontSize: 12,
                                      decoration: item.checked ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (isDeleting)
                                GestureDetector(
                                  onTap: () {
                                    _deleteNestedItem(st, idx);
                                    setState(() {
                                      _deletingNestedItemId = null;
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                )
                              else
                                _buildChecklistItemDurationMenu(st, idx, item),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Inline Add Nested Item form
                  _buildAddNestedItemForm(st),
                  const VGapSm(),

                  // Subtask Meta actions (Date/Time badge & Edit button)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              st.scheduledTime != null
                                  ? '${DateFormat('MMM d, yyyy').format(st.timestamp)} • ${_formatTimeString(st.scheduledTime!)}'
                                  : DateFormat('MMM d, yyyy').format(st.timestamp),
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onEditSubTask(st),
                        icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryLight),
                        label: const Text('Edit', style: TextStyle(color: AppTheme.primaryLight, fontSize: 11)),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymbolIndicator(Task st) {
    const double size = 26;

    if (st.symbolType == 'flag') {
      final flagColor = _getFlagColor(st.symbolValue);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: flagColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.flag_rounded, color: flagColor, size: 16),
      );
    } else if (st.symbolType == 'number') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Center(
          child: Text(
            st.symbolValue ?? '1',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (st.symbolType == 'progress') {
      final double progress = double.tryParse(st.symbolValue ?? '0') ?? 0;
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: PieChartPainter(
            progress: progress,
            color: AppTheme.secondaryColor,
            backgroundColor: Colors.white10,
          ),
        ),
      );
    } else if (st.symbolType == 'mood') {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Text(
          st.symbolValue ?? '😄',
          style: const TextStyle(fontSize: 16),
        ),
      );
    } else {
      // Default fallback: draw the subtasks checklist progress pie chart if items exist
      final totalCount = st.subTasks.length;
      final completedCount = st.subTasks.where((i) => i.checked).length;
      final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
      if (totalCount > 0) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: PieChartPainter(
              progress: progress,
              color: AppTheme.secondaryColor,
              backgroundColor: Colors.white10,
            ),
          ),
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.flag_outlined, color: Colors.white30, size: 16),
      );
    }
  }

  Widget _buildAddNestedItemForm(Task st) {
    if (!_nestedControllers.containsKey(st.id)) {
      _nestedControllers[st.id] = TextEditingController();
    }
    final controller = _nestedControllers[st.id]!;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: _nestedFocusNode,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Add checklist sub-item...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (val) {
              final text = val.trim();
              if (text.isNotEmpty) {
                _addNestedItem(st, text);
                controller.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              _addNestedItem(st, text);
              controller.clear();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            foregroundColor: AppTheme.primaryLight,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Add', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  void _addNestedItem(Task st, String label) {
    final newList = List<SubTask>.from(st.subTasks);
    newList.add(SubTask(
      id: 'item-${DateTime.now().millisecondsSinceEpoch}',
      title: label,
      checked: false,
    ));
    widget.onToggleSubTask(st.copyWith(subTasks: newList), st.checked);
  }

  void _toggleNestedItem(Task st, int index, bool val) {
    final newList = List<SubTask>.from(st.subTasks);
    newList[index] = newList[index].copyWith(checked: val);
    widget.onToggleSubTask(st.copyWith(subTasks: newList), st.checked);
  }

  void _deleteNestedItem(Task st, int index) {
    final newList = List<SubTask>.from(st.subTasks);
    newList.removeAt(index);
    widget.onToggleSubTask(st.copyWith(subTasks: newList), st.checked);
  }

  void _updateNestedItemDuration(Task st, int index, int? duration) {
    final newList = List<SubTask>.from(st.subTasks);
    newList[index] = newList[index].copyWith(durationMinutes: duration);
    widget.onToggleSubTask(st.copyWith(subTasks: newList), st.checked);
  }

  Widget _buildChecklistItemDurationMenu(Task st, int index, SubTask item) {
    return PopupMenuButton<String>(
      tooltip: 'Change duration or delete',
      onSelected: (val) {
        if (val == 'delete') {
          _deleteNestedItem(st, index);
        } else {
          final int? duration = val == 'none' ? null : int.tryParse(val);
          _updateNestedItemDuration(st, index, duration);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'none',
          child: Text('No limit', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem<String>(
          value: '10',
          child: Text('10 minutes', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem<String>(
          value: '30',
          child: Text('30 minutes', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuItem<String>(
          value: '60',
          child: Text('1 hour', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Delete Item', style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
            ],
          ),
        ),
      ],
      offset: const Offset(0, 30),
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: item.durationMinutes != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.checked
                      ? Colors.white.withValues(alpha: 0.02)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 10,
                      color: item.checked
                          ? AppTheme.textSecondary.withValues(alpha: 0.4)
                          : AppTheme.primaryLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.durationMinutes}m',
                      style: TextStyle(
                        color: item.checked
                            ? AppTheme.textSecondary.withValues(alpha: 0.4)
                            : AppTheme.primaryLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : Icon(
                Icons.timer_outlined,
                size: 16,
                color: item.checked
                    ? AppTheme.textSecondary.withValues(alpha: 0.2)
                    : Colors.white24,
              ),
      ),
    );
  }



  void _showSymbolSelectionDialog(Task st) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mark with symbol',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onUpdateSubTaskSymbols(st, '', '');
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildDialogLabel('Flag'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFlagOption(st, 'red', Colors.redAccent),
                    _buildFlagOption(st, 'yellow', Colors.amber),
                    _buildFlagOption(st, 'purple', Colors.purpleAccent),
                    _buildFlagOption(st, 'blue', Colors.blueAccent),
                    _buildFlagOption(st, 'green', Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Number'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final numStr = '${index + 1}';
                    return _buildNumberOption(st, numStr);
                  }),
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Progress'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProgressOption(st, '0.0', 0.0),
                    _buildProgressOption(st, '0.25', 0.25),
                    _buildProgressOption(st, '0.5', 0.5),
                    _buildProgressOption(st, '0.75', 0.75),
                    _buildProgressOption(st, '1.0', 1.0),
                  ],
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Mood'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMoodOption(st, '😄'),
                    _buildMoodOption(st, '🙂'),
                    _buildMoodOption(st, '😐'),
                    _buildMoodOption(st, '😔'),
                    _buildMoodOption(st, '😫'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFlagOption(Task st, String value, Color color) {
    final isSelected = st.symbolType == 'flag' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateSubTaskSymbols(st, 'flag', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.flag_rounded, color: color, size: 20),
      ),
    );
  }

  Widget _buildNumberOption(Task st, String value) {
    final isSelected = st.symbolType == 'number' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateSubTaskSymbols(st, 'number', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryLight : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOption(Task st, String value, double progress) {
    final isSelected = st.symbolType == 'progress' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateSubTaskSymbols(st, 'progress', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CustomPaint(
              painter: PieChartPainter(
                progress: progress,
                color: AppTheme.secondaryColor,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodOption(Task st, String value) {
    final isSelected = st.symbolType == 'mood' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateSubTaskSymbols(st, 'mood', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white54 : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Color _getFlagColor(String? value) {
    switch (value) {
      case 'red':
        return Colors.redAccent;
      case 'yellow':
        return Colors.amber;
      case 'purple':
        return Colors.purpleAccent;
      case 'blue':
        return Colors.blueAccent;
      case 'green':
        return Colors.greenAccent;
      default:
        return Colors.white30;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatTimeString(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2) return time24h;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final hourOfPeriod = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';
      final minuteStr = minute.toString().padLeft(2, '0');
      
      return '$hourOfPeriod:$minuteStr $period';
    } catch (_) {
      return time24h;
    }
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

class PieChartPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  PieChartPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2,
        progress * 2 * 3.141592653589793,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
