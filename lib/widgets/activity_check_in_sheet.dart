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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
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
                      stream: _firebaseService.getCheckInsStream(widget.activity.id),
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
    final isMultiple = widget.activity.trackingType == 'multiple';
    
    final bool isCompleted = isMultiple ? todayCount >= targetCount : todayCount >= 1;

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
                          : 'Daily habit check-in',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
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
            controller: scrollController,
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
              if (checkIns.isEmpty)
                _buildEmptyHistoryState()
              else
                _buildHistoryList(checkIns, isLive: !widget.useMockData),
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
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isCompleted ? AppTheme.primaryColor.withOpacity(0.4) : Colors.white.withOpacity(0.05),
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
                  color: AppTheme.primaryColor.withOpacity(0.1),
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
                  color: isCompleted ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.6),
                  width: 2.5,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
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
            color: Colors.white.withOpacity(0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: percent >= 1.0
                        ? [AppTheme.successColor, AppTheme.successColor.withOpacity(0.7)]
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
            color: AppTheme.surfaceColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: checkIn.checked ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.02),
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
                      color: checkIn.checked ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: AppTheme.bodyMedium.copyWith(
                          color: checkIn.checked ? Colors.white : AppTheme.textSecondary,
                          fontWeight: checkIn.checked ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
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
                          color: checkIn.checked ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.5),
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
    // For daily habits, limit to 1 per day
    if (widget.activity.trackingType != 'multiple' && isCompleted) {
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
}


