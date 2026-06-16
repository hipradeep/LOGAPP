import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/milestones_tab.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Register theme dependency to rebuild on theme switch
    return const FullScreenPage(
      showScaffold: false,
      isScrollable: false,
      title: 'Milestones',
      backgroundWidgets: [
        GlowBlob(
          top: -40,
          left: -40,
          size: 220,
          color: AppTheme.primaryColor,
          opacity: 0.08,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 260,
          color: AppTheme.secondaryColor,
          opacity: 0.05,
        ),
      ],
      children: [
        Expanded(
          child: MilestonesTab(),
        ),
      ],
    );
  }
}
