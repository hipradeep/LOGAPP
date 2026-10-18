import 'package:flutter/material.dart';
import '../models/topic.dart';
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
/// - Revision level badge [TopicRevisionBadge] (R1..R5 / Mastered)
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
          TopicRevisionBadge(revision: revision),
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

