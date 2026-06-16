import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'vertical_calendar_month.dart';

class CheckInHistorySheet extends StatefulWidget {
  const CheckInHistorySheet({super.key});

  @override
  State<CheckInHistorySheet> createState() => _CheckInHistorySheetState();
}

class _CheckInHistorySheetState extends State<CheckInHistorySheet> {
  late final List<DateTime> _months;
  final GlobalKey _currentMonthKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Chronological: Joining Month (Feb) to Next Month
    final joinDate = DateTime(2026, 2, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    
    _months = [];
    DateTime current = joinDate;
    while (current.isBefore(nextMonth) || current.isAtSameMomentAs(nextMonth)) {
      _months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // Accurately scroll to the current month's key
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            final now = DateTime.now();
            int index = _months.indexWhere((m) => m.month == now.month && m.year == now.year);
            if (index != -1) {
              // Initial rough jump to avoid showing Feb even for a split second
              scrollController.jumpTo(index * 340.0);
              
              // Refined centering after the sheet settles
              Future.delayed(const Duration(milliseconds: 200), () {
                if (_currentMonthKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _currentMonthKey.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    alignment: 0.5,
                  );
                }
              });
            }
          }
        });

        Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background(context).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppTheme.borderColor(context), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Column(
                children: [
                  const VGapMd(),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const VGapLg(),
                  
                  // Persistent Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Activity History', style: AppTheme.headingMedium.copyWith(fontSize: 28)),
                            Text(
                              'Your gym consistency over time',
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor(context)),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.subtleFillColor(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VGapLg(),

                  // Days of the Week Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
                        return SizedBox(
                          width: (MediaQuery.of(context).size.width - 48 - 48) / 7, // Account for list padding and grid gaps
                          child: Center(
                            child: Text(
                              day,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const VGapSm(),
                  Divider(color: AppTheme.borderColor(context), indent: 24, endIndent: 24),
                  
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      children: _months.map((monthDate) {
                        final now = DateTime.now();
                        final isCurrentMonth = monthDate.month == now.month && monthDate.year == now.year;
                        final isFuture = monthDate.isAfter(DateTime(now.year, now.month, 1));
                        
                        // Dummy logic for attended days
                        List<int> attendedDays = [];
                        if (isCurrentMonth) {
                          attendedDays = [now.day, now.day - 1, now.day - 3];
                        } else if (monthDate.month == 2) {
                          attendedDays = [15, 16, 18, 20, 22, 25];
                        } else if (!isFuture) {
                          attendedDays = [5, 12, 18, 24];
                        }

                        return Padding(
                          key: isCurrentMonth ? _currentMonthKey : null,
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Opacity(
                            opacity: isFuture ? 0.4 : 1.0,
                            child: VerticalCalendarMonth(
                              month: monthDate,
                              attendedDays: attendedDays,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
