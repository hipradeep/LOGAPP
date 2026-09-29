import 'package:flutter/material.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';
import 'my_progress_screen.dart';

/// Activity Screen:
/// Displays detailed activity metrics moved from the profile:
/// - Summary Stats Card (Study Volume: Topics Finished vs Topic Revisions)
/// - Activity Breakdown Card (Daily Breakdown stacked bar chart 7D/14D/30D)
/// - Recent Activity Card (Day-by-day activity log)
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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
    return FullScreenPage(
      title: 'Activity',
      showBackButton: true,
      children: [
        ListenableBuilder(
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
                const VGapSm(),
                SummaryStatsCard(controller: _progressController),
                const VGapMd(),
                ActivityBreakdownCard(controller: _progressController),
                const VGapMd(),
                RecentActivityCard(controller: _progressController),
              ],
            );
          },
        ),
      ],
    );
  }
}
