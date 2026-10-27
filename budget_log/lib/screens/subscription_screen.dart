import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/subscription_controller.dart';
import '../models/subscription.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/subscription_schedule.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import 'add_subscription_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final SubscriptionController _controller =
      getIt<SubscriptionController>();
  bool? _notificationsEnabled;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshNotificationState());
  }

  Future<void> _refreshNotificationState() async {
    if (!getIt.isRegistered<NotificationService>()) return;
    final enabled = await getIt<NotificationService>().notificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequestingPermission = true);
    final granted = await getIt<NotificationService>().requestPermission();
    if (!mounted) return;
    setState(() => _isRequestingPermission = false);
    await _refreshNotificationState();
    await _controller.reload();
    if (!mounted) return;
    _showMessage(
      granted
          ? 'Reminders enabled'
          : 'Notifications are still off. Enable them in system settings.',
    );
  }

  Future<void> _markPaid(Subscription subscription) async {
    final updated = await _controller.markPaid(subscription);
    if (!mounted) return;
    _showMessage(
      updated == null
          ? 'This bill was already updated or is no longer active.'
          : '${subscription.name} marked as paid',
    );
  }

  Future<void> _toggleActive(Subscription subscription) async {
    await _controller.setActive(subscription.id, !subscription.isActive);
    if (!mounted) return;
    _showMessage(
      subscription.isActive
          ? '${subscription.name} paused'
          : '${subscription.name} resumed',
    );
  }

  Future<void> _delete(Subscription subscription) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'subscription',
      message: 'This removes the reminder and its schedule.',
    );
    if (!confirmed || !mounted) return;
    await _controller.deleteSubscription(subscription.id);
    if (!mounted) return;
    _showMessage('${subscription.name} deleted');
  }

  void _openForm([Subscription? subscription]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddSubscriptionScreen(existingSubscription: subscription),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'Subscriptions',
              subtitle: 'Recurring bills, autopay labels and reminders.',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isLoading &&
                      _controller.subscriptions.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return RefreshIndicator(
                    onRefresh: _controller.reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        96,
                      ),
                      children: [
                        _SubscriptionSummary(controller: _controller),
                        if (_notificationsEnabled == false) ...[
                          const VGapMd(),
                          _NotificationBanner(
                            isRequesting: _isRequestingPermission,
                            onEnable: _requestPermission,
                          ),
                        ],
                        if (_controller.subscriptions.isEmpty)
                          AppEmptyState(
                            icon: Icons.autorenew_rounded,
                            title: 'No subscriptions yet',
                            description:
                                'Add rent, streaming, internet or any '
                                'recurring bill to get reminders before it is due.',
                            actionLabel: 'Add subscription',
                            onActionPressed: _openForm,
                          )
                        else ...[
                          if (_controller.overdueSubscriptions.isNotEmpty) ...[
                            const VGapLg(),
                            _SectionHeader(
                              title: 'Overdue',
                              count: _controller.overdueSubscriptions.length,
                              color: AppTheme.expenseColor,
                            ),
                            const VGapSm(),
                            ..._buildTiles(_controller.overdueSubscriptions),
                          ],
                          if (_controller.upcomingSubscriptions.isNotEmpty) ...[
                            const VGapLg(),
                            _SectionHeader(
                              title: 'Upcoming',
                              count: _controller.upcomingSubscriptions.length,
                            ),
                            const VGapSm(),
                            ..._buildTiles(_controller.upcomingSubscriptions),
                          ],
                          if (_controller.pausedSubscriptions.isNotEmpty) ...[
                            const VGapLg(),
                            _SectionHeader(
                              title: 'Paused',
                              count: _controller.pausedSubscriptions.length,
                            ),
                            const VGapSm(),
                            ..._buildTiles(_controller.pausedSubscriptions),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: _openForm,
        icon: Icons.add_rounded,
        label: 'Add',
        tooltip: 'Add subscription',
      ),
    );
  }

  List<Widget> _buildTiles(List<Subscription> subscriptions) {
    final children = <Widget>[];
    for (var index = 0; index < subscriptions.length; index++) {
      final subscription = subscriptions[index];
      if (index > 0) children.add(const VGapSm());
      children.add(
        _SubscriptionTile(
          subscription: subscription,
          onTap: () => _openForm(subscription),
          onMarkPaid: subscription.isActive
              ? () => _markPaid(subscription)
              : null,
          onToggleActive: () => _toggleActive(subscription),
          onDelete: () => _delete(subscription),
        ),
      );
    }
    return children;
  }
}

class _SubscriptionSummary extends StatelessWidget {
  final SubscriptionController controller;

  const _SubscriptionSummary({required this.controller});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final next = controller.nextSubscription;
    final overdue = controller.overdueSubscriptions.length;
    final monthly = controller.activeSubscriptions.fold<double>(
      0,
      (total, subscription) => total + _monthlyEquivalent(subscription),
    );
    final accent = overdue > 0 ? AppTheme.expenseColor : AppTheme.primaryColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Recurring bills', style: textTheme.bodySmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      AppTheme.pillBorderRadius,
                    ),
                  ),
                  child: Text(
                    overdue > 0 ? '$overdue overdue' : 'On track',
                    style: textTheme.labelSmall?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            const VGapXs(),
            Text(AppFormat.currency(monthly), style: textTheme.displaySmall),
            Text('estimated monthly cost', style: textTheme.bodySmall),
            const VGapMd(),
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapMd(),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Active',
                    value: '${controller.activeCount}',
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Paused',
                    value: '${controller.pausedSubscriptions.length}',
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Next due',
                    value: next == null
                        ? 'None'
                        : AppFormat.shortDate(next.nextDueDate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall),
        const VGapXs(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final bool isRequesting;
  final VoidCallback onEnable;

  const _NotificationBanner({
    required this.isRequesting,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_off_outlined),
        title: const Text('Reminders are off'),
        subtitle: const Text(
          'Allow notifications to get alerts 3 days before, 1 day before, '
          'and on the due date.',
        ),
        trailing: TextButton(
          onPressed: isRequesting ? null : onEnable,
          child: isRequesting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enable'),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color? color;

  const _SectionHeader({required this.title, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = color ?? AppTheme.textPrimaryColor(context);
    return Row(
      children: [
        Text(title, style: textTheme.titleMedium?.copyWith(color: textColor)),
        const HGapXs(),
        Text('$count', style: textTheme.bodySmall),
      ],
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback? onMarkPaid;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SubscriptionTile({
    required this.subscription,
    required this.onTap,
    required this.onMarkPaid,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dueLabel = SubscriptionSchedule.dueLabel(subscription.nextDueDate);
    final daysUntil = SubscriptionSchedule.daysUntil(subscription.nextDueDate);
    final dueColor = !subscription.isActive
        ? AppTheme.textMutedColor(context)
        : daysUntil < 0
        ? AppTheme.expenseColor
        : daysUntil <= 3
        ? AppTheme.warningColor
        : AppTheme.textSecondaryColor(context);
    final scheduleText = subscription.isActive ? dueLabel : 'Paused';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingXs,
            AppTheme.spacingSm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.autorenew_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subscription.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (subscription.isAutopay) ...[
                          const HGapXs(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AUTOPAY',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const VGapXs(),
                    Text(
                      '$scheduleText · '
                      '${SubscriptionSchedule.label(subscription.frequency)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: dueColor),
                    ),
                  ],
                ),
              ),
              const HGapXs(),
              Text(
                AppFormat.currency(subscription.amount),
                style: textTheme.titleMedium,
              ),
              if (onMarkPaid != null)
                IconButton(
                  onPressed: onMarkPaid,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  color: AppTheme.incomeColor,
                  tooltip: 'Mark as paid',
                )
              else
                const SizedBox(width: AppTheme.spacingXs),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onTap();
                      return;
                    case 'toggle':
                      onToggleActive();
                      return;
                    case 'delete':
                      onDelete();
                      return;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(subscription.isActive ? 'Pause' : 'Resume'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _monthlyEquivalent(Subscription subscription) {
  return switch (subscription.frequency) {
    'daily' => subscription.amount * 30,
    'weekly' => subscription.amount * 52 / 12,
    'quarterly' => subscription.amount / 3,
    'yearly' => subscription.amount / 12,
    _ => subscription.amount,
  };
}
