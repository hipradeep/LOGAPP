import 'package:flutter/material.dart';

import '../controllers/cloud_sync_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/database_backup_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/appearance_sheet.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/tile_divider.dart';
import 'categories_screen.dart';
import 'design_system_screen.dart';
import 'notification_settings_screen.dart';
import 'payment_modes_screen.dart';

/// Dedicated Settings screen holding configuration options:
/// - Preferences: Appearance, Notifications, Design System
/// - Cloud Backup & Sync: Google Drive Account, Back Up, Restore
/// - Financial Configuration: Accounts & payment modes, Categories
/// - Local Backup & Restore: Export, Import
/// - About: About Budget Log
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
            CustomAppBar(title: 'Settings', onBack: () => _handleBack(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreferencesSection(),
                    VGapMd(),
                    _SectionHeader(title: 'CLOUD BACKUP & SYNC'),
                    _CloudSyncCard(),
                    VGapMd(),
                    _FinancialConfigSection(),
                    VGapMd(),
                    _LocalBackupSection(),
                    VGapMd(),
                    _AboutSection(),
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
  const _PreferencesSection();

  void _onAppearance(BuildContext context) => AppearanceSheet.show(context);

  void _onNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  void _onDesignSystem(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DesignSystemScreen(showBackButton: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = AppProvider.watch<ThemeController>(context);
    final themeLabel = switch (themeCtrl.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Column(
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
              onTap: () => _onAppearance(context),
            ),
            const TileDivider(),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBgColor: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Notifications',
              onTap: () => _onNotifications(context),
            ),
            const TileDivider(),
            _SettingsTile(
              icon: Icons.widgets_outlined,
              iconBgColor: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              title: 'Design System',
              subtitle: 'Tokens, components & styles',
              onTap: () => _onDesignSystem(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinancialConfigSection extends StatelessWidget {
  const _FinancialConfigSection();

  void _openPaymentModes(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaymentModesScreen()));
  }

  void _openCategories(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'FINANCIAL CONFIGURATION'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconBgColor: const Color(0xFFE8F8F0),
              iconColor: const Color(0xFF10B981),
              title: 'Accounts & payment modes',
              subtitle: 'Manage UPI, banks, cards, cash and wallets.',
              onTap: () => _openPaymentModes(context),
            ),
            const TileDivider(),
            _SettingsTile(
              icon: Icons.category_outlined,
              iconBgColor: const Color(0xFFF0EEFF),
              iconColor: const Color(0xFF5B4DFB),
              title: 'Categories',
              subtitle: 'Expense and income labels for your log.',
              onTap: () => _openCategories(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocalBackupSection extends StatelessWidget {
  const _LocalBackupSection();

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
          _showSuccessSnack(context, 'Backup exported successfully!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnack(context, 'Failed to export backup: $e');
      }
    }
  }

  Future<void> _handleImportBackup(BuildContext context) async {
    final backupService = getIt.isRegistered<DatabaseBackupService>()
        ? getIt<DatabaseBackupService>()
        : null;
    if (backupService == null) return;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Import a local backup?',
      message: 'This replaces all local data with the selected backup file.',
      confirmText: 'Import',
      destructive: true,
      icon: Icons.upload_file_outlined,
    );

    if (!confirmed || !context.mounted) return;

    _showBlockingLoadingDialog(context, 'Restoring database...');
    try {
      final imported = await backupService.importFromFile();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (imported) {
          _showSuccessSnack(context, 'Database restored successfully!');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnack(context, 'Failed to restore backup: $e');
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
            const TileDivider(),
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

class _AboutSection extends StatelessWidget {
  const _AboutSection();

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
                Icons.account_balance_wallet_rounded,
                color: AppTheme.pastelPurpleText(context),
                size: 20,
              ),
            ),
            const HGapSm(),
            const Text(
              'Budget Log',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'An offline-first budget and expense logging companion.\n\n'
          'Version 1.0.0\n'
          'Track spending, budgets and bills with clarity.',
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
              title: 'About Budget Log',
              badgeText: 'v1.0.0',
              onTap: () => _showAboutDialog(context),
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
      child: Column(children: children),
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

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.trailing,
    this.onTap,
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
                        color: AppTheme.textPrimaryColor(context),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                    color: AppTheme.textMutedColor(context),
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
  const _CloudSyncCard();

  Future<void> _handleSignIn(
    BuildContext context,
    CloudSyncController ctrl,
  ) async {
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
    if (success) {
      _showSuccessSnack(context, 'Signed in to Google');
    } else if (ctrl.errorMessage != null) {
      _showErrorSnack(context, ctrl.errorMessage!);
    }
  }

  Future<void> _handleBackup(
    BuildContext context,
    CloudSyncController ctrl,
  ) async {
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
      _showSuccessSnack(context, 'Backed up successfully to Google Drive!');
    } else if (ctrl.errorMessage != null) {
      _showErrorSnack(context, ctrl.errorMessage!);
    }
  }

  Future<void> _handleRestore(
    BuildContext context,
    CloudSyncController ctrl,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Restore from Google Drive?',
      message:
          'This replaces all local data with the latest cloud backup. '
          'Export a local backup first if you are unsure.',
      confirmText: 'Restore',
      destructive: true,
      icon: Icons.cloud_download_outlined,
    );
    if (!confirmed || !context.mounted) return;

    _showBlockingLoadingDialog(context, 'Restoring from Google Drive...');
    bool success = false;
    try {
      success = await ctrl.restoreFromDrive();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return;
    if (success) {
      _showSuccessSnack(context, 'Cloud backup restored');
    } else if (ctrl.errorMessage != null) {
      _showErrorSnack(context, ctrl.errorMessage!);
    }
  }

  Future<void> _handleSignOut(
    BuildContext context,
    CloudSyncController ctrl,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign out of Google?',
      message:
          'Your data is backed up to Drive before signing out. '
          'Local data stays on this device.',
      confirmText: 'Sign Out',
      icon: Icons.logout_rounded,
    );

    if (!confirmed || !context.mounted) return;

    _showBlockingLoadingDialog(context, 'Backing up and logging out...');
    try {
      await ctrl.signOut();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (context.mounted) {
      _showSuccessSnack(context, 'Backed up to Drive and logged out');
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
              icon: isSignedIn
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              iconBgColor: isSignedIn
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFE0E7FF),
              iconColor: isSignedIn
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF4F46E5),
              title: isSignedIn
                  ? (syncCtrl.displayName ??
                        syncCtrl.userEmail ??
                        'Google Connected')
                  : (syncCtrl.isCheckingAuth
                        ? 'Connecting to Google...'
                        : 'Google Drive Account'),
              subtitle: isSignedIn
                  ? (syncCtrl.userEmail ??
                        'Connected to private AppData folder')
                  : (syncCtrl.isCheckingAuth
                        ? 'Verifying account status...'
                        : 'Sign in to back up data across devices'),
              trailing:
                  (syncCtrl.isSigningIn ||
                      (syncCtrl.isCheckingAuth && !isSignedIn))
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
            const TileDivider(),
            _SettingsTile(
              icon: Icons.cloud_upload_rounded,
              iconBgColor: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Back Up to Drive',
              subtitle: syncCtrl.isAutoSyncing
                  ? 'Auto-syncing changes to Drive...'
                  : (lastBackup != null
                        ? 'Auto-synced: ${AppFormat.dateTime(lastBackup)}'
                        : 'No backups in Drive yet'),
              trailing: (syncCtrl.isSyncing || syncCtrl.isAutoSyncing)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: isBusy ? null : () => _handleBackup(context, syncCtrl),
            ),
            const TileDivider(),
            _SettingsTile(
              icon: Icons.cloud_download_rounded,
              iconBgColor: const Color(0xFFF0EEFF),
              iconColor: const Color(0xFF5B4DFB),
              title: 'Restore from Drive',
              subtitle: 'Replace local data with the latest cloud backup.',
              trailing: syncCtrl.isRestoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: isBusy ? null : () => _handleRestore(context, syncCtrl),
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

void _showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
}

void _showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
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
