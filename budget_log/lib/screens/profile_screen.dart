import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/cloud_sync_controller.dart';
import '../controllers/debt_controller.dart';
import '../controllers/finance_controller.dart';
import '../controllers/sms_inbox_controller.dart';
import '../controllers/subscription_controller.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_spacers.dart';
import '../widgets/tab_header.dart';
import 'budget_transactions_screen.dart';
import 'manage_budgets_screen.dart';
import 'settings_screen.dart';
import 'sms_inbox_screen.dart';
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

  SmsInboxController? get _smsInbox => getIt.isRegistered<SmsInboxController>()
      ? getIt<SmsInboxController>()
      : null;

  @override
  bool get wantKeepAlive => true;

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openAllTransactions() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BudgetTransactionsScreen()));
  }

  void _openManageBudgets() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManageBudgetsScreen()));
  }

  void _openSubscriptions() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }

  void _openUdar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UdarScreen()));
  }

  void _openSmsInbox() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SmsInboxScreen()));
  }

  Future<void> _signIn() async {
    final cloud = _cloud;
    if (cloud == null || _isSigningIn || cloud.isBusy) return;

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

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Signed in as ${cloud.displayName ?? cloud.userEmail ?? 'User'}!',
            ),
          ),
        );
    } else {
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
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final finance = getIt<FinanceController>();
    final cloud = _cloud;

    final listenable = Listenable.merge([
      finance,
      _debt,
      _subscriptions,
      ?_smsInbox,
      ?cloud,
    ]);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'Profile',
              subtitle: 'Your financial stats & settings',
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: AppTheme.textSecondaryColor(context),
                    size: 22,
                  ),
                  onPressed: _openSettings,
                  tooltip: 'Settings',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: listenable,
                builder: (context, _) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 4,
                      bottom: bottomSafe + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _UserProfileCard(
                          finance: finance,
                          cloud: cloud,
                          isSigningIn: _isSigningIn,
                          onSignIn: _signIn,
                        ),
                        const VGapMd(),
                        const _SectionHeader(title: 'MENU'),
                        _ProfileMenuCard(
                          transactionCount: finance.transactions.length,
                          budgetCount: finance.budgets.length,
                          activeSubscriptions: _subscriptions.activeCount,
                          smsPendingCount: _smsInbox?.pendingCount ?? 0,
                          onTransactionsTap: _openAllTransactions,
                          onBudgetsTap: _openManageBudgets,
                          onSubscriptionsTap: _openSubscriptions,
                          onUdarTap: _openUdar,
                          onSmsTap: _openSmsInbox,
                        ),
                      ],
                    ),
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

class _UserProfileCard extends StatelessWidget {
  final FinanceController finance;
  final CloudSyncController? cloud;
  final bool isSigningIn;
  final Future<void> Function() onSignIn;

  const _UserProfileCard({
    required this.finance,
    required this.cloud,
    required this.isSigningIn,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final isSignedIn = cloud?.isSignedIn ?? false;
    final signingIn = isSigningIn || (cloud?.isSigningIn ?? false);

    final syncDisplayName = cloud?.displayName?.trim();
    final email = cloud?.userEmail?.trim();

    final displayName = (syncDisplayName != null && syncDisplayName.isNotEmpty)
        ? syncDisplayName
        : ((email != null && email.isNotEmpty)
              ? email.split('@').first
              : 'Guest Spender');
    final displayEmail = (email != null && email.isNotEmpty)
        ? email
        : 'Sign in to sync your data';

    final avatarUrl = cloud?.photoUrl;
    final userInitial = displayName.trim().isEmpty
        ? 'B'
        : displayName.trim()[0].toUpperCase();

    final incomeBase = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : finance.plannedIncome;
    final savedRate = incomeBase <= 0
        ? 0
        : (((incomeBase - finance.monthlyExpense) / incomeBase) * 100)
              .clamp(0, 100)
              .round();

    if (!isSignedIn && cloud?.isCheckingAuth == true) {
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 10.0,
            ),
            child: isSignedIn
                ? Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: ClipOval(
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? Image.network(
                                  avatarUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Text(
                                    userInitial,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  userInitial,
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
                                    displayName,
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
                              displayEmail,
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
                              'Guest Spender',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            const VGapXs(),
                            Text(
                              displayEmail,
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
                      const HGapSm(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: cloud == null || signingIn ? null : onSignIn,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 16,
                                  color: AppTheme.primaryColor,
                                ),
                                HGapXs(),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                _MiniStat(
                  value: AppFormat.currency(finance.monthlyExpense),
                  label: 'Spent',
                  icon: Icons.arrow_upward_rounded,
                  color: AppTheme.pastelCoralText(context),
                ),
                _StatDivider(),
                _MiniStat(
                  value: '$savedRate%',
                  label: 'Saved',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF10B981),
                ),
                _StatDivider(),
                _MiniStat(
                  value: '${getIt<SubscriptionController>().activeCount}',
                  label: 'Subs',
                  icon: Icons.repeat_rounded,
                  color: const Color(0xFF06B6D4),
                ),
                _StatDivider(),
                _MiniStat(
                  value: AppFormat.currency(getIt<DebtController>().netBalance),
                  label: 'Udar',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.pastelBlueText(context),
                ),
              ],
            ),
          ),
        ],
      ),
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
  final int transactionCount;
  final int budgetCount;
  final int activeSubscriptions;
  final int smsPendingCount;
  final VoidCallback onTransactionsTap;
  final VoidCallback onBudgetsTap;
  final VoidCallback onSubscriptionsTap;
  final VoidCallback onUdarTap;
  final VoidCallback onSmsTap;

  const _ProfileMenuCard({
    required this.transactionCount,
    required this.budgetCount,
    required this.activeSubscriptions,
    required this.smsPendingCount,
    required this.onTransactionsTap,
    required this.onBudgetsTap,
    required this.onSubscriptionsTap,
    required this.onUdarTap,
    required this.onSmsTap,
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
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.pastelGreenText(context),
            iconBgColor: AppTheme.pastelGreen(context),
            title: 'Budget Transactions',
            trailing: _CountBadge(count: transactionCount),
            onTap: onTransactionsTap,
          ),
          _MenuDivider(),
          _MenuTile(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppTheme.pastelPurpleText(context),
            iconBgColor: AppTheme.pastelPurple(context),
            title: 'Manage Budgets',
            trailing: _CountBadge(count: budgetCount),
            onTap: onBudgetsTap,
          ),
          _MenuDivider(),
          _MenuTile(
            icon: Icons.repeat_rounded,
            iconColor: AppTheme.pastelIndigoText(context),
            iconBgColor: AppTheme.pastelIndigo(context),
            title: 'Subscriptions & recurring bills',
            trailing: _CountBadge(count: activeSubscriptions),
            onTap: onSubscriptionsTap,
          ),
          _MenuDivider(),
          _MenuTile(
            icon: Icons.people_alt_rounded,
            iconColor: AppTheme.pastelBlueText(context),
            iconBgColor: AppTheme.pastelBlue(context),
            title: 'Udar & splits',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMutedColor(context),
              size: 18,
            ),
            onTap: onUdarTap,
          ),
          _MenuDivider(),
          _MenuTile(
            icon: Icons.sms_rounded,
            iconColor: AppTheme.pastelOrangeText(context),
            iconBgColor: AppTheme.pastelOrange(context),
            title: 'SMS inbox',
            trailing: _CountBadge(count: smsPendingCount),
            onTap: onSmsTap,
          ),
        ],
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 52,
      color: AppTheme.borderColor(context),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textMutedColor(context),
        size: 18,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const HGapSm(),
        Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.textMutedColor(context),
          size: 18,
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.trailing,
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
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMutedColor(context),
                    size: 18,
                  ),
            ],
          ),
        ),
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
