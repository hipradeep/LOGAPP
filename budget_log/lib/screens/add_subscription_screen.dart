import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/subscription.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/id_utils.dart';
import '../utils/subscription_schedule.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? existingSubscription;

  const AddSubscriptionScreen({super.key, this.existingSubscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _frequency;
  late DateTime _nextDueDate;
  String? _categoryId;
  String? _paymentModeId;
  late bool _isAutopay;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEditing => widget.existingSubscription != null;

  @override
  void initState() {
    super.initState();
    final subscription = widget.existingSubscription;
    _nameController = TextEditingController(text: subscription?.name ?? '');
    _amountController = TextEditingController(
      text: subscription == null ? '' : subscription.amount.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: subscription?.notes ?? '');
    _frequency = subscription?.frequency ?? 'monthly';
    if (!SubscriptionSchedule.frequencies.contains(_frequency)) {
      _frequency = 'monthly';
    }
    _nextDueDate = SubscriptionSchedule.startOfDay(
      subscription?.nextDueDate ?? DateTime.now(),
    );
    _categoryId = subscription?.categoryId;
    _paymentModeId = subscription?.paymentModeId;
    _isAutopay = subscription?.isAutopay ?? false;
    _isActive = subscription?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _nextDueDate = SubscriptionSchedule.startOfDay(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    final controller = getIt<SubscriptionController>();
    final messenger = ScaffoldMessenger.of(context);
    final existing = widget.existingSubscription;
    final now = DateTime.now();
    final notes = _notesController.text.trim();
    final subscription = Subscription(
      id: existing?.id ?? IdUtils.generate('sub'),
      name: _nameController.text.trim(),
      amount: amount,
      categoryId: _categoryId,
      paymentModeId: _paymentModeId,
      frequency: _frequency,
      nextDueDate: _nextDueDate,
      reminderDaysBefore: existing?.reminderDaysBefore ?? 1,
      isActive: _isActive,
      isAutopay: _isAutopay,
      notes: notes.isEmpty ? null : notes,
      createdAt: existing?.createdAt ?? now,
    );

    try {
      if (existing == null) {
        await controller.addSubscription(subscription);
      } else {
        await controller.updateSubscription(subscription);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Subscription updated' : 'Subscription added',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not save subscription: $error');
    }
  }

  Future<void> _delete() async {
    final subscription = widget.existingSubscription;
    if (subscription == null) return;
    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'subscription',
      message: 'This removes the reminder and its schedule.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await getIt<SubscriptionController>().deleteSubscription(subscription.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Subscription deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not delete subscription: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final finance = AppProvider.read<FinanceController>(context);
    final categories = finance.categoriesForType('expense');
    final paymentModes = finance.paymentModes;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing ? 'Edit subscription' : 'New subscription',
              subtitle: _isEditing
                  ? 'Update the bill, schedule or reminder status.'
                  : 'Track a recurring bill and get reminded before it is due.',
              actions: [
                if (_isEditing)
                  IconButton(
                    onPressed: _isSaving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    tooltip: 'Delete subscription',
                  ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                    AppTheme.spacingMd,
                    AppTheme.spacingXl,
                  ),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Subscription name',
                        hintText: 'Netflix, rent, internet...',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a subscription name';
                        }
                        return null;
                      },
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        hintText: '499',
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
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Repeats'),
                      items: [
                        for (final frequency
                            in SubscriptionSchedule.frequencies)
                          DropdownMenuItem(
                            value: frequency,
                            child: Text(SubscriptionSchedule.label(frequency)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _frequency = value);
                      },
                    ),
                    const VGapMd(),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId ?? '',
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No category'),
                        ),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _categoryId = value == null || value.isEmpty
                              ? null
                              : value;
                        });
                      },
                    ),
                    const VGapMd(),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentModeId ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Payment mode',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No payment mode'),
                        ),
                        for (final mode in paymentModes)
                          DropdownMenuItem(
                            value: mode.id,
                            child: Text(mode.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _paymentModeId = value == null || value.isEmpty
                              ? null
                              : value;
                        });
                      },
                    ),
                    const VGapMd(),
                    Card(
                      child: ListTile(
                        onTap: _isSaving ? null : _pickDate,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Next due date'),
                        subtitle: Text(
                          AppFormat.mediumDate(_nextDueDate),
                          style: textTheme.titleMedium,
                        ),
                        trailing: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                    const VGapMd(),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _isAutopay,
                            onChanged: (value) {
                              setState(() => _isAutopay = value);
                            },
                            title: const Text('Autopay'),
                            subtitle: const Text(
                              'Recorded as a label only. Mark payments manually.',
                            ),
                          ),
                          Divider(
                            color: AppTheme.borderColor(context),
                            height: 1,
                          ),
                          SwitchListTile(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                            title: const Text('Active'),
                            subtitle: const Text(
                              'Paused subscriptions keep their schedule but '
                              'do not send reminders.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional account or plan details',
                      ),
                    ),
                    const VGapLg(),
                    Card(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const HGapSm(),
                            Expanded(
                              child: Text(
                                'Reminders fire 3 days before, 1 day before, '
                                'and on the due date at 9:00 AM.',
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingSm,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isEditing ? 'Save changes' : 'Add subscription'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
