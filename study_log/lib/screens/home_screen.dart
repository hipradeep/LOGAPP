import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FullScreenPage(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: AppTheme.primaryColor),
        onPressed: () {},
        tooltip: 'Menu',
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
          onPressed: () {},
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryColor),
          onPressed: () {},
          tooltip: 'Notifications',
        ),
      ],
      children: const [
        VGapSm(),
        _HomeHeader(),
        VGapXl(),
        _HomeEmptyContent(),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose your',
          style: AppTheme.textLead,
        ),
        const VGapXs(),
        Text(
          'Study Activity',
          style: AppTheme.headingMedium,
        ),
      ],
    );
  }
}

class _HomeEmptyContent extends StatelessWidget {
  const _HomeEmptyContent();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.auto_stories_outlined,
      title: 'Ready to study?',
      description: 'Your study sessions, tracked logs, and daily targets will appear here.',
      actionLabel: 'New Activity',
    );
  }
}
