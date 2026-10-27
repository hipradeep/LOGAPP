import 'package:flutter/material.dart';

import '../controllers/cloud_sync_controller.dart';
import '../controllers/sms_inbox_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/database_backup_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import 'categories_screen.dart';
import 'design_system_screen.dart';
import 'notification_settings_screen.dart';
import 'payment_modes_screen.dart';
import 'sms_inbox_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runCloudAction(
    BuildContext context,
    CloudSyncController cloud,
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final success = await action();
    if (!context.mounted) return;
    if (success) {
      _showMessage(context, successMessage);
    } else if (cloud.errorMessage != null) {
      _showMessage(context, cloud.errorMessage!);
    }
  }

  Future<void> _restoreFromDrive(
    BuildContext context,
    CloudSyncController cloud,
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
    await _runCloudAction(
      context,
      cloud,
      cloud.restoreFromDrive,
      'Cloud backup restored',
    );
  }

  Future<void> _importFile(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Import a local backup?',
      message: 'This replaces all local data with the selected backup file.',
      confirmText: 'Import',
      destructive: true,
      icon: Icons.upload_file_outlined,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final imported = await getIt<DatabaseBackupService>().importFromFile();
      if (!context.mounted) return;
      if (imported) _showMessage(context, 'Backup imported');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Could not import backup: $error');
    }
  }

  Future<void> _exportFile(BuildContext context) async {
    try {
      final path = await getIt<DatabaseBackupService>().exportToFile();
      if (!context.mounted) return;
      if (path != null) _showMessage(context, 'Backup exported');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Could not export backup: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppProvider.watch<ThemeController>(context);
    final cloud = getIt<CloudSyncController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'Settings',
              subtitle: 'Accounts, categories, backups and preferences.',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: cloud,
                builder: (context, _) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                      AppTheme.spacingMd,
                      AppTheme.spacingXl,
                    ),
                    children: [
                      const _SectionLabel('FINANCIAL CONFIGURATION'),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              title: const Text('Accounts & payment modes'),
                              subtitle: const Text(
                                'Manage UPI, banks, cards, cash and wallets.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const PaymentModesScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(
                              color: AppTheme.borderColor(context),
                              height: 1,
                            ),
                            ListTile(
                              leading: const Icon(Icons.category_outlined),
                              title: const Text('Categories'),
                              subtitle: const Text(
                                'Expense and income labels for your log.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CategoriesScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const VGapLg(),
                      const _SectionLabel('ACCOUNT & CLOUD BACKUP'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMd),
                          child: cloud.isSignedIn
                              ? _SignedInAccount(
                                  cloud: cloud,
                                  onBackup: () => _runCloudAction(
                                    context,
                                    cloud,
                                    cloud.backupToDrive,
                                    'Cloud backup complete',
                                  ),
                                  onRestore: () =>
                                      _restoreFromDrive(context, cloud),
                                  onSignOut: cloud.signOut,
                                )
                              : _SignedOutAccount(
                                  cloud: cloud,
                                  onSignIn: () => _runCloudAction(
                                    context,
                                    cloud,
                                    cloud.signIn,
                                    'Signed in to Google',
                                  ),
                                ),
                        ),
                      ),
                      const VGapLg(),
                      const _SectionLabel('TRACKING'),
                      Card(
                        child: ListenableBuilder(
                          listenable: getIt<SmsInboxController>(),
                          builder: (context, _) {
                            final pendingCount =
                                getIt<SmsInboxController>().pendingCount;
                            return ListTile(
                              leading: const Icon(Icons.sms_outlined),
                              title: const Text('SMS inbox'),
                              subtitle: const Text(
                                'Review staged bank credit and debit messages.',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (pendingCount > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.pillBorderRadius,
                                        ),
                                      ),
                                      child: Text(
                                        '$pendingCount',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const HGapSm(),
                                  ],
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SmsInboxScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const VGapLg(),
                      const _SectionLabel('PREFERENCES'),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.notifications_outlined),
                              title: const Text('Notifications'),
                              subtitle: const Text(
                                'Bill reminders and permission status.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(
                              color: AppTheme.borderColor(context),
                              height: 1,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appearance',
                                    style: textTheme.titleMedium,
                                  ),
                                  const VGapSm(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<ThemeMode>(
                                      segments: const [
                                        ButtonSegment(
                                          value: ThemeMode.system,
                                          label: Text('System'),
                                        ),
                                        ButtonSegment(
                                          value: ThemeMode.light,
                                          label: Text('Light'),
                                        ),
                                        ButtonSegment(
                                          value: ThemeMode.dark,
                                          label: Text('Dark'),
                                        ),
                                      ],
                                      selected: {themeController.themeMode},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (selection) {
                                        themeController.setThemeMode(
                                          selection.first,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VGapLg(),
                      const _SectionLabel('DATA'),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.download_outlined),
                              title: const Text('Export backup file'),
                              subtitle: const Text(
                                'Save a JSON copy to this device.',
                              ),
                              onTap: () => _exportFile(context),
                            ),
                            Divider(
                              color: AppTheme.borderColor(context),
                              height: 1,
                            ),
                            ListTile(
                              leading: const Icon(Icons.upload_outlined),
                              title: const Text('Import backup file'),
                              subtitle: const Text(
                                'Restore from a JSON backup.',
                              ),
                              onTap: () => _importFile(context),
                            ),
                          ],
                        ),
                      ),
                      const VGapLg(),
                      const _SectionLabel('DEVELOPER'),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Design system'),
                          subtitle: const Text(
                            'Preview colors, type, controls and sheets.',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DesignSystemScreen(
                                  showBackButton: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const VGapLg(),
                      Center(
                        child: Text(
                          'Budget Log · offline-first',
                          style: textTheme.labelSmall,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInAccount extends StatelessWidget {
  final CloudSyncController cloud;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final Future<void> Function() onSignOut;

  const _SignedInAccount({
    required this.cloud,
    required this.onBackup,
    required this.onRestore,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = cloud.displayName?.trim();
    final email = cloud.userEmail ?? '';
    final lastBackup = cloud.lastBackupDate == null
        ? 'Not backed up yet'
        : 'Last backup ${AppFormat.dateTime(cloud.lastBackupDate!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              child: Icon(
                Icons.person_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const HGapSm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name == null || name.isEmpty ? 'Google account' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const VGapXs(),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: cloud.isBusy ? null : onSignOut,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
            ),
          ],
        ),
        const VGapSm(),
        Text(lastBackup, style: textTheme.labelSmall),
        if (cloud.errorMessage != null) ...[
          const VGapSm(),
          Text(
            cloud.errorMessage!,
            style: textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
          ),
        ],
        if (cloud.isBusy) ...[
          const VGapSm(),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const VGapMd(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cloud.isBusy ? null : onRestore,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Restore'),
              ),
            ),
            const HGapSm(),
            Expanded(
              child: FilledButton.icon(
                onPressed: cloud.isBusy ? null : onBackup,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Back up'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignedOutAccount extends StatelessWidget {
  final CloudSyncController cloud;
  final VoidCallback onSignIn;

  const _SignedOutAccount({required this.cloud, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Google Drive sync', style: textTheme.titleMedium),
        const VGapXs(),
        Text(
          'Keep a private backup in your Google Drive AppData folder. '
          'Local data keeps working offline.',
          style: textTheme.bodyMedium,
        ),
        if (cloud.errorMessage != null) ...[
          const VGapSm(),
          Text(
            cloud.errorMessage!,
            style: textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
          ),
        ],
        const VGapMd(),
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: FilledButton.icon(
            onPressed: cloud.isBusy ? null : onSignIn,
            icon: cloud.isSigningIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign in with Google'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
