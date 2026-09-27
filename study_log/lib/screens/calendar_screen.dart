import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/full_screen_page.dart';

/// Empty placeholder screen for the Calendar tab.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FullScreenPage(
      title: 'Calendar',
      showBackButton: false,
      children: [
        AppEmptyState(
          icon: Icons.calendar_month_rounded,
          title: 'Study Calendar',
          description: 'Upcoming scheduled study blocks, deadlines, and milestones will be mapped here.',
        ),
      ],
    );
  }
}
