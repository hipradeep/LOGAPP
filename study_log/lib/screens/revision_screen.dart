import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/full_screen_page.dart';

/// Empty placeholder screen for the Revision tab.
class RevisionScreen extends StatelessWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FullScreenPage(
      title: 'Revision',
      showBackButton: false,
      children: [
        AppEmptyState(
          icon: Icons.sync_rounded,
          title: 'No Revision Scheduled',
          description: 'Spaced repetition sessions and revision cards will appear here.',
        ),
      ],
    );
  }
}
