import 'package:flutter/material.dart';

import '../controllers/debt_controller.dart';
import '../controllers/finance_controller.dart';
import '../models/contact.dart';
import '../models/debt_record.dart';
import '../models/payment_mode.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

class SettleDebtSheet extends StatefulWidget {
  final Contact contact;
  final DebtRecord record;

  const SettleDebtSheet({
    super.key,
    required this.contact,
    required this.record,
  });

  static Future<bool> show(
    BuildContext context, {
    required Contact contact,
    required DebtRecord record,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: SettleDebtSheet(contact: contact, record: record),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<SettleDebtSheet> createState() => _SettleDebtSheetState();
}

class _SettleDebtSheetState extends State<SettleDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String? _paymentModeId;
  bool _isSaving = false;

  DebtController get _debtController => getIt<DebtController>();
  List<PaymentMode> get _paymentModes =>
      getIt<FinanceController>().paymentModes;

  double get _appliedAmount {
    final entered = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (entered == null || entered <= 0) return 0;
    return entered.clamp(0, widget.record.outstanding).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _formatAmount(widget.record.outstanding),
    );
    _paymentModeId = _paymentModes.isEmpty ? null : _paymentModes.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentModeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment mode first.')),
      );
      return;
    }
    final amount = _appliedAmount;
    if (amount <= 0) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _debtController.settleDebt(
        record: widget.record,
        contact: widget.contact,
        amount: amount,
        paymentModeId: _paymentModeId!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            amount >= widget.record.outstanding
                ? 'Settled with ${widget.contact.name}'
                : 'Partial payment recorded',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not settle entry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final record = widget.record;
    final isGiven = record.isGiven;
    final accent = isGiven ? AppTheme.successColor : AppTheme.errorColor;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: accent.withValues(alpha: 0.10),
            child: Icon(
              isGiven ? Icons.call_made_rounded : Icons.call_received_rounded,
              size: 20,
              color: accent,
            ),
          ),
          title: 'Settle up',
          subtitle: isGiven
              ? '${widget.contact.name} owes ${AppFormat.currency(record.outstanding)}'
              : 'You owe ${widget.contact.name} ${AppFormat.currency(record.outstanding)}',
        ),
        const VGapLg(),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Summary(
                  label: 'Total',
                  value: AppFormat.currency(record.amount),
                ),
              ),
              Expanded(
                child: _Summary(
                  label: 'Already paid',
                  value: AppFormat.currency(record.settledAmount),
                ),
              ),
              Expanded(
                child: _Summary(
                  label: 'Outstanding',
                  value: AppFormat.currency(record.outstanding),
                ),
              ),
            ],
          ),
        ),
        const VGapLg(),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Payment amount',
                  prefixText: '₹ ',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount greater than zero';
                  }
                  if (parsed > record.outstanding + 0.000001) {
                    return 'Amount exceeds outstanding balance';
                  }
                  return null;
                },
              ),
              const VGapMd(),
              Row(
                children: [
                  Text('Payment mode', style: textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    AppFormat.currency(_appliedAmount),
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const VGapSm(),
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: _paymentModes.map((mode) {
                  final selected = mode.id == _paymentModeId;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(
                      CategoryVisuals.paymentModeIcon(mode.type),
                      size: 16,
                      color: selected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor(context),
                    ),
                    label: Text(mode.name),
                    onSelected: (_) {
                      setState(() => _paymentModeId = mode.id);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const VGapLg(),
        SheetSubmitButton(
          text: 'Record settlement',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;

  const _Summary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall),
        const VGapXs(),
        Text(value, style: textTheme.titleSmall),
      ],
    );
  }
}
