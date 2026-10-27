import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/cloud_sync_controller.dart';
import '../controllers/debt_controller.dart';
import '../controllers/finance_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/tab_header.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'udar_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isSigningIn = false;

  CloudSyncController? get _cloud => getIt.isRegistered<CloudSyncController>()
      ? getIt<CloudSyncController>()
      : null;

  DebtController get _debt => getIt<DebtController>();

  SubscriptionController get _subscriptions => getIt<SubscriptionController>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _signIn() async {
    final cloud = _cloud;
    if (cloud == null || _isSigningIn || cloud.isSigningIn) return;

    setState(() => _isSigningIn = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SignInDialog(),
      ),
    );

    final success = await cloud.signIn();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _isSigningIn = false);

    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(cloud.errorMessage ?? 'Could not sign in to Google.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final finance = AppProvider.watch<FinanceController>(context);
    final cloud = _cloud;
    final textTheme = Theme.of(context).textTheme;
    final incomeBase = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : finance.plannedIncome;
    final savedRate = incomeBase <= 0
        ? 0.0
        : (((incomeBase - finance.monthlyExpense) / incomeBase) * 100)
              .clamp(0, 100)
              .toDouble();

    final listenable = Listenable.merge([_debt, _subscriptions, ?cloud]);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'Profile',
              subtitle: 'Your financial snapshot & subscriptions.',
              actions: [
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
              ],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: listenable,
                builder: (context, _) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                      AppTheme.spacingMd,
                      AppTheme.spacingXl,
                    ),
                    children: [
                      _ProfileHeroCard(
                        cloud: cloud,
                        spent: finance.monthlyExpense,
                        savedRate: savedRate,
                        subscriptions: _subscriptions.activeCount,
                        udar: _debt.netBalance,
                        isSigningIn: _isSigningIn,
                        onSignIn: _signIn,
                      ),
                      const VGapLg(),
                      const _SectionLabel('QUICK ACCESS'),
                      const VGapSm(),
                      _ProfileActionsCard(
                        activeSubscriptions: _subscriptions.activeCount,
                        udarBalance: _debt.netBalance,
                        onOpenSubscriptions: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionScreen(),
                            ),
                          );
                        },
                        onOpenUdar: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UdarScreen(),
                            ),
                          );
                        },
                      ),
                      const VGapLg(),
                      Text(
                        'Manage categories, payment modes, cloud backups and '
                        'appearance from Settings.',
                        style: textTheme.bodySmall,
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

class _ProfileHeroCard extends StatelessWidget {
  final CloudSyncController? cloud;
  final double spent;
  final double savedRate;
  final int subscriptions;
  final double udar;
  final bool isSigningIn;
  final Future<void> Function() onSignIn;

  const _ProfileHeroCard({
    required this.cloud,
    required this.spent,
    required this.savedRate,
    required this.subscriptions,
    required this.udar,
    required this.isSigningIn,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final signedIn = cloud?.isSignedIn ?? false;
    final signingIn = isSigningIn || (cloud?.isSigningIn ?? false);
    final name = _displayName(cloud);
    final email = cloud?.userEmail;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileAvatar(cloud: cloud, name: name),
                const HGapSm(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              signedIn ? name : 'Guest Spender',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium,
                            ),
                          ),
                          if (signedIn) ...[
                            const HGapXs(),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ],
                      ),
                      const VGapXs(),
                      Text(
                        signedIn
                            ? (email == null || email.isEmpty
                                  ? 'Signed in to Google'
                                  : email)
                            : 'Your data stays on this device.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                      const VGapXs(),
                      Text(
                        _syncLabel(cloud),
                        style: textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      if (cloud?.errorMessage != null) ...[
                        const VGapXs(),
                        Text(
                          cloud!.errorMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!signedIn && cloud != null) ...[
                  const HGapSm(),
                  FilledButton.tonal(
                    onPressed: signingIn ? null : onSignIn,
                    child: signingIn
                        ? const _ButtonSpinner()
                        : const Text('Sign in'),
                  ),
                ],
              ],
            ),
            const VGapMd(),
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapMd(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Spent',
                    value: AppFormat.currency(spent),
                    color: AppTheme.pastelCoralText(context),
                  ),
                ),
                const HGapXs(),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.savings_rounded,
                    label: 'Saved',
                    value: '${savedRate.round()}%',
                    color: AppTheme.pastelGreenText(context),
                  ),
                ),
                const HGapXs(),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.repeat_rounded,
                    label: 'Subs',
                    value: '$subscriptions',
                    color: AppTheme.pastelIndigoText(context),
                  ),
                ),
                const HGapXs(),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.people_alt_rounded,
                    label: 'Udar',
                    value: AppFormat.currency(udar),
                    color: AppTheme.pastelBlueText(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _displayName(CloudSyncController? cloud) {
    final displayName = cloud?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = cloud?.userEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Google account';
  }

  static String _syncLabel(CloudSyncController? cloud) {
    if (cloud == null) return 'Local only';
    if (cloud.isCheckingAuth) return 'Checking cloud account…';
    if (!cloud.isSignedIn) return 'Local only · not backed up';
    final lastBackup = cloud.lastBackupDate;
    if (lastBackup == null) return 'Signed in · not backed up yet';
    return 'Last synced ${AppFormat.relativeDate(lastBackup)}';
  }
}

class _ProfileAvatar extends StatelessWidget {
  final CloudSyncController? cloud;
  final String name;

  const _ProfileAvatar({required this.cloud, required this.name});

  @override
  Widget build(BuildContext context) {
    final photoUrl = cloud?.photoUrl;
    final initial = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
        ),
      ),
      alignment: Alignment.center,
      child: photoUrl != null
          ? Image.network(
              photoUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarInitial(initial: initial),
            )
          : _AvatarInitial(initial: initial),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const VGapXs(),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall,
        ),
        const VGapXs(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionsCard extends StatelessWidget {
  final int activeSubscriptions;
  final double udarBalance;
  final VoidCallback onOpenSubscriptions;
  final VoidCallback onOpenUdar;

  const _ProfileActionsCard({
    required this.activeSubscriptions,
    required this.udarBalance,
    required this.onOpenSubscriptions,
    required this.onOpenUdar,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = activeSubscriptions == 0
        ? 'No active subscriptions'
        : activeSubscriptions == 1
        ? '1 active subscription'
        : '$activeSubscriptions active subscriptions';

    final udarLabel = udarBalance.abs() < 0.01
        ? 'All settled'
        : udarBalance > 0
        ? 'You are owed ${AppFormat.currency(udarBalance.abs())}'
        : 'You owe ${AppFormat.currency(udarBalance.abs())}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.pastelIndigo(context),
                borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.autorenew_rounded,
                color: AppTheme.pastelIndigoText(context),
                size: 20,
              ),
            ),
            title: const Text('Subscriptions & recurring bills'),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenSubscriptions,
          ),
          Divider(
            height: 1,
            indent: 68,
            color: AppTheme.borderColor(context),
          ),
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.pastelBlue(context),
                borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.people_alt_rounded,
                color: AppTheme.pastelBlueText(context),
                size: 20,
              ),
            ),
            title: const Text('Udar & splits'),
            subtitle: Text(udarLabel),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenUdar,
          ),
        ],
      ),
    );
  }
}

class _SignInDialog extends StatelessWidget {
  const _SignInDialog();

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            HGapMd(),
            Flexible(child: Text('Opening Google sign-in…')),
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
