import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';
import '../widgets/streak_highlights_card.dart';
import '../widgets/strike_heatmap_card.dart';
import '../widgets/summary_stats_card.dart';
import '../widgets/activity_breakdown_card.dart';
import '../widgets/recent_activity_card.dart';

export '../widgets/streak_highlights_card.dart';
export '../widgets/strike_heatmap_card.dart';
export '../widgets/summary_stats_card.dart';
export '../widgets/activity_breakdown_card.dart';
export '../widgets/recent_activity_card.dart';

/// "My Progress" screen showing:
/// - Top Card: Total active days and Max streak
/// - Activity Card: Calendar heatmap grid of study & revision activity
class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  late final ProgressController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = getIt<ProgressController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressController.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'My Progress',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: ListenableBuilder(
                  listenable: _progressController,
                  builder: (context, _) {
                    if (_progressController.isLoading &&
                        _progressController.totalTopicsFinished == 0 &&
                        _progressController.totalTopicRevisions == 0) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreakHighlightsCard(controller: _progressController),
                        const VGapMd(),
                        StrikeHeatmapCard(controller: _progressController),
                        const VGapMd(),
                        SummaryStatsCard(controller: _progressController),
                        const VGapMd(),
                        ActivityBreakdownCard(controller: _progressController),
                        const VGapMd(),
                        RecentActivityCard(controller: _progressController),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
