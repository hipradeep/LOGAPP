import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/payment_mode.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sheet_action_widgets.dart';

class PaymentModesScreen extends StatelessWidget {
  const PaymentModesScreen({super.key});

  static const _types = <String, String>{
    'cash': 'Cash',
    'bank': 'Bank',
    'card': 'Card',
    'wallet': 'Wallet',
  };

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<FinanceController>(context);
    final modes = controller.paymentModes;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'Payment modes',
              subtitle: 'Cash, bank, cards, UPI and wallets.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingSm,
                  AppTheme.spacingMd,
                  96,
                ),
                children: [
                  if (modes.isEmpty)
                    AppEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No payment modes yet',
                      description:
                          'Add a way you pay so transactions can be grouped.',
                      actionLabel: 'Add payment mode',
                      onActionPressed: () => PaymentModeFormSheet.show(
                        context,
                        controller: controller,
                      ),
                    )
                  else
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < modes.length;
                            index++
                          ) ...[
                            _PaymentModeRow(
                              mode: modes[index],
                              typeLabel:
                                  _types[modes[index].type] ?? 'Payment mode',
                              onTap: () => PaymentModeFormSheet.show(
                                context,
                                controller: controller,
                                existing: modes[index],
                              ),
                            ),
                            if (index < modes.length - 1)
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
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () =>
            PaymentModeFormSheet.show(context, controller: controller),
        icon: Icons.add_rounded,
        label: 'Mode',
        tooltip: 'Add payment mode',
      ),
    );
  }
}

class _PaymentModeRow extends StatelessWidget {
  final PaymentMode mode;
  final String typeLabel;
  final VoidCallback onTap;

  const _PaymentModeRow({
    required this.mode,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.pastelBlue(context),
          borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
        ),
        alignment: Alignment.center,
        child: Icon(
          CategoryVisuals.paymentModeIcon(mode.type),
          color: AppTheme.pastelBlueText(context),
          size: 19,
        ),
      ),
      title: Text(mode.name),
      subtitle: Text(typeLabel),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class PaymentModeFormSheet extends StatefulWidget {
  final FinanceController controller;
  final PaymentMode? existing;

  const PaymentModeFormSheet({
    super.key,
    required this.controller,
    this.existing,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    PaymentMode? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: PaymentModeFormSheet(controller: controller, existing: existing),
      ),
    );
  }

  @override
  State<PaymentModeFormSheet> createState() => _PaymentModeFormSheetState();
}

class _PaymentModeFormSheetState extends State<PaymentModeFormSheet> {
  static const _types = <String, String>{
    'cash': 'Cash',
    'bank': 'Bank',
    'card': 'Card',
    'wallet': 'Wallet',
  };

  late final TextEditingController _nameController;
  late String _type;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _type = existing?.type ?? 'bank';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.controller.createPaymentMode(
          name: _nameController.text,
          type: _type,
        );
      } else {
        await widget.controller.updatePaymentMode(
          existing.copyWith(name: _nameController.text, type: _type),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error is ArgumentError
            ? error.message.toString()
            : 'Could not save this payment mode.';
      });
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _isSaving) return;

    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'payment mode',
      message:
          'Transactions using this mode will keep their records but lose '
          'this payment mode. This action cannot be undone.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await widget.controller.deletePaymentMode(existing.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not delete this payment mode.';
      });
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
          title: _isEditing ? 'Edit payment mode' : 'New payment mode',
          subtitle: 'Choose a name and how you pay.',
        ),
        const VGapMd(),
        TextField(
          controller: _nameController,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Payment mode name',
            hintText: 'HDFC UPI',
          ),
        ),
        if (_error != null) ...[
          const VGapXs(),
          Text(
            _error!,
            style: textTheme.labelSmall?.copyWith(color: AppTheme.errorColor),
          ),
        ],
        const VGapMd(),
        Text('Type', style: textTheme.labelLarge),
        const VGapSm(),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            for (final entry in _types.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _type == entry.key,
                showCheckmark: false,
                avatar: Icon(
                  CategoryVisuals.paymentModeIcon(entry.key),
                  size: 16,
                ),
                onSelected: (_) => setState(() => _type = entry.key),
              ),
          ],
        ),
        const VGapLg(),
        SheetSubmitButton(
          text: _isEditing ? 'Save changes' : 'Add payment mode',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
        if (_isEditing) ...[
          const VGapSm(),
          SheetDestructiveButton(title: 'Delete payment mode', onTap: _delete),
        ],
        const VGapXs(),
        const SheetCancelButton(),
      ],
    );
  }
}
