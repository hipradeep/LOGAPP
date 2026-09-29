import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Reusable pastel pill displaying the module name with a book icon.
///
/// Matches the styling on [AddTopicScreen] and [ModuleDetailScreen].
class ModuleContextPill extends StatelessWidget {
  final String moduleTitle;
  final EdgeInsetsGeometry? padding;

  const ModuleContextPill({
    super.key,
    required this.moduleTitle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (moduleTitle.isEmpty) return const SizedBox.shrink();

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
            Icons.auto_stories_rounded,
            size: 14,
            color: AppTheme.pastelPurpleText(context),
          ),
          const HGapXs(),
          Flexible(
            child: Text(
              moduleTitle,
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
