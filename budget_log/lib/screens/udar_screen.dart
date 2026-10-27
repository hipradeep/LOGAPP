import 'package:flutter/material.dart';

import '../controllers/contacts_controller.dart';
import '../controllers/debt_controller.dart';
import '../models/contact.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_spacers.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/custom_app_bar.dart';
import 'add_contact_screen.dart';
import 'contact_detail_screen.dart';

class UdarScreen extends StatelessWidget {
  final bool showBackButton;

  const UdarScreen({super.key, this.showBackButton = true});

  ContactsController get _contactsController => getIt<ContactsController>();
  DebtController get _debtController => getIt<DebtController>();

  Future<void> _refresh() async {
    await Future.wait([_contactsController.reload(), _debtController.reload()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Udar',
              subtitle: 'Split money and keep give & owe balances clear.',
              showBackButton: showBackButton,
              actions: [
                IconButton(
                  onPressed: () => AddContactScreen.navigate(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: 'Add contact',
                ),
              ],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _contactsController,
                  _debtController,
                ]),
                builder: (context, _) {
                  final contacts = _contactsController.contacts;
                  if (_contactsController.isLoading &&
                      _debtController.isLoading &&
                      contacts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (contacts.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          AppEmptyState(
                            icon: Icons.people_alt_outlined,
                            title: 'No contacts yet',
                            description:
                                'Add friends and family to split expenses '
                                'or track money you lend and borrow.',
                            actionLabel: 'Add contact',
                            onActionPressed: () =>
                                AddContactScreen.navigate(context),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        96,
                      ),
                      children: [
                        _BalanceHeader(
                          given: _debtController.totalGiven,
                          taken: _debtController.totalTaken,
                        ),
                        const VGapLg(),
                        Row(
                          children: [
                            Text(
                              'People',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${contacts.length} contact'
                              '${contacts.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const VGapSm(),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < contacts.length;
                                index++
                              ) ...[
                                _ContactRow(
                                  contact: contacts[index],
                                  net: _debtController.netForContact(
                                    contacts[index].id,
                                  ),
                                  entryCount: _debtController
                                      .recordsForContact(contacts[index].id)
                                      .length,
                                  onTap: () => ContactDetailScreen.navigate(
                                    context,
                                    contactId: contacts[index].id,
                                  ),
                                ),
                                if (index < contacts.length - 1)
                                  Divider(
                                    height: 1,
                                    indent: 68,
                                    color: AppTheme.borderColor(context),
                                  ),
                              ],
                            ],
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
      floatingActionButton: AppFab(
        onPressed: () => AddContactScreen.navigate(context),
        icon: Icons.person_add_alt_1_rounded,
        label: 'Contact',
        tooltip: 'Add contact',
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final double given;
  final double taken;

  const _BalanceHeader({required this.given, required this.taken});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final net = given - taken;
    final isSettled = given < 0.01 && taken < 0.01;
    final accent = net > 0.01
        ? AppTheme.successColor
        : net < -0.01
        ? AppTheme.errorColor
        : AppTheme.textSecondaryColor(context);
    final label = isSettled
        ? 'All settled'
        : net > 0.01
        ? 'You are owed'
        : 'You owe';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Text(label, style: textTheme.labelSmall?.copyWith(color: accent)),
          const VGapXs(),
          Text(
            AppFormat.currency(net.abs()),
            style: textTheme.displaySmall?.copyWith(
              color: accent,
              fontSize: 30,
            ),
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: _BalanceMetric(
                  label: 'You gave',
                  value: given,
                  color: AppTheme.successColor,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppTheme.borderColor(context),
              ),
              Expanded(
                child: _BalanceMetric(
                  label: 'You took',
                  value: taken,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BalanceMetric({
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
        Text(
          AppFormat.currency(value),
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Contact contact;
  final double net;
  final int entryCount;
  final VoidCallback onTap;

  const _ContactRow({
    required this.contact,
    required this.net,
    required this.entryCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final owesYou = net > 0.01;
    final youOwe = net < -0.01;
    final accent = owesYou
        ? AppTheme.successColor
        : youOwe
        ? AppTheme.errorColor
        : AppTheme.textMutedColor(context);
    final label = owesYou
        ? 'Owes you'
        : youOwe
        ? 'You owe'
        : entryCount == 0
        ? 'No entries yet'
        : 'Settled up';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm + 2,
        ),
        child: Row(
          children: [
            ContactAvatar(contact: contact),
            const HGapSm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const VGapXs(),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const HGapXs(),
                      Text(
                        label,
                        style: textTheme.bodySmall?.copyWith(color: accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const HGapSm(),
            Text(
              net.abs() < 0.01 ? '—' : AppFormat.currency(net.abs()),
              style: textTheme.titleMedium?.copyWith(
                color: net.abs() < 0.01
                    ? AppTheme.textMutedColor(context)
                    : AppTheme.textPrimaryColor(context),
              ),
            ),
            const HGapXs(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textMutedColor(context),
            ),
          ],
        ),
      ),
    );
  }
}
