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
  });

  @override
  State<MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<MilestonesTab> {
  String _selectedCategory = 'All';
  String? _expandedSubTaskId;
  final Map<String, TextEditingController> _nestedControllers = {};

  // Accordion open/close state
  bool _todayExpanded = true;
  bool _futureExpanded = true;
  bool _completedExpanded = true;

  @override
  void dispose() {
    for (var controller in _nestedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Capsule list
        _buildCategoryBar(categories),
        const VGapMd(),

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
    final timeStr = st.scheduledTime;
    final totalCount = st.subTasks.length;
    final completedCount = st.subTasks.where((i) => i.checked).length;

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
                children: [
                  // 1. Left Checkbox
                  GestureDetector(
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
                        if (timeStr != null || totalCount > 0 || !_isToday(st.timestamp) || parent.repeatDays.length < 7) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Subtask ratio branch badge
                              if (totalCount > 0) ...[
                                const Icon(
                                  Icons.account_tree_outlined,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$completedCount/$totalCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Alarm time badge
                              if (timeStr != null) ...[
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimeString(timeStr),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Repeat arrows badge
                              if (parent.repeatDays.length < 7) ...[
                                const Icon(
                                  Icons.repeat_rounded,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Date badge (if not today)
                              if (!_isToday(st.timestamp)) ...[
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd-MM').format(st.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // 3. Right Symbol Indicator
                  GestureDetector(
                    onTap: () => _showSymbolSelectionDialog(st),
                    child: _buildSymbolIndicator(st),
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: item.checked,
                              activeColor: AppTheme.primaryColor,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                if (val != null) {
                                  _toggleNestedItem(st, idx, val);
                                }
                              },
                            ),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  color: item.checked ? AppTheme.textSecondary : Colors.white70,
                                  fontSize: 12,
                                  decoration: item.checked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
                              onPressed: () => _deleteNestedItem(st, idx),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Inline Add Nested Item form
                  _buildAddNestedItemForm(st),
                  const VGapSm(),

                  // Subtask Meta actions (Date selection & Delete Subtask)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickSubTaskDate(st),
                        icon: const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primaryLight),
                        label: Text(
                          DateFormat('MMM d, yyyy').format(st.timestamp),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.03),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Future<void> _pickSubTaskDate(Task st) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: st.timestamp,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final newDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        st.timestamp.hour,
        st.timestamp.minute,
      );
      widget.onToggleSubTask(st.copyWith(timestamp: newDate), st.checked);
    }
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
