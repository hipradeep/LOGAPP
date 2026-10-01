import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/appearance_sheet.dart';
import '../services/local_course_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/theme_controller.dart';
import 'courses_screen.dart';
import 'upload_json_screen.dart';
import 'notification_settings_screen.dart';

/// Dedicated Settings screen holding all configuration options:
/// - Study: Courses, Revision Intervals
/// - Preferences: Appearance, Notifications
/// - Data & Storage: Import Curriculum, Clear Local Cache
/// - About: About Study Log
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  /// Fires a dummy notification so the user can confirm reminders actually
  /// reach the device. Deliberately ignores the stored notification prefs.
  Future<void> _sendTestNotification(BuildContext context) async {
    final result = await getIt<NotificationService>().showInstantNotification(
      title: 'Test Notification',
      body: 'If you can see this, reminder delivery is working.',
    );

    if (!context.mounted) return;

    final message = switch (result) {
      TestNotificationResult.instantSent => 'Test notification sent.',
      TestNotificationResult.permissionDenied =>
        'Notification permission denied. Enable it in system settings.',
      _ => 'Could not deliver the test notification. Check logs.',
    };
    final color = switch (result) {
      TestNotificationResult.instantSent => AppTheme.successColor,
      TestNotificationResult.permissionDenied => AppTheme.warningColor,
      _ => AppTheme.errorColor,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          ),
        ),
      );
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
              const _IntervalRow(level: 1, interval: '1 day after completion'),
              const _IntervalRow(level: 2, interval: '3 days after R1'),
              const _IntervalRow(level: 3, interval: '7 days after R2'),
              const _IntervalRow(level: 4, interval: '14 days after R3'),
              const _IntervalRow(level: 5, interval: '30 days after R4 (Mastered)'),
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

    return FullScreenPage(
      title: 'Settings',
      showBackButton: true,
      children: [
        const VGapSm(),
        const _SectionHeader(title: 'STUDY'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.school_rounded,
              iconBgColor: AppTheme.pastelPurple(context),
              iconColor: AppTheme.pastelPurpleText(context),
              title: 'Courses',
              onTap: () => _openCourses(context),
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.tune_rounded,
              iconBgColor: const Color(0xFFCFFAFE),
              iconColor: const Color(0xFF0891B2),
              title: 'Revision Intervals',
              onTap: () => _showRevisionInfo(context),
            ),
          ],
        ),
        const VGapMd(),
        const _SectionHeader(title: 'PREFERENCES'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              iconBgColor: const Color(0xFFFFEDD5),
              iconColor: const Color(0xFFEA580C),
              title: 'Appearance',
              badgeText: themeLabel,
              onTap: () => AppearanceSheet.show(context),
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBgColor: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Notifications',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.notifications_active_rounded,
              iconBgColor: AppTheme.pastelGreen(context),
              iconColor: AppTheme.pastelGreenText(context),
              title: 'Send Test Notification',
              subtitle: 'Post a dummy reminder now',
              onTap: () => _sendTestNotification(context),
            ),
          ],
        ),
        const VGapMd(),
        const _SectionHeader(title: 'DATA & STORAGE'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.upload_file_rounded,
              iconBgColor: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              title: 'Import Curriculum (JSON)',
              onTap: () => _openUploadJson(context),
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              iconBgColor: const Color(0xFFFEE2E2),
              iconColor: AppTheme.errorColor,
              title: 'Clear Local Cache',
              isDestructive: true,
              onTap: () => _handleClearCache(context),
            ),
          ],
        ),
        const VGapMd(),
        const _SectionHeader(title: 'ABOUT'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconBgColor: const Color(0xFFF1F5F9),
              iconColor: const Color(0xFF475569),
              title: 'About Study Log',
              badgeText: 'v1.0.0',
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
        const VGapLg(),
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
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMutedColor(context),
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
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
  final String? subtitle;
  final String? badgeText;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
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
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const HGapSm(),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDestructive
                            ? AppTheme.errorColor
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const VGapXs(),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const HGapSm(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
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
                size: 16,
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
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 48,
      color: AppTheme.borderColor(context),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  final int level;
  final String interval;

  const _IntervalRow({
    required this.level,
    required this.interval,
  });

  @override
  Widget build(BuildContext context) {
    final colors = RevisionLevelPalette.of(context, level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Text(
              'R$level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              interval,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
