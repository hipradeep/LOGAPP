import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_icons.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../services/firebase_service.dart';

class ActivityCheckInSheet extends StatefulWidget {
  final Activity activity;
  final bool useMockData;

  const ActivityCheckInSheet({
    Key? key,
    required this.activity,
    required this.useMockData,
  }) : super(key: key);

  @override
  State<ActivityCheckInSheet> createState() => _ActivityCheckInSheetState();
}

class _ActivityCheckInSheetState extends State<ActivityCheckInSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  final DateTime _now = DateTime.now();
  final TextEditingController _subTaskTextController = TextEditingController();
  final FocusNode _subTaskFocusNode = FocusNode();
  late Stream<List<CheckIn>> _checkInsStream;
  TimeOfDay? _subTaskTime;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  void initState() {
    super.initState();
    _checkInsStream = _firebaseService.getCheckInsStream(widget.activity.id);
  }

  @override
  void dispose() {
    _subTaskTextController.dispose();
    _subTaskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: widget.useMockData
                  ? _buildSheetContent(scrollController, _getLocalCheckIns())
                  : StreamBuilder<List<CheckIn>>(
                      stream: _checkInsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Error loading history', style: TextStyle(color: AppTheme.errorColor)),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          );
                        }
                        final checkIns = snapshot.data ?? [];
                        return _buildSheetContent(scrollController, checkIns);
                      },
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<CheckIn> _getLocalCheckIns() {
    final checkIns = FirebaseService.mockCheckIns
        .where((c) => c.activityId == widget.activity.id)
        .toList();
    // Sort descending by timestamp
    checkIns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return checkIns;
  }

  Widget _buildSheetContent(ScrollController scrollController, List<CheckIn> checkIns) {
    // Calculate today's completed check-ins
    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();
    final todayCount = todayCheckIns.length;
    final targetCount = widget.activity.targetCount;
    final isMultiple = targetCount > 1;
    final bool isCompleted = todayCount >= targetCount;

    return Column(
      children: [
        const VGapMd(),
        // Drawer drag handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const VGapLg(),
        
        // Sheet Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.name,
                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isMultiple
                          ? 'Target: $targetCount times per day (Today: $todayCount)'
                          : 'Daily check-in',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),
        ),
        const VGapLg(),
        const Divider(color: Colors.white10, height: 1, indent: 24, endIndent: 24),
        const VGapMd(),

        Expanded(
          child: ListView(
            // Detached scrollController to prevent keyboard focus-stealing
            controller: null,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              // 1. Current Check-In Section
              _buildCurrentCheckInCard(isCompleted, todayCount, targetCount, isMultiple),
              const VGapLg(),
              
              // Progress indicator for multiple check-ins
              if (isMultiple) ...[
                _buildProgressBar(todayCount, targetCount),
                const VGapLg(),
              ],
              


              // Sub-tasks checklist section (if activity has sub-tasks enabled)
              if (widget.activity.hasSubTasks) ...[
                _buildSubTasksSection(checkIns, !widget.useMockData),
                const VGapLg(),
              ],
              
              // 2. History Section Title
              Row(
                children: [
                  const IconSm(Icons.history_rounded, color: AppTheme.textSecondary),
                  const HGapSm(),
                  Text(
                    'History Logs'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const VGapSm(),

              // 3. History Checklist List
              _buildHistorySection(checkIns),
            ],
          ),
        ),
      ],
    );
  }

  // CURRENT DATE & TIME CHECK-IN WIDGET
  Widget _buildCurrentCheckInCard(bool isCompleted, int todayCount, int targetCount, bool isMultiple) {
    final formattedTime = DateFormat('h:mm a').format(_now);
    final formattedDate = DateFormat('MMM d, yyyy').format(_now);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isCompleted ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const IconMd(Icons.timer_outlined, color: AppTheme.primaryLight),
              ),
              const HGapMd(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMultiple ? 'Log Check-in' : 'Current Check-in',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const VGapXs(),
                  Text(
                    isMultiple
                        ? 'Completed $todayCount of $targetCount times today'
                        : '$formattedDate at $formattedTime',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          
          // Check-in toggle checkbox or add button
          GestureDetector(
            onTap: () => _handleTodayCheckIn(isCompleted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : const Icon(Icons.add, size: 18, color: AppTheme.primaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int count, int target) {
    final double percent = (count / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Progress',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
            ),
            Text(
              '${(percent * 100).toInt()}% completed',
              style: AppTheme.bodySmall.copyWith(
                color: percent >= 1.0 ? AppTheme.successColor : AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const VGapXs(),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 8,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: percent >= 1.0
                        ? [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.7)]
                        : [AppTheme.primaryColor, AppTheme.primaryLight],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // HISTORY CHECKLIST LIST VIEW
  Widget _buildHistorySection(List<CheckIn> checkIns) {
    final completedCheckIns = checkIns.where((c) => c.checked).toList();
    if (completedCheckIns.isEmpty) {
      return _buildEmptyHistoryState();
    }
    return _buildHistoryList(completedCheckIns, isLive: !widget.useMockData);
  }

  Widget _buildHistoryList(List<CheckIn> checkIns, {required bool isLive}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: checkIns.length,
      itemBuilder: (context, index) {
        final checkIn = checkIns[index];
        final formattedDate = DateFormat('EEEE, MMM d, yyyy • h:mm a').format(checkIn.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: checkIn.checked ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.02),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: checkIn.checked ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedDate,
                            style: AppTheme.bodyMedium.copyWith(
                              color: checkIn.checked ? Colors.white : AppTheme.textSecondary,
                              fontWeight: checkIn.checked ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          if (checkIn.subTaskName != null) ...[
                            const VGapXs(),
                            Text(
                              checkIn.subTaskName!.contains('|')
                                  ? 'Sub-task: ${checkIn.subTaskName!.split('|').first} (${_formatTimeString(checkIn.subTaskName!.split('|').last)})'
                                  : 'Sub-task: ${checkIn.subTaskName}',
                              style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkbox to check/uncheck past check-ins
                  GestureDetector(
                    onTap: () => _toggleCheckIn(checkIn, isLive),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: checkIn.checked ? AppTheme.primaryColor : Colors.transparent,
                        border: Border.all(
                          color: checkIn.checked ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: checkIn.checked
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const HGapMd(),
                  // Delete Check-in
                  GestureDetector(
                    onTap: () => _deleteCheckIn(checkIn.id, isLive),
                    child: const Icon(
                       Icons.delete_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistoryState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'No check-ins logged yet.',
        style: AppTheme.bodyMedium.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  // ACTIONS
  void _handleTodayCheckIn(bool isCompleted) async {
    // For single check-ins, limit to 1 per day
    if (widget.activity.trackingType == 'single' && isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already checked in today!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final checkInNow = DateTime.now();
    if (widget.useMockData) {
      FirebaseService.mockCheckIns.add(
        CheckIn(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          activityId: widget.activity.id,
          timestamp: checkInNow,
          checked: true,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged check-in locally.'), duration: Duration(seconds: 1)),
      );
      setState(() {});
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.createCheckIn(widget.activity.id, checkInNow, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged check-in to Firestore.'), duration: Duration(seconds: 1)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check in: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _toggleCheckIn(CheckIn checkIn, bool isLive) async {
    final newChecked = !checkIn.checked;
    if (!isLive) {
      setState(() {
        final idx = FirebaseService.mockCheckIns.indexWhere((c) => c.id == checkIn.id);
        if (idx != -1) {
          FirebaseService.mockCheckIns[idx] = FirebaseService.mockCheckIns[idx].copyWith(checked: newChecked);
        }
      });
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.toggleCheckIn(checkIn.id, newChecked);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _deleteCheckIn(String id, bool isLive) async {
    if (!isLive) {
      setState(() {
        FirebaseService.mockCheckIns.removeWhere((c) => c.id == id);
      });
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.deleteCheckIn(id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete check-in: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // SUB-TASKS UI SECTION
  Widget _buildSubTasksSection(List<CheckIn> checkIns, bool isLive) {
    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp)).toList();

    final List<_SubTaskUiItem> uiItems = [];

    // 1. Add template sub-tasks
    for (var template in widget.activity.subTaskTemplates) {
      final match = todayCheckIns.firstWhere(
        (c) => c.subTaskName == template,
        orElse: () => CheckIn(id: '', activityId: '', timestamp: DateTime.now(), checked: false),
      );
      uiItems.add(_SubTaskUiItem(
        name: template,
        checked: match.id.isNotEmpty ? match.checked : false,
        checkInId: match.id.isNotEmpty ? match.id : null,
        isTemplate: true,
      ));
    }

    // 2. Add custom sub-tasks
    for (var c in todayCheckIns) {
      if (c.subTaskName != null && !widget.activity.subTaskTemplates.contains(c.subTaskName)) {
        uiItems.add(_SubTaskUiItem(
          name: c.subTaskName!,
          checked: c.checked,
          checkInId: c.id,
          isTemplate: false,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconSm(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary),
            const HGapSm(),
            Text(
              'Sub-tasks Checklist'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const VGapSm(),

        // Underline Input Row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subTaskTextController,
                  focusNode: _subTaskFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add daily sub-task...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24, width: 1),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) => _addSubTask(value, isLive),
                ),
              ),
              if (_subTaskTime != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimeForDisplay(_subTaskTime!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _subTaskTime = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickSubTaskTime,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: _subTaskTime != null ? AppTheme.primaryLight : AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _addSubTask(_subTaskTextController.text, isLive),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppTheme.primaryLight,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const VGapSm(),

        // List of sub-tasks
        if (uiItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'No sub-tasks yet today. Add one above!',
                style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          Column(
            children: uiItems.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.checked 
                        ? AppTheme.primaryColor.withValues(alpha: 0.15) 
                        : Colors.white.withValues(alpha: 0.02),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleSubTask(item, isLive),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: item.checked ? AppTheme.primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: item.checked 
                                      ? AppTheme.primaryColor 
                                      : AppTheme.textSecondary.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: item.checked
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const HGapMd(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name.split('|').first,
                                  style: TextStyle(
                                    color: item.checked ? AppTheme.textSecondary : Colors.white,
                                    decoration: item.checked ? TextDecoration.lineThrough : null,
                                    fontSize: 13,
                                  ),
                                ),
                                if (item.name.contains('|')) ...[
                                  const SizedBox(height: 4),
                                  Container(
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
                                          Icons.access_time_rounded,
                                          size: 10,
                                          color: item.checked
                                              ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                              : AppTheme.primaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimeString(item.name.split('|').last),
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
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!item.isTemplate)
                      GestureDetector(
                        onTap: () => _deleteCheckIn(item.checkInId!, isLive),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.errorColor.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _addSubTask(String name, bool isLive) async {
    name = name.trim();
    if (name.isEmpty) return;
    final taskNameWithSchedule = _subTaskTime != null
        ? '$name|${_formatTimeOfDay(_subTaskTime)}'
        : name;
    _subTaskTextController.clear();
    
    final timestamp = DateTime.now();
    if (!isLive) {
      setState(() {
        FirebaseService.mockCheckIns.add(
          CheckIn(
            id: 'c-${DateTime.now().millisecondsSinceEpoch}',
            activityId: widget.activity.id,
            timestamp: timestamp,
            checked: false,
            subTaskName: taskNameWithSchedule,
          ),
        );
        _subTaskTime = null;
      });
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.createCheckIn(widget.activity.id, timestamp, false, subTaskName: taskNameWithSchedule);
        setState(() {
          _subTaskTime = null;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  String? _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeForDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeString(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2) return time24h;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final time = TimeOfDay(hour: hour, minute: minute);
      return _formatTimeForDisplay(time);
    } catch (_) {
      return time24h;
    }
  }

  Future<void> _pickSubTaskTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _subTaskTime ?? const TimeOfDay(hour: 8, minute: 0),
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
      setState(() => _subTaskTime = picked);
    }
  }

  void _toggleSubTask(_SubTaskUiItem item, bool isLive) async {
    final newChecked = !item.checked;
    if (!isLive) {
      if (item.checkInId != null) {
        setState(() {
          final idx = FirebaseService.mockCheckIns.indexWhere((c) => c.id == item.checkInId);
          if (idx != -1) {
            FirebaseService.mockCheckIns[idx] = FirebaseService.mockCheckIns[idx].copyWith(checked: newChecked);
          }
        });
        FirebaseService.notifyCheckInsChanged();
      } else {
        setState(() {
          FirebaseService.mockCheckIns.add(
            CheckIn(
              id: 'c-${DateTime.now().millisecondsSinceEpoch}',
              activityId: widget.activity.id,
              timestamp: DateTime.now(),
              checked: newChecked,
              subTaskName: item.name,
            ),
          );
        });
        FirebaseService.notifyCheckInsChanged();
      }
    } else {
      try {
        if (item.checkInId != null) {
          await _firebaseService.toggleCheckIn(item.checkInId!, newChecked);
        } else {
          await _firebaseService.createCheckIn(widget.activity.id, DateTime.now(), newChecked, subTaskName: item.name);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class _SubTaskUiItem {
  final String name;
  final bool checked;
  final String? checkInId;
  final bool isTemplate;

  _SubTaskUiItem({
    required this.name,
    required this.checked,
    this.checkInId,
    required this.isTemplate,
  });
}


