import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_action_buttons.dart';
import '../services/preferences_service.dart';

const List<Map<String, dynamic>> _paymentIcons = [
  {'name': 'attach_money_rounded', 'icon': Icons.attach_money_rounded},
  {'name': 'smartphone_rounded', 'icon': Icons.smartphone_rounded},
  {'name': 'account_balance_rounded', 'icon': Icons.account_balance_rounded},
  {'name': 'credit_card_rounded', 'icon': Icons.credit_card_rounded},
  {'name': 'account_balance_wallet_rounded', 'icon': Icons.account_balance_wallet_rounded},
  {'name': 'language_rounded', 'icon': Icons.language_rounded},
  {'name': 'payment_rounded', 'icon': Icons.payment_rounded},
];

const List<Color> _paymentColors = [
  Colors.green,
  Colors.indigo,
  Colors.orange,
  Colors.deepPurple,
  Colors.pinkAccent,
  Colors.blue,
  Colors.teal,
  Colors.blueGrey,
];

IconData getPaymentIcon(String name) {
  for (var i in _paymentIcons) {
    if (i['name'] == name) return i['icon'] as IconData;
  }
  return Icons.payment_rounded;
}

class PaymentModeScreen extends StatefulWidget {
  const PaymentModeScreen({super.key});

  @override
  State<PaymentModeScreen> createState() => _PaymentModeScreenState();
}

class _PaymentModeScreenState extends State<PaymentModeScreen> {
  final PreferencesService _prefs = PreferencesService();
  List<Map<String, dynamic>> _modes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _prefs.getPaymentModes();
    if (mounted) {
      setState(() {
        _modes = list;
        _isLoading = false;
      });
    }
  }

  void _showAddPaymentModeSheet() {
    final labelController = TextEditingController();
    String selectedIcon = _paymentIcons.first['name'] as String;
    Color selectedColor = _paymentColors.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Payment Mode', style: AppTheme.headingSmall),
              const VGapMd(),
              TextField(
                controller: labelController,
                style: AppTheme.bodyLarge,
                decoration: const InputDecoration(hintText: 'e.g. Google Pay, HDFC Bank, Amex'),
              ),
              const VGapLg(),
              Text('Select Icon', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              const VGapSm(),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _paymentIcons.length,
                  separatorBuilder: (_, __) => const HGapSm(),
                  itemBuilder: (context, i) {
                    final item = _paymentIcons[i];
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final isSel = selectedIcon == name;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedIcon = name),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryColor.withValues(alpha: 0.25) : AppTheme.background(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? AppTheme.primaryColor : AppTheme.borderColor(context),
                          ),
                        ),
                        child: Icon(icon, color: isSel ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context)),
                      ),
                    );
                  },
                ),
              ),
              const VGapLg(),
              Text('Select Color', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              const VGapSm(),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _paymentColors.length,
                  separatorBuilder: (_, __) => const HGapSm(),
                  itemBuilder: (context, i) {
                    final color = _paymentColors[i];
                    final isSel = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VGapXl(),
              AppActionButtons(
                primaryLabel: 'Add Payment Mode',
                onPrimaryPressed: () async {
                  final text = labelController.text.trim();
                  if (text.isEmpty) return;
                  final updated = List<Map<String, dynamic>>.from(_modes);
                  updated.add({
                    'label': text,
                    'icon': selectedIcon,
                    'color': selectedColor.toARGB32(),
                    'count': 0,
                  });
                  await _prefs.savePaymentModes(updated);
                  setState(() => _modes = updated);
                  if (mounted) Navigator.pop(ctx);
                },
                cancelLabel: 'Cancel',
                onCancelPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deletePaymentMode(int index) async {
    final updated = List<Map<String, dynamic>>.from(_modes)..removeAt(index);
    await _prefs.savePaymentModes(updated);
    setState(() => _modes = updated);
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      title: 'Payment Modes',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: _showAddPaymentModeSheet,
        ),
      ],
      children: [
        const VGapSm(),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _modes.length,
            itemBuilder: (context, index) {
              final mode = _modes[index];
              final label = mode['label'] as String;
              final iconName = mode['icon'] as String? ?? 'payment';
              final color = Color(mode['color'] as int? ?? 0xFF8B5CF6);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(getPaymentIcon(iconName), color: color, size: 20),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
                      onPressed: () => _deletePaymentMode(index),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
