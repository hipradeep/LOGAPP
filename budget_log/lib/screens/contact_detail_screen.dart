import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/contacts_controller.dart';
import '../controllers/debt_controller.dart';
import '../models/contact.dart';
import '../models/debt_record.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/add_debt_sheet.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/settle_debt_sheet.dart';
import 'add_contact_screen.dart';

class ContactDetailScreen extends StatelessWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  static Future<void> navigate(
    BuildContext context, {
    required String contactId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(contactId: contactId),
      ),
    );
  }

  ContactsController get _contactsController => getIt<ContactsController>();
  DebtController get _debtController => getIt<DebtController>();

  Future<void> _share(
    BuildContext context,
    Contact contact,
    List<DebtRecord> records,
  ) async {
    final net = _debtController.netForContact(contact.id);
    final summary = StringBuffer()
      ..writeln('Udar — ${contact.name}')
      ..writeln(
        net > 0.01
            ? 'You are owed ${AppFormat.currency(net)}'
            : net < -0.01
            ? 'You owe ${AppFormat.currency(net.abs())}'
            : 'All settled',
      );

    if (records.isNotEmpty) {
      summary.writeln();
      for (final record in records) {
        final direction = record.isGiven ? 'Gave' : 'Took';
        final status = record.outstanding > 0
            ? '${AppFormat.currency(record.outstanding)} pending'
            : 'Settled';
        summary.writeln(
          '${AppFormat.mediumDate(record.createdAt)} · $direction '
          '${AppFormat.currency(record.amount)} · $status',
        );
      }
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: summary.toString().trim(),
          subject: 'Udar summary — ${contact.name}',
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share summary: $error')),
      );
    }
  }

  Future<void> _deleteRecord(BuildContext context, DebtRecord record) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'ledger entry',
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _debtController.deleteDebt(record.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ledger entry deleted')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete entry: $error')),
      );
    }
  }

  Future<void> _addEntry(BuildContext context, Contact contact) async {
    await AddDebtSheet.show(context, contact);
  }

  Future<void> _settle(
    BuildContext context,
    Contact contact,
    DebtRecord record,
  ) async {
    if (record.outstanding <= 0) return;
    await SettleDebtSheet.show(context, contact: contact, record: record);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_contactsController, _debtController]),
      builder: (context, _) {
        final contact = _contactsController.contactById(contactId);
        if (contact == null) {
          return Scaffold(
            backgroundColor: AppTheme.background(context),
            body: SafeArea(
              child: Column(
                children: [
                  const CustomAppBar(title: 'Contact'),
                  Expanded(
                    child: AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'Contact not found',
                      description: 'This contact may have been deleted.',
                      actionLabel: 'Go back',
                      onActionPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final records = _debtController.recordsForContact(contact.id);
        final net = _debtController.netForContact(contact.id);
        final given = _debtController.givenForContact(contact.id);
        final taken = _debtController.takenForContact(contact.id);

        return Scaffold(
          backgroundColor: AppTheme.background(context),
          body: SafeArea(
            child: Column(
              children: [
                CustomAppBar(
                  title: contact.name,
                  subtitle: 'Udar ledger',
                  actions: [
                    IconButton(
                      onPressed: () => _share(context, contact, records),
                      icon: const Icon(Icons.ios_share_rounded),
                      tooltip: 'Share summary',
                    ),
                    IconButton(
                      onPressed: () => AddContactScreen.navigate(
                        context,
                        existingContact: contact,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit contact',
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      0,
                      AppTheme.spacingMd,
                      AppTheme.spacingXl,
                    ),
                    children: [
                      _ContactHeader(
                        contact: contact,
                        net: net,
                        given: given,
                        taken: taken,
                      ),
                      const VGapMd(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addEntry(context, contact),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add entry'),
                            ),
                          ),
                          const HGapSm(),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final pending = records
                                    .where((item) => item.outstanding > 0)
                                    .fold<double>(
                                      0,
                                      (sum, item) => sum + item.outstanding,
                                    );
                                if (pending <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nothing pending to settle',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final firstPending = records.firstWhere(
                                  (item) => item.outstanding > 0,
                                );
                                _settle(context, contact, firstPending);
                              },
                              icon: const Icon(
                                Icons.task_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('Settle up'),
                            ),
                          ),
                        ],
                      ),
                      const VGapLg(),
                      Row(
                        children: [
                          Text(
                            'Ledger',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${records.length} entr${records.length == 1 ? 'y' : 'ies'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const VGapSm(),
                      if (records.isEmpty)
                        AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No ledger entries',
                          description:
                              'Add money you gave or took to start tracking.',
                          actionLabel: 'Add entry',
                          onActionPressed: () => _addEntry(context, contact),
                        )
                      else
                        ...records.map(
                          (record) => _DebtEntryCard(
                            record: record,
                            onTap: () => _settle(context, contact, record),
                            onDelete: () => _deleteRecord(context, record),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactHeader extends StatelessWidget {
  final Contact contact;
  final double net;
  final double given;
  final double taken;

  const _ContactHeader({
    required this.contact,
    required this.net,
    required this.given,
    required this.taken,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = net > 0.01
        ? AppTheme.successColor
        : net < -0.01
        ? AppTheme.errorColor
        : AppTheme.textSecondaryColor(context);
    final label = net > 0.01
        ? 'Owes you'
        : net < -0.01
        ? 'You owe'
        : 'All settled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                ContactAvatar(contact: contact, size: 56),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.name, style: textTheme.titleLarge),
                      if (contact.phone != null || contact.upiId != null) ...[
                        const VGapXs(),
                        Text(
                          [
                            if (contact.phone != null) contact.phone!,
                            if (contact.upiId != null) contact.upiId!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const VGapMd(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(color: accent),
                  ),
                  const VGapXs(),
                  Text(
                    AppFormat.currency(net.abs()),
                    style: textTheme.displaySmall?.copyWith(color: accent),
                  ),
                ],
              ),
            ),
            const VGapMd(),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'You gave',
                    value: AppFormat.currency(given),
                    color: AppTheme.successColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.borderColor(context),
                ),
                Expanded(
                  child: _Metric(
                    label: 'You took',
                    value: AppFormat.currency(taken),
                    color: AppTheme.errorColor,
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label, style: textTheme.labelSmall),
        const VGapXs(),
        Text(value, style: textTheme.titleMedium?.copyWith(color: color)),
      ],
    );
  }
}

class _DebtEntryCard extends StatelessWidget {
  final DebtRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DebtEntryCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final given = record.isGiven;
    final accent = given ? AppTheme.successColor : AppTheme.errorColor;
    final settled = record.outstanding <= 0;
    final overdue =
        !settled &&
        record.dueDate != null &&
        record.dueDate!.isBefore(
          DateTime.now().subtract(const Duration(days: 1)),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: settled ? null : onTap,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  given ? Icons.call_made_rounded : Icons.call_received_rounded,
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
                      given ? 'You gave' : 'You took',
                      style: textTheme.titleSmall,
                    ),
                    const VGapXs(),
                    Text(
                      [
                        AppFormat.mediumDate(record.createdAt),
                        if (record.notes != null) record.notes!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    if (record.dueDate != null) ...[
                      const VGapXs(),
                      Text(
                        overdue
                            ? 'Overdue · ${AppFormat.mediumDate(record.dueDate!)}'
                            : 'Due ${AppFormat.mediumDate(record.dueDate!)}',
                        style: textTheme.labelSmall?.copyWith(
                          color: overdue
                              ? AppTheme.errorColor
                              : AppTheme.textMutedColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const HGapSm(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormat.currency(record.amount),
                    style: textTheme.titleMedium,
                  ),
                  const VGapXs(),
                  Text(
                    settled
                        ? 'Settled'
                        : '${AppFormat.currency(record.outstanding)} left',
                    style: textTheme.labelSmall?.copyWith(
                      color: settled
                          ? AppTheme.successColor
                          : AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Entry actions',
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (value) {
                  if (value == 'settle') onTap();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  if (!settled)
                    const PopupMenuItem(
                      value: 'settle',
                      child: Text('Settle up'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
