import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/appearance_sheet.dart';
import '../services/local_course_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/theme_controller.dart';
import 'courses_screen.dart';
import 'upload_json_screen.dart';
import 'my_progress_screen.dart';

/// Redesigned Profile Screen:
/// - 26px bold "Profile" header matching Home and Revision tabs
/// - User Hero Card with gradient avatar, user role, and live learning stats (Courses, Streak, Revisions)
/// - Modern grouped settings cards (Study & Progress, Preferences, Data & Storage, About)
/// - Tinted icon containers and clear micro-typography
/// - Strict compliance with aa-rules.md & optimize.md (build < 40 lines, const, zero-dep)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openCourses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoursesScreen()),
    );
  }

  void _openUploadJson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadJsonScreen()),
    );
  }

  void _openMyProgress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyProgressScreen()),
    );
  }

  Future<void> _handleClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete all locally stored course, topic, and revision cache. '
          'Your Firestore cloud data will remain safe.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Future.wait([
        LocalCourseStorage.clearAll(),
        LocalTopicStorage.clearAll(),
        LocalRevisionStorage.clearAll(),
        LocalStudyLogStorage.clearAll(),
      ]);
      getIt<CoursesController>().refresh();
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cache cleared successfully'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showRevisionInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const VGapMd(),
              Text(
                'Spaced Repetition Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const VGapSm(),
              Text(
                'The study ladder uses 5 intervals to lock knowledge into long-term memory:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const VGapMd(),
              const _IntervalRow(level: 'R1', interval: '1 day after completion'),
              const _IntervalRow(level: 'R2', interval: '3 days after R1'),
              const _IntervalRow(level: 'R3', interval: '7 days after R2'),
              const _IntervalRow(level: 'R4', interval: '14 days after R3'),
              const _IntervalRow(level: 'R5', interval: '30 days after R4 (Mastered)'),
              const VGapMd(),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.pastelPurple(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.pastelPurpleText(context),
                size: 20,
              ),
            ),
            const HGapSm(),
            const Text(
              'Study Log',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'An offline-first syllabus tracker and spaced repetition companion.\n\n'
          'Version 1.0.0\n'
          'Designed for focused daily learning.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: bottomSafe + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ProfileHeader(),
              const VGapLg(),
              const _UserProfileCard(),
              const VGapLg(),
              _ProfileSections(
                onMyProgressTap: () => _openMyProgress(context),
                onCoursesTap: () => _openCourses(context),
                onUploadJsonTap: () => _openUploadJson(context),
                onClearCacheTap: () => _handleClearCache(context),
                onAppearanceTap: () => AppearanceSheet.show(context),
                onRevisionInfoTap: () => _showRevisionInfo(context),
                onAboutTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -0.3,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: AppTheme.textPrimaryColor(context),
            size: 22,
          ),
          onPressed: () => AppearanceSheet.show(context),
          tooltip: 'Appearance Settings',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard();

  @override
  Widget build(BuildContext context) {
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
        if (coursesCtrl != null) coursesCtrl,
        if (revisionCtrl != null) revisionCtrl,
        if (progressCtrl != null) progressCtrl,
      ]),
      builder: (context, _) {
        final courseCount = coursesCtrl?.courses.length ?? 0;
        final revisionCount = revisionCtrl?.revisions.length ?? 0;
        final streak = progressCtrl?.currentStreak ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFFC4B5FD),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'P',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                                  'Pradeep Maurya',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor(context),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const HGapXs(),
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                          const VGapXs(),
                          Text(
                            'Software Developer',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.borderColor(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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
      height: 24,
      color: AppTheme.borderColor(context),
    );
  }
}

class _ProfileSections extends StatelessWidget {
  final VoidCallback onMyProgressTap;
  final VoidCallback onCoursesTap;
  final VoidCallback onUploadJsonTap;
  final VoidCallback onClearCacheTap;
  final VoidCallback onAppearanceTap;
  final VoidCallback onRevisionInfoTap;
  final VoidCallback onAboutTap;

  const _ProfileSections({
    required this.onMyProgressTap,
    required this.onCoursesTap,
    required this.onUploadJsonTap,
    required this.onClearCacheTap,
    required this.onAppearanceTap,
    required this.onRevisionInfoTap,
    required this.onAboutTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeCtrl = getIt.isRegistered<ThemeController>()
        ? getIt<ThemeController>()
        : null;

    final String themeLabel;
    if (themeCtrl != null) {
      themeLabel = switch (themeCtrl.themeMode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
    } else {
      themeLabel = 'System';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'STUDY & ANALYTICS'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.insights_rounded,
              iconBgColor: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
              title: 'My Progress',
              subtitle: 'Activity streaks & 90-day heatmap',
              onTap: onMyProgressTap,
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.school_rounded,
              iconBgColor: AppTheme.pastelPurple(context),
              iconColor: AppTheme.pastelPurpleText(context),
              title: 'Courses',
              subtitle: 'Syllabus modules & topic tracking',
              onTap: onCoursesTap,
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.tune_rounded,
              iconBgColor: const Color(0xFFCFFAFE),
              iconColor: const Color(0xFF0891B2),
              title: 'Revision Intervals',
              subtitle: 'Spaced repetition schedule (R1–R5)',
              onTap: onRevisionInfoTap,
            ),
          ],
        ),
        const VGapLg(),
        const _SectionHeader(title: 'PREFERENCES'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              iconBgColor: const Color(0xFFFFEDD5),
              iconColor: const Color(0xFFEA580C),
              title: 'Appearance',
              subtitle: 'Theme preference',
              badgeText: themeLabel,
              onTap: onAppearanceTap,
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBgColor: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Notifications',
              subtitle: 'Daily study and review alerts',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Notifications are active for daily reviews'),
                    backgroundColor: AppTheme.primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ],
        ),
        const VGapLg(),
        const _SectionHeader(title: 'DATA & STORAGE'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.upload_file_rounded,
              iconBgColor: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              title: 'Import Curriculum (JSON)',
              subtitle: 'Import structured courses & modules',
              onTap: onUploadJsonTap,
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              iconBgColor: const Color(0xFFFEE2E2),
              iconColor: AppTheme.errorColor,
              title: 'Clear Local Cache',
              subtitle: 'Free up local memory & reset caches',
              isDestructive: true,
              onTap: onClearCacheTap,
            ),
          ],
        ),
        const VGapLg(),
        const _SectionHeader(title: 'ABOUT'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconBgColor: const Color(0xFFF1F5F9),
              iconColor: const Color(0xFF475569),
              title: 'About Study Log',
              subtitle: 'Offline-first syllabus tracker',
              badgeText: 'v1.0.0',
              onTap: onAboutTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryColor(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppTheme.errorColor
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const HGapSm(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
              ],
              const HGapSm(),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? AppTheme.errorColor
                    : AppTheme.textMutedColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68.0),
      child: Divider(
        height: 1,
        thickness: 0.8,
        color: AppTheme.borderColor(context),
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final String level;
  final String interval;

  const _IntervalRow({required this.level, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.pastelPurple(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
            ),
            alignment: Alignment.center,
            child: Text(
              level,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.pastelPurpleText(context),
              ),
            ),
          ),
          const HGapSm(),
          Text(
            interval,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
