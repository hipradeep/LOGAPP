import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class TabHeader extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  const TabHeader({
    super.key,
    this.title = '',
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.spacingMd,
      AppTheme.spacingSm + AppTheme.spacingXs,
      AppTheme.spacingMd,
      AppTheme.spacingSm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget ??
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineSmall,
                      ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const VGapXs(),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const HGapSm(),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
