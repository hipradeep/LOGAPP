import 'package:flutter/material.dart';

import '../controllers/sms_inbox_controller.dart';
import '../models/budget_transaction.dart';
import '../models/debt_record.dart';
import '../models/staged_sms_transaction.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import 'add_transaction_screen.dart';

class SmsInboxScreen extends StatefulWidget {
  final SmsInboxController? controller;
  final String? initialValidationId;
  final String? initialValidationKind;

  const SmsInboxScreen({
    super.key,
    this.controller,
    this.initialValidationId,
    this.initialValidationKind,
  });

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  late final SmsInboxController _controller =
      widget.controller ?? getIt<SmsInboxController>();
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialTarget();
    });
  }

  Future<void> _openInitialTarget() async {
    final id = widget.initialValidationId;
    if (id == null || id.isEmpty) return;
    await _controller.initialize();
    if (widget.initialValidationKind == 'candidate') {
      await _controller.drainBackground();
    }
    await _controller.refresh();
    if (!mounted) return;

    StagedSmsTransaction? match;
    for (final item in _controller.pending) {
      if (item.id == id) {
        match = item;
        break;
      }
    }
    if (match == null) return;
    await _review(match);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final message = _controller.errorMessage ?? _controller.message;
    if (message == null) {
      _lastMessage = null;
      return;
    }
    if (message == _lastMessage) return;
    _lastMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      _controller.clearMessages();
    });
  }

  Future<void> _requestPermission() async {
    final granted = await _controller.requestSmsPermission();
    if (!granted || !mounted) return;
    await _requestNotificationPermission();
    await _controller.scanNow();
  }

  Future<void> _scanNow() async {
    if (!_controller.hasSmsPermission) {
      final granted = await _controller.requestSmsPermission();
      if (!granted || !mounted) return;
      await _requestNotificationPermission();
    }
    await _controller.scanNow();
  }

  Future<void> _requestNotificationPermission() async {
    await getIt<NotificationService>().requestPermission();
  }

  Future<void> _setBackgroundEnabled(bool enabled) async {
    if (enabled) {
      await _requestNotificationPermission();
    }
    await _controller.setBackgroundEnabled(enabled);
  }

  Future<void> _review(StagedSmsTransaction staged) async {
    await AddTransactionScreen.navigate(
      context,
      initialType: staged.isCredit ? 'income' : 'expense',
      initialAmount: staged.extractedAmount,
      initialTitle: _titleFor(staged),
      initialNote: 'Imported from SMS · ${staged.smsSender}',
      initialTimestamp: staged.smsTimestamp,
      onSave:
          (BudgetTransaction transaction, List<DebtRecord> debtRecords) async {
            final accepted = await _controller.accept(
              staged: staged,
              transaction: transaction,
              debtRecords: debtRecords,
            );
            if (!accepted) {
              throw StateError(
                _controller.errorMessage ?? 'Could not accept this SMS.',
              );
            }
          },
    );
  }

  Future<void> _reject(StagedSmsTransaction staged) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Reject this SMS transaction?',
      message: 'It will stay in the inbox history but will not be imported.',
      confirmText: 'Reject',
      destructive: true,
      icon: Icons.close_rounded,
    );
    if (!confirmed || !mounted) return;
    await _controller.reject(staged.id);
  }

  String _titleFor(StagedSmsTransaction staged) {
    final merchant = staged.extractedMerchant?.trim();
    if (merchant != null && merchant.isNotEmpty) return merchant;
    final sender = staged.smsSender.trim();
    return sender.isEmpty ? 'SMS transaction' : sender;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'SMS inbox',
              subtitle: 'Review bank credit and debit messages.',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return RefreshIndicator(
                    onRefresh: _controller.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        AppTheme.spacingXl,
                      ),
                      children: [
                        if (!_controller.hasSmsPermission) ...[
                          _PermissionCard(onAllow: _requestPermission),
                          const VGapMd(),
                        ],
                        _BackgroundCard(
                          controller: _controller,
                          onChanged: _controller.hasSmsPermission
                              ? _setBackgroundEnabled
                              : null,
                        ),
                        const VGapMd(),
                        _ScanCard(
                          isScanning: _controller.isScanning,
                          hasPermission: _controller.hasSmsPermission,
                          onScan: _scanNow,
                        ),
                        const VGapLg(),
                        Text(
                          _controller.pendingCount == 0
                              ? 'PENDING'
                              : 'PENDING · ${_controller.pendingCount}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const VGapSm(),
                        if (_controller.pending.isEmpty)
                          const _EmptyState()
                        else
                          ..._controller.pending.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.spacingSm,
                              ),
                              child: _PendingSmsCard(
                                staged: item,
                                title: _titleFor(item),
                                onReview: () => _review(item),
                                onReject: () => _reject(item),
                              ),
                            ),
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

class _PermissionCard extends StatelessWidget {
  final VoidCallback onAllow;

  const _PermissionCard({required this.onAllow});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sms_outlined, color: AppTheme.primaryColor),
                const HGapSm(),
                Expanded(
                  child: Text(
                    'SMS access is off',
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const VGapSm(),
            Text(
              'Allow SMS access to detect bank credit and debit messages. '
              'Only transaction messages are kept; OTPs and promotions are '
              'ignored.',
              style: textTheme.bodySmall,
            ),
            const VGapMd(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAllow,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Allow SMS access'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  final SmsInboxController controller;
  final ValueChanged<bool>? onChanged;

  const _BackgroundCard({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: controller.backgroundEnabled,
        onChanged: onChanged,
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
          ),
          child: const Icon(Icons.notifications_active_outlined, size: 18),
        ),
        title: const Text('Background capture'),
        subtitle: Text(
          controller.hasSmsPermission
              ? 'Get one validation alert at a time, even when the app is '
                    'closed.'
              : 'Allow SMS access first.',
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final bool isScanning;
  final bool hasPermission;
  final VoidCallback onScan;

  const _ScanCard({
    required this.isScanning,
    required this.hasPermission,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan now', style: textTheme.titleMedium),
            const VGapXs(),
            Text(
              hasPermission
                  ? 'Reads the last 30 days of inbox messages. Only credit '
                        'and debit transactions are staged.'
                  : 'Grant SMS access to read the inbox.',
              style: textTheme.bodySmall,
            ),
            const VGapMd(),
            SizedBox(
              width: double.infinity,
              height: AppTheme.buttonHeight,
              child: FilledButton.icon(
                onPressed: isScanning ? null : onScan,
                icon: isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text(isScanning ? 'Scanning...' : 'Scan SMS inbox'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingSmsCard extends StatelessWidget {
  final StagedSmsTransaction staged;
  final String title;
  final VoidCallback onReview;
  final VoidCallback onReject;

  const _PendingSmsCard({
    required this.staged,
    required this.title,
    required this.onReview,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCredit = staged.isCredit;
    final accent = isCredit
        ? AppTheme.pastelGreenText(context)
        : AppTheme.pastelCoralText(context);
    final accentBackground = isCredit
        ? AppTheme.pastelGreen(context)
        : AppTheme.pastelCoral(context);
    final amount = staged.extractedAmount;
    final account = staged.accountRef;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
                  ),
                  child: Icon(
                    isCredit
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const VGapXs(),
                      Text(
                        [
                          AppFormat.dateTime(staged.smsTimestamp),
                          if (account != null && account.isNotEmpty)
                            'A/c ••$account',
                        ].join(' · '),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                Text(
                  amount == null
                      ? '—'
                      : AppFormat.signedCurrency(amount, isExpense: !isCredit),
                  style: textTheme.titleMedium?.copyWith(color: accent),
                ),
              ],
            ),
            const VGapSm(),
            Text(
              staged.rawBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onReject, child: const Text('Reject')),
                const HGapXs(),
                FilledButton(onPressed: onReview, child: const Text('Review')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 32,
              color: AppTheme.successColor.withValues(alpha: 0.8),
            ),
            const VGapSm(),
            Text('Nothing waiting', style: textTheme.titleMedium),
            const VGapXs(),
            Text(
              'New credit and debit messages will appear here for review.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
