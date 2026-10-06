import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';
import '../widgets/recent_activity_card.dart';
import 'my_progress_screen.dart';
import 'recent_activity_screen.dart';

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

  void _openRecentActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecentActivityScreen()),
    );
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
              title: 'Activity',
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
                        SummaryStatsCard(controller: _progressController),
                        const VGapMd(),
                        ActivityBreakdownCard(controller: _progressController),
                        const VGapMd(),
                        RecentActivityCard(
                          controller: _progressController,
                          showViewAll: false,
                          onItemTap: (_) => _openRecentActivity(context),
                        ),
                        const VGapSm(),
                        GestureDetector(
                          onTap: () => _openRecentActivity(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(
                                AppTheme.defaultBorderRadius,
                              ),
                              border: Border.all(
                                color: AppTheme.borderColor(context),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'View All Activity →',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
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
