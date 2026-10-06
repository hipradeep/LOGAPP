import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/appearance_sheet.dart';
import '../services/service_locator.dart';
import '../controllers/theme_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import 'upload_json_screen.dart';
import 'notification_settings_screen.dart';

/// Dedicated Settings screen holding configuration options:
/// - Preferences: Appearance, Notifications
/// - Cloud Backup & Sync: Google Drive Account, Back Up to Drive
/// - Curriculum: Import Curriculum (JSON)
/// - About: About Study Log
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openUploadJson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadJsonScreen()),
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

    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Settings',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      ],
                    ),
                    const VGapMd(),
                    const _SectionHeader(title: 'CLOUD BACKUP & SYNC'),
                    const _CloudSyncCard(),
                    const VGapMd(),
                    const _SectionHeader(title: 'CURRICULUM'),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          icon: Icons.upload_file_rounded,
                          iconBgColor: const Color(0xFFEDE9FE),
                          iconColor: const Color(0xFF7C3AED),
                          title: 'Import Curriculum (JSON)',
                          subtitle: 'Load syllabus from course JSON file',
                          onTap: () => _openUploadJson(context),
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
                ),
              ),
            ),
          ],
        ),
      ),
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
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.trailing,
    this.onTap,
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
              trailing ??
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

class _CloudSyncCard extends StatelessWidget {
  static final _dateFormat = DateFormat('MMM d, h:mm a');

  const _CloudSyncCard();

  Future<void> _handleSignIn(BuildContext context, CloudSyncController ctrl) async {
    debugPrint('👉 [_CloudSyncCard] Sign In tapped!');
    final success = await ctrl.signIn();
    debugPrint('👉 [_CloudSyncCard] signIn result: $success, error: ${ctrl.errorMessage}');
    if (!context.mounted) return;
    if (!success && ctrl.errorMessage != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Google Sign-In Status'),
          content: Text(
            ctrl.errorMessage!,
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleBackup(BuildContext context, CloudSyncController ctrl) async {
    final success = await ctrl.backupToDrive();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Backed up successfully to Google Drive!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (ctrl.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ctrl.errorMessage!),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, CloudSyncController ctrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out from Google?'),
        content: const Text(
          'Your latest study progress will be backed up to Google Drive, and local data will be cleared from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ctrl.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backed up to Drive and logged out'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncCtrl = getIt<CloudSyncController>();

    return ListenableBuilder(
      listenable: syncCtrl,
      builder: (context, _) {
        final isSignedIn = syncCtrl.isSignedIn;
        final isBusy = syncCtrl.isBusy;
        final lastBackup = syncCtrl.lastBackupDate;

        return _SettingsCard(
          children: [
            _SettingsTile(
              icon: isSignedIn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              iconBgColor: isSignedIn ? const Color(0xFFDCFCE7) : const Color(0xFFE0E7FF),
              iconColor: isSignedIn ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
              title: isSignedIn
                  ? (syncCtrl.displayName ?? syncCtrl.userEmail ?? 'Google Connected')
                  : 'Google Drive Account',
              subtitle: isSignedIn
                  ? (syncCtrl.userEmail ?? 'Connected to private AppData folder')
                  : 'Sign in to back up data across devices',
              trailing: syncCtrl.isSigningIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (isSignedIn
                      ? InkWell(
                          onTap: isBusy ? null : () => _handleSignOut(context, syncCtrl),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: isBusy ? null : () => _handleSignIn(context, syncCtrl),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        )),
              onTap: isBusy
                  ? null
                  : () => isSignedIn
                      ? _handleSignOut(context, syncCtrl)
                      : _handleSignIn(context, syncCtrl),
            ),
            _TileDivider(),
            _SettingsTile(
              icon: Icons.cloud_upload_rounded,
              iconBgColor: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Back Up to Drive',
              subtitle: lastBackup != null
                  ? 'Last backup: ${_dateFormat.format(lastBackup)}'
                  : 'No backups in Drive yet',
              trailing: syncCtrl.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: isBusy ? null : () => _handleBackup(context, syncCtrl),
            ),
          ],
        );
      },
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
