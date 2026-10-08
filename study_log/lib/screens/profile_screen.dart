import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/tab_header.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import 'my_progress_screen.dart';
import 'activity_screen.dart';
import 'courses_screen.dart';
import 'settings_screen.dart';

/// Profile Screen:
/// - 22px bold "Profile" header with gear (settings ⚙️) icon in top right
/// - User Hero Card with avatar, user role, and live learning stats (Courses, Streak, Revisions)
/// - Top highlights card (Total active days & Max streak)
/// - Activity calendar strike heatmap card
/// - Below the strike card: menu items for "Activity" (Volume, Breakdown, Recent) and "Courses"
/// - Pull-to-refresh to sync all progress and learning metrics
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProgressController _progressController;
  

  @override
  void initState() {
    super.initState();
    _progressController = getIt<ProgressController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressController.refresh();
      if (getIt.isRegistered<RevisionController>()) {
        getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<CoursesController>()) {
        getIt<CoursesController>().loadCourses();
      }
    });
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityScreen()),
    );
  }

  void _openCourses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoursesScreen()),
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
            TabHeader(
              title: 'Profile',
              subtitle: 'Your learning stats & settings',
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: AppTheme.textPrimaryColor(context),
                    size: 22,
                  ),
                  onPressed: () => _openSettings(context),
                  tooltip: 'Settings',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 4,
                  bottom: bottomSafe + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _UserProfileCard(),
                    const VGapMd(),
                    ListenableBuilder(
                      listenable: _progressController,
                      builder: (context, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StreakHighlightsCard(controller: _progressController),
                            const VGapMd(),
                            StrikeHeatmapCard(controller: _progressController),
                            const VGapMd(),
                            const _SectionHeader(title: 'MENU'),
                            _ProfileMenuCard(
                              onActivityTap: () => _openActivity(context),
                              onCoursesTap: () => _openCourses(context),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  Future<void> _handleSignIn(BuildContext context, CloudSyncController? ctrl) async {
    if (ctrl == null || ctrl.isBusy) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const HGapMd(),
                Text(
                  'Connecting to Google...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    bool success = false;
    try {
      success = await ctrl.signIn();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as ${ctrl.displayName ?? ctrl.userEmail ?? "User"}!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    } else if (ctrl.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ctrl.errorMessage!),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncCtrl = getIt.isRegistered<CloudSyncController>()
        ? getIt<CloudSyncController>()
        : null;
    final coursesCtrl = getIt.isRegistered<CoursesController>()
        ? getIt<CoursesController>()
        : null;
    final revisionCtrl = getIt.isRegistered<RevisionController>()
        ? getIt<RevisionController>()
        : null;
    final progressCtrl = getIt.isRegistered<ProgressController>()
        ? getIt<ProgressController>()
        : null;

    return ListenableBuilder(
      listenable: Listenable.merge([
        if (syncCtrl != null) syncCtrl,
        if (coursesCtrl != null) coursesCtrl,
        if (revisionCtrl != null) revisionCtrl,
        if (progressCtrl != null) progressCtrl,
      ]),
      builder: (context, _) {
        final isSignedIn = syncCtrl?.isSignedIn ?? false;
        final courseCount = coursesCtrl?.courses.length ?? 0;
        final int revisionCount = (progressCtrl != null && progressCtrl.totalTopicRevisions > 0)
            ? progressCtrl.totalTopicRevisions
            : (revisionCtrl?.revisions.length ?? 0);
        final streak = progressCtrl?.currentStreak ?? 0;

        if (!isSignedIn && syncCtrl?.isCheckingAuth == true) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: isSignedIn
                    ? Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(
                        child: (progressCtrl?.userAvatarUrl != null &&
                                progressCtrl!.userAvatarUrl!.isNotEmpty)
                            ? Image.network(
                                progressCtrl.userAvatarUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  progressCtrl.userInitial,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                progressCtrl?.userInitial ?? 'P',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  progressCtrl?.userName ?? 'Pradeep Maurya',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const HGapXs(),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                          const VGapXs(),
                          Text(
                            (progressCtrl?.userEmail?.isNotEmpty == true)
                                ? progressCtrl!.userEmail!
                                : (progressCtrl?.userHeadline ?? 'Learner'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Guest Learner',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const VGapXs(),
                          Text(
                            'Sign in to sync your progress',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HGapSm(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: syncCtrl == null || syncCtrl.isBusy
                            ? null
                            : () => _handleSignIn(context, syncCtrl),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_upload_outlined,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const HGapXs(),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.6,
                color: AppTheme.borderColor(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Row(
                  children: [
                    _MiniStat(
                      value: '$courseCount',
                      label: 'Courses',
                      icon: Icons.school_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    _StatDivider(),
                    _MiniStat(
                      value: '${streak}d',
                      label: 'Streak',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFF97316),
                    ),
                    _StatDivider(),
                    _MiniStat(
                      value: progressCtrl?.formattedStudyHours ?? '0h',
                      label: 'Hours',
                      icon: Icons.access_time_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    _StatDivider(),
                    _MiniStat(
                      value: '$revisionCount',
                      label: 'Revisions',
                      icon: Icons.sync_rounded,
                      color: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12.5, color: color),
                const HGapXs(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const VGapXs(),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: AppTheme.borderColor(context),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMutedColor(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final VoidCallback onActivityTap;
  final VoidCallback onCoursesTap;

  const _ProfileMenuCard({
    required this.onActivityTap,
    required this.onCoursesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.insights_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: AppTheme.isDark
                ? const Color(0xFF063321)
                : const Color(0xFFE8F8F0),
            title: 'Activity',
            onTap: onActivityTap,
          ),
          Divider(
            height: 1,
            thickness: 0.6,
            indent: 52,
            color: AppTheme.borderColor(context),
          ),
          _MenuTile(
            icon: Icons.school_rounded,
            iconColor: AppTheme.pastelPurpleText(context),
            iconBgColor: AppTheme.pastelPurple(context),
            title: 'Courses',
            onTap: onCoursesTap,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Color? textColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor ?? AppTheme.textMutedColor(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
