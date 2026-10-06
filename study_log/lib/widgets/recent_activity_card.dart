import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/progress_controller.dart';
import '../screens/recent_activity_screen.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable card displaying daily aggregate study progress.
/// Used on Home Screen, Activity Screen, and My Progress Screen.
class RecentActivityCard extends StatefulWidget {
  final ProgressController controller;
  final int maxDays;
  final VoidCallback? onViewAll;
  final void Function(DailyProgressActivity item)? onItemTap;
  final bool showViewAll;
  final bool showHeader;
  final String title;

  const RecentActivityCard({
    super.key,
    required this.controller,
    this.maxDays = 4,
    this.onViewAll,
    this.onItemTap,
    this.showViewAll = true,
    this.showHeader = true,
    this.title = 'Recent Activity',
  });

  @override
  State<RecentActivityCard> createState() => RecentActivityCardState();
}

class RecentActivityCardState extends State<RecentActivityCard> {
  bool _showAll = false;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  static final DateFormat _weekdayFormat = DateFormat('EEE');

  static String _formatHours(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes / 60.0;
    if (hours < 1.0) {
      return '${minutes}m';
    }
    if (hours == hours.truncateToDouble()) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final allRecent = widget.controller.recentActivities;
    final displayItems = _showAll ? allRecent : allRecent.take(widget.maxDays).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                if (widget.showViewAll)
                  GestureDetector(
                    onTap: widget.onViewAll ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RecentActivityScreen()),
                          );
                        },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        HGapXs(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const VGapSm(),
          ],
          if (displayItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  widget.maxDays <= 3
                      ? 'No activity recorded yet in the last 3 days.\nComplete topics and revisions to build your streak!'
                      : 'No activity recorded yet in the last 3 months.\nComplete topics and revisions to build your streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: displayItems.length,
              separatorBuilder: (context, _) => Divider(
                color: AppTheme.borderColor(context),
                height: 16,
              ),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return InkWell(
                  onTap: () {
                    if (widget.onItemTap != null) {
                      widget.onItemTap!(item);
                    } else if (widget.onViewAll != null) {
                      widget.onViewAll!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecentActivityScreen()),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Date column: date + weekday inline
                        SizedBox(
                          width: 68,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dateFormat.format(item.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _weekdayFormat.format(item.date),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const HGapXs(),
                        // Topics Finished
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF10B981),
                                  size: 13,
                                ),
                              ),
                              const HGapXs(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.topicsFinished}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor(context),
                                      ),
                                    ),
                                    Text(
                                      'Topics',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSecondaryColor(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Revisions
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0EEFF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.sync_rounded,
                                  color: Color(0xFF7A6EFC),
                                  size: 13,
                                ),
                              ),
                              const HGapXs(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.revisionsDone}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor(context),
                                      ),
                                    ),
                                    Text(
                                      'Revisions',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSecondaryColor(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Hours Spent
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: item.studyMinutes > 0
                                      ? const Color(0xFFFEF3C7)
                                      : AppTheme.surfaceVariant(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.schedule_rounded,
                                  color: item.studyMinutes > 0
                                      ? const Color(0xFFD97706)
                                      : AppTheme.textMutedColor(context),
                                  size: 13,
                                ),
                              ),
                              const HGapXs(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatHours(item.studyMinutes),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.studyMinutes > 0
                                            ? AppTheme.textPrimaryColor(context)
                                            : AppTheme.textMutedColor(context),
                                      ),
                                    ),
                                    Text(
                                      'Hours',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSecondaryColor(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
