import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../models/split_share.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';
import 'contact_avatar.dart';
import 'sheet_action_widgets.dart';

class SplitExpenseSheet extends StatefulWidget {
  final double total;
  final List<Contact> contacts;
  final List<SplitShare> initialShares;

  const SplitExpenseSheet({
    super.key,
    required this.total,
    required this.contacts,
    this.initialShares = const [],
  });

  static Future<List<SplitShare>?> show(
    BuildContext context, {
    required double total,
    required List<Contact> contacts,
    List<SplitShare> initialShares = const [],
  }) {
    return showModalBottomSheet<List<SplitShare>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SplitExpenseSheet(
          total: total,
          contacts: contacts,
          initialShares: initialShares,
        ),
      ),
    );
  }

  @override
  State<SplitExpenseSheet> createState() => _SplitExpenseSheetState();
}

class _SplitExpenseSheetState extends State<SplitExpenseSheet> {
  final Map<String, TextEditingController> _amountControllers = {};
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    for (final share in widget.initialShares) {
      final exists = widget.contacts.any(
        (contact) => contact.id == share.contactId,
      );
      if (!exists) continue;
      _selectedIds.add(share.contactId);
      _amountControllers[share.contactId] = TextEditingController(
        text: _formatAmount(share.amount),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _allocated {
    var total = 0.0;
    for (final id in _selectedIds) {
      total +=
          double.tryParse(
            _amountControllers[id]?.text.trim().replaceAll(',', '') ?? '',
          ) ??
          0;
    }
    return total;
  }

  double get _yourShare => widget.total - _allocated;

  bool get _isOverTotal => _yourShare < -0.01;

  void _toggleContact(Contact contact) {
    setState(() {
      if (_selectedIds.remove(contact.id)) {
        _amountControllers.remove(contact.id)?.dispose();
      } else {
        _selectedIds.add(contact.id);
        _amountControllers[contact.id] = TextEditingController();
      }
    });
    if (_selectedIds.contains(contact.id)) {
      _resetEqual();
    }
  }

  void _resetEqual() {
    if (_selectedIds.isEmpty) return;
    final share = widget.total / (_selectedIds.length + 1);
    setState(() {
      for (final id in _selectedIds) {
        _amountControllers[id]!.text = _formatAmount(share);
      }
    });
  }

  String _formatAmount(double amount) {
    final fixed = amount.toStringAsFixed(2);
    if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
    return fixed;
  }

  void _submit() {
    if (_selectedIds.isEmpty) {
      _showMessage('Select at least one contact.');
      return;
    }
    final parsed = <SplitShare>[];
    for (final id in _selectedIds) {
      final amount = double.tryParse(
        _amountControllers[id]?.text.trim().replaceAll(',', '') ?? '',
      );
      if (amount == null || amount < 0) {
        _showMessage('Enter a valid amount for every selected contact.');
        return;
      }
      if (amount > 0) {
        parsed.add(SplitShare(contactId: id, amount: amount));
      }
    }
    if (parsed.isEmpty) {
      _showMessage('Allocate at least some amount.');
      return;
    }
    final allocated = parsed.fold<double>(0, (sum, item) => sum + item.amount);
    if (allocated > widget.total + 0.01) {
      _showMessage('Allocated amount cannot exceed the expense.');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedContacts = widget.contacts
        .where((contact) => _selectedIds.contains(contact.id))
        .toList(growable: false);
    final remaining = _yourShare;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.86,
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm + 2,
        AppTheme.spacingMd,
        MediaQuery.paddingOf(context).bottom + AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandleBar(),
          const VGapMd(),
          SheetHeader(
            badge: const SheetHeaderBadge(
              child: Icon(Icons.call_split_rounded, size: 20),
            ),
            title: 'Split this expense',
            subtitle:
                'Total ${AppFormat.currency(widget.total)}. '
                'Equal split includes your share.',
          ),
          const VGapMd(),
          if (widget.contacts.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Add contacts in Udar before splitting an expense.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  Row(
                    children: [
                      Text('Split with', style: textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: _selectedIds.isEmpty ? null : _resetEqual,
                        child: const Text('Reset equal'),
                      ),
                    ],
                  ),
                  const VGapXs(),
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingSm,
                    children: widget.contacts.map((contact) {
                      final selected = _selectedIds.contains(contact.id);
                      return FilterChip(
                        selected: selected,
                        showCheckmark: false,
                        avatar: ContactAvatar(contact: contact, size: 22),
                        label: Text(contact.name),
                        onSelected: (_) => _toggleContact(contact),
                      );
                    }).toList(),
                  ),
                  if (selectedContacts.isNotEmpty) ...[
                    const VGapLg(),
                    Text('Allocation', style: textTheme.titleMedium),
                    const VGapSm(),
                    ...selectedContacts.map((contact) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacingSm,
                        ),
                        child: Row(
                          children: [
                            ContactAvatar(contact: contact, size: 34),
                            const HGapSm(),
                            Expanded(
                              child: Text(
                                contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyLarge,
                              ),
                            ),
                            const HGapSm(),
                            SizedBox(
                              width: 112,
                              child: TextField(
                                controller: _amountControllers[contact.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.end,
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const VGapSm(),
                  Text(
                    'Unallocated amounts count as your own share.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const VGapSm(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            decoration: BoxDecoration(
              color:
                  (_isOverTotal ? AppTheme.errorColor : AppTheme.primaryColor)
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            ),
            child: Row(
              children: [
                Text(
                  _isOverTotal ? 'Over total by' : 'Your share',
                  style: textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  AppFormat.currency(remaining.abs()),
                  style: textTheme.titleMedium?.copyWith(
                    color: _isOverTotal
                        ? AppTheme.errorColor
                        : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const VGapSm(),
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: FilledButton.icon(
              onPressed: _selectedIds.isEmpty ? null : _submit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Split expense'),
            ),
          ),
        ],
      ),
    );
  }
}
