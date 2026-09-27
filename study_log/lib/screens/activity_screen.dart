import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_empty_state.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FullScreenPage(
      title: 'Activities',
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
          onPressed: () {},
          tooltip: 'Filter',
        ),
      ],
      children: const [
        VGapSm(),
        _ActivityEmptyContent(),
      ],
    );
  }
}

class _ActivityEmptyContent extends StatelessWidget {
  const _ActivityEmptyContent();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.explore_outlined,
      title: 'No Activities Yet',
      description: 'Explore recommended activities, track tasks, and review study history here.',
      actionLabel: 'Explore Activities',
    );
  }
}
