import 'package:flutter/material.dart';

import '../controllers/debt_controller.dart';
import '../models/contact.dart';
import '../services/service_locator.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

class AddDebtSheet extends StatefulWidget {
  final Contact contact;

  const AddDebtSheet({super.key, required this.contact});

  static Future<bool> show(BuildContext context, Contact contact) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(child: AddDebtSheet(contact: contact)),
      ),
    );
    return result ?? false;
  }

  @override
  State<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _direction = 'give';
  DateTime? _dueDate;
  bool _isSaving = false;

  DebtController get _controller => getIt<DebtController>();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.addDebt(
        contactId: widget.contact.id,
        direction: _direction,
        amount: amount,
        dueDate: _dueDate,
        notes: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _direction == 'give'
                ? 'Lending entry added'
                : 'Borrowing entry added',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add entry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        SheetHeader(
          badge: const SheetHeaderBadge(
            child: Icon(Icons.swap_horiz_rounded, size: 20),
          ),
          title: 'New Udar entry',
          subtitle:
              'Track money given to or taken from ${widget.contact.name}.',
        ),
        const VGapLg(),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'give',
                    label: Text('You gave'),
                    icon: Icon(Icons.call_made_rounded),
                  ),
                  ButtonSegment(
                    value: 'take',
                    label: Text('You took'),
                    icon: Icon(Icons.call_received_rounded),
                  ),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => _direction = selection.first);
                },
              ),
              const VGapMd(),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  return null;
                },
              ),
              const VGapMd(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text('Due date', style: textTheme.bodyMedium),
                  subtitle: Text(
                    _dueDate == null
                        ? 'No due date'
                        : AppFormat.mediumDate(_dueDate!),
                  ),
                  trailing: _dueDate == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          onPressed: () => setState(() => _dueDate = null),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear due date',
                        ),
                  onTap: _pickDueDate,
                ),
              ),
              const VGapMd(),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Optional details',
                ),
              ),
            ],
          ),
        ),
        const VGapLg(),
        SheetSubmitButton(
          text: 'Add entry',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}
