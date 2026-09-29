import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable pastel pill displaying the course name with a school icon.
///
/// Matches the styling of [ModuleContextPill] across [CourseDetailScreen] and [AddModuleScreen].
class CourseContextPill extends StatelessWidget {
  final String courseTitle;
  final EdgeInsetsGeometry? padding;

  const CourseContextPill({
    super.key,
    required this.courseTitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (courseTitle.isEmpty) return const SizedBox.shrink();

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: AppTheme.pastelPurple(context),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_rounded,
            size: 14,
            color: AppTheme.pastelPurpleText(context),
          ),
          const HGapXs(),
          Flexible(
            child: Text(
              courseTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.pastelPurpleText(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (padding != null) {
      pill = Padding(padding: padding!, child: pill);
    }

    return pill;
  }
}
