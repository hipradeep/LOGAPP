import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/appearance_sheet.dart';
import '../services/service_locator.dart';
import '../controllers/theme_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../services/database_backup_service.dart';
import 'upload_json_screen.dart';
import 'notification_settings_screen.dart';

/// Dedicated Settings screen holding configuration options:
/// - Preferences: Appearance, Notifications
/// - Cloud Backup & Sync: Google Drive Account, Back Up to Drive
/// - Curriculum: Import Curriculum (JSON)
/// - About: About Study Log
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _handleBack(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Settings',
              onBack: () => _handleBack(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreferencesSection(),
                    VGapMd(),
                    _SectionHeader(title: 'CLOUD BACKUP & SYNC'),
                    _CloudSyncCard(),
                    VGapMd(),
                    _LocalBackupSection(),
                    VGapMd(),
                    _CurriculumSection(),
                    VGapMd(),
                    _AboutSection(),
                    _AccountAndDataSection(),
                    VGapLg(),
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

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({super.key});

  void _onAppearance(BuildContext context) => AppearanceSheet.show(context);

  void _onNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = getIt.isRegistered<ThemeController>()
        ? getIt<ThemeController>()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'PREFERENCES'),
        _SettingsCard(
          children: [
            if (themeCtrl != null)
              ListenableBuilder(
                listenable: themeCtrl,
                builder: (context, _) {
                  final themeLabel = switch (themeCtrl.themeMode) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  };
                  return _SettingsTile(
                    icon: Icons.palette_outlined,
                    iconBgColor: const Color(0xFFFFEDD5),
                    iconColor: const Color(0xFFEA580C),
                    title: 'Appearance',
                    badgeText: themeLabel,
                    onTap: () => _onAppearance(context),
                  );
                },
              )
            else
              _SettingsTile(
                icon: Icons.palette_outlined,
                iconBgColor: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                title: 'Appearance',
                badgeText: 'System',
                onTap: () => _onAppearance(context),
              ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBgColor: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Notifications',
              onTap: () => _onNotifications(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocalBackupSection extends StatelessWidget {
  const _LocalBackupSection({super.key});

  Future<void> _handleExportBackup(BuildContext context) async {
    final backupService = getIt.isRegistered<DatabaseBackupService>()
        ? getIt<DatabaseBackupService>()
        : null;
    if (backupService == null) return;

    _showBlockingLoadingDialog(context, 'Exporting backup file...');
    try {
      final path = await backupService.exportToFile();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Backup exported successfully!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _handleImportBackup(BuildContext context) async {
    final backupService = getIt.isRegistered<DatabaseBackupService>()
        ? getIt<DatabaseBackupService>()
        : null;
    if (backupService == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Database Backup?'),
        content: const Text(
          'Restoring from a backup will replace your current courses, topics, logs, and progress with the data from the backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Select File & Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    _showBlockingLoadingDialog(context, 'Restoring database...');
    try {
      final imported = await backupService.importFromFile();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (imported) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Database restored successfully!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'LOCAL BACKUP & RESTORE'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.file_download_outlined,
              iconBgColor: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Export Backup',
              subtitle: 'Save database backup to JSON file',
              onTap: () => _handleExportBackup(context),
            ),
            const _TileDivider(),
            _SettingsTile(
              icon: Icons.file_upload_outlined,
              iconBgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: 'Import Backup',
              subtitle: 'Restore database from JSON file',
              onTap: () => _handleImportBackup(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurriculumSection extends StatelessWidget {
  const _CurriculumSection({super.key});

  void _openUploadJson(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadJsonScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

class _AccountAndDataSection extends StatelessWidget {
  const _AccountAndDataSection({super.key});

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await StudyConfirmationDialog.showDeleteAccountAndData(context);
    if (!confirmed || !context.mounted) return;

    final syncCtrl = getIt.isRegistered<CloudSyncController>()
        ? getIt<CloudSyncController>()
        : null;

    if (syncCtrl != null) {
      _showBlockingLoadingDialog(context, 'Deleting account & data...');
      try {
        await syncCtrl.deleteAccountAndClearData();
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account and all data have been completely deleted.'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete all data: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncCtrl = getIt.isRegistered<CloudSyncController>()
        ? getIt<CloudSyncController>()
        : null;

    if (syncCtrl == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: syncCtrl,
      builder: (context, _) {
        if (!syncCtrl.isSignedIn) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VGapMd(),
            const _SectionHeader(title: 'ACCOUNT & DATA'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  iconBgColor: const Color(0xFFFEE2E2),
                  iconColor: AppTheme.errorColor,
                  title: 'Delete Account & Clear Data',
                  subtitle: 'Permanently erase all data',
                  isDestructive: true,
                  onTap: () => _handleDeleteAccount(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({super.key, required this.title});

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

  const _SettingsCard({super.key, required this.children});

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
    super.key,
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

  const _CloudSyncCard({super.key});

  Future<void> _handleSignIn(BuildContext context, CloudSyncController ctrl) async {
    _showBlockingLoadingDialog(context, 'Connecting to Google...');
    bool success = false;
    try {
      success = await ctrl.signIn();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
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
    _showBlockingLoadingDialog(context, 'Backing up to Google Drive...');
    bool success = false;
    try {
      success = await ctrl.backupToDrive();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
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
      _showBlockingLoadingDialog(context, 'Backing up and logging out...');
      try {
        await ctrl.signOut();
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
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
                  : (syncCtrl.isCheckingAuth ? 'Connecting to Google...' : 'Google Drive Account'),
              subtitle: isSignedIn
                  ? (syncCtrl.userEmail ?? 'Connected to private AppData folder')
                  : (syncCtrl.isCheckingAuth ? 'Verifying account status...' : 'Sign in to back up data across devices'),
              trailing: (syncCtrl.isSigningIn || (syncCtrl.isCheckingAuth && !isSignedIn))
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _AccountAuthButton(
                      isSignedIn: isSignedIn,
                      isBusy: isBusy,
                      onSignIn: () => _handleSignIn(context, syncCtrl),
                      onSignOut: () => _handleSignOut(context, syncCtrl),
                    ),
              onTap: isBusy
                  ? null
                  : () => isSignedIn
                      ? _handleSignOut(context, syncCtrl)
                      : _handleSignIn(context, syncCtrl),
            ),
            const _TileDivider(),
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

class _AccountAuthButton extends StatelessWidget {
  final bool isSignedIn;
  final bool isBusy;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  const _AccountAuthButton({
    super.key,
    required this.isSignedIn,
    required this.isBusy,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    if (isSignedIn) {
      return InkWell(
        onTap: isBusy ? null : onSignOut,
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
      );
    }
    return InkWell(
      onTap: isBusy ? null : onSignIn,
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
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider({super.key});

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

/// Non-dismissible loading dialog that prevents user interaction while operations run
void _showBlockingLoadingDialog(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
