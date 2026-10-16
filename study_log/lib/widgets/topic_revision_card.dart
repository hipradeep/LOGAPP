import 'package:flutter/material.dart';
import '../models/topic_revision.dart';
import '../theme/app_theme.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';
import 'app_spacers.dart';
import 'compact_list_item.dart';
import 'course_icon_chip.dart';
import 'topic_revision_badge.dart';

/// Card component representing an individual topic revision ladder item.
///
/// Features:
/// - Course glyph chip
/// - Topic title with [TopicRevisionBadge] (R1..R5 / Mastered)
/// - Course & module breadcrumbs (`Course › Module`)
/// - Due countdown indicator (Due today, In 3d, Overdue 2d)
/// - Quick action buttons: "Revise" (timer session) and "Complete" (quick advance)
class TopicRevisionCard extends StatelessWidget {
  final TopicRevision revision;
  final VoidCallback onTap;
  final VoidCallback? onRevise;
  final VoidCallback? onQuickComplete;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;
  final bool showTypeBadge;

  const TopicRevisionCard({
    super.key,
    required this.revision,
    required this.onTap,
    this.onRevise,
    this.onQuickComplete,
    this.onLongPress,
    this.onOptionsTap,
    this.showTypeBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = _daysUntilDue(now, revision.nextRevisionAt);
    final isDue = revision.isDueAt(now);
    final dueColor = _dueColor(context, days, isDue, revision);

    return CompactListItem(
      margin: EdgeInsets.zero,
      leading: CourseIconChip(
        courseId: revision.courseId,
        size: 38,
        radius: 10,
      ),
      title: revision.title,
      titleBadge: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTypeBadge) ...[
            const _TopicTypeBadge(),
            const HGapXs(),
          ],
          TopicRevisionBadge(revision: revision),
        ],
      ),
      courseName: courseTitleFor(revision),
      moduleName: moduleTitleFor(revision),
      bottom: Row(
        children: [
          Icon(
            revision.isFinished
                ? Icons.check_circle_rounded
                : Icons.access_time_rounded,   
            size: 13,
            color: isDue ? AppTheme.errorColor : dueColor,
          ),
          const HGapXs(),
          Expanded(
            child: Text(
              _dueLabel(days, isDue, revision),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDue ? AppTheme.errorColor : dueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!revision.isFinished) ...[
            if (onQuickComplete != null && isDue) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onQuickComplete,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Complete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const HGapXs(),
            ],
            if (onRevise != null) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRevise,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDue
                          ? AppTheme.primaryColor
                          : AppTheme.pastelIndigo(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 13,
                          color: isDue
                              ? Colors.white
                              : AppTheme.pastelIndigoText(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Revise',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDue
                                ? Colors.white
                                : AppTheme.pastelIndigoText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      onOptionsTap: onOptionsTap,
    );
  }

  static int _daysUntilDue(DateTime now, DateTime nextRevisionAt) {
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(nextRevisionAt.year, nextRevisionAt.month, nextRevisionAt.day);
    return dueDay.difference(today).inDays;
  }

  static String courseTitleFor(TopicRevision revision) {
    if (revision.courseId.isNotEmpty && getIt.isRegistered<CoursesController>()) {
      final course = getIt<CoursesController>().getCourseById(revision.courseId);
      if (course != null && course.title.isNotEmpty) return course.title;
    }
    return '';
  }

  static String moduleTitleFor(TopicRevision revision) {
    if (revision.moduleId.isNotEmpty && getIt.isRegistered<OngoingModulesController>()) {
      return getIt<OngoingModulesController>().moduleTitleFor(revision.moduleId);
    }
    return '';
  }

  static String _dueLabel(int days, bool isDue, TopicRevision revision) {
    if (revision.isFinished) return 'Mastered';
    if (isDue) return days < 0 ? 'Overdue ${days.abs()}d' : 'Due today';
    if (days <= 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'In ${days}d';
  }

  static Color _dueColor(
      BuildContext context, int days, bool isDue, TopicRevision revision) {
    if (revision.isFinished) return AppTheme.successColor;
    if (isDue) return AppTheme.errorColor;
    return AppTheme.textSecondaryColor(context);
  }
}

/// Pastel tag identifying the item as a single topic revision.
class _TopicTypeBadge extends StatelessWidget {
  const _TopicTypeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.pastelIndigo(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.pastelIndigoBorder(context),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.topic_outlined,
            size: 11,
            color: AppTheme.pastelIndigoText(context),
          ),
          const HGapXs(),
          Text(
            'Topic',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.pastelIndigoText(context),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

