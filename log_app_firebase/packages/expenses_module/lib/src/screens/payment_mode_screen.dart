import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';

// ==================== ICON/COLOR CONSTANTS ====================

const List<Map<String, dynamic>> _availablePaymentIcons = [
  {'name': 'attach_money_rounded', 'icon': Icons.attach_money_rounded},
  {'name': 'account_balance_rounded', 'icon': Icons.account_balance_rounded},
  {'name': 'credit_card_rounded', 'icon': Icons.credit_card_rounded},
  {'name': 'account_balance_wallet_rounded', 'icon': Icons.account_balance_wallet_rounded},
  {'name': 'language_rounded', 'icon': Icons.language_rounded},
  {'name': 'payment_rounded', 'icon': Icons.payment_rounded},
  {'name': 'smartphone_rounded', 'icon': Icons.smartphone_rounded},
  {'name': 'computer_rounded', 'icon': Icons.computer_rounded},
  {'name': 'storefront_rounded', 'icon': Icons.storefront_rounded},
  {'name': 'more_horiz_rounded', 'icon': Icons.more_horiz_rounded},
];

const List<Color> _availablePaymentColors = [
  Colors.green,
  Colors.indigo,
  Colors.orange,
  Colors.brown,
  Colors.deepPurpleAccent,
  Colors.pinkAccent,
  Colors.redAccent,
  Colors.amber,
  Colors.blue,
  Colors.teal,
  Colors.grey,
];

IconData getPaymentIconByName(String name) {
  switch (name) {
    case 'attach_money_rounded': return Icons.attach_money_rounded;
    case 'account_balance_rounded': return Icons.account_balance_rounded;
    case 'credit_card_rounded': return Icons.credit_card_rounded;
    case 'account_balance_wallet_rounded': return Icons.account_balance_wallet_rounded;
    case 'language_rounded': return Icons.language_rounded;
    case 'smartphone_rounded': return Icons.smartphone_rounded;
    case 'computer_rounded': return Icons.computer_rounded;
    case 'storefront_rounded': return Icons.storefront_rounded;
    case 'payment_rounded': return Icons.payment_rounded;
    default: return Icons.more_horiz_rounded;
  }
}

// ==================== CONTROLLER ====================

class PaymentModeController extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  List<Map<String, dynamic>> _paymentModes = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get paymentModes => _paymentModes;
  bool get isLoading => _isLoading;

  PaymentModeController() {
    _loadPaymentModes();
  }

  Future<void> _loadPaymentModes() async {
    final list = await _cacheService.getPaymentModes();
    _paymentModes = list;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPaymentMode(String label, String iconName, int colorValue) async {
    final updated = List<Map<String, dynamic>>.from(_paymentModes);
    updated.add({
      'label': label,
      'icon': iconName,
      'color': colorValue,
      'count': 0,
    });
    await _cacheService.savePaymentModes(updated);
    _paymentModes = updated;
    notifyListeners();
  }
}

// ==================== SCREEN ====================

class PaymentModeScreen extends StatefulWidget {
  const PaymentModeScreen({super.key});

  @override
  State<PaymentModeScreen> createState() => _PaymentModeScreenState();
}

class _PaymentModeScreenState extends State<PaymentModeScreen> {
  late final PaymentModeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaymentModeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleShowAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPaymentModeSheet(onAdd: _controller.addPaymentMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Payment Modes',
      showBackButton: true,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 80,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleShowAddSheet,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      children: [
        const VGapMd(),
        _buildSectionLabel(),
        const VGapMd(),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildPaymentModeBody(),
        ),
      ],
    );
  }

  Widget _buildSectionLabel() {
    return Text(
      'Manage payment modes & usage frequency'.toUpperCase(),
      style: AppTheme.bodySmall.copyWith(
        color: AppTheme.textSecondaryColor(context),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildPaymentModeBody() {
    if (_controller.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }
    if (_controller.paymentModes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No payment modes defined.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor(context)),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _controller.paymentModes.length,
      itemBuilder: (context, index) => _PaymentModeItem(
        data: _controller.paymentModes[index],
      ),
    );
  }
}

// ==================== LIST ITEM ====================

class _PaymentModeItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PaymentModeItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final String label = data['label'] as String? ?? 'Other';
    final String iconName = data['icon'] as String? ?? 'more_horiz_rounded';
    final int colorVal = data['color'] as int? ?? Colors.grey.toARGB32();
    final int count = data['count'] as int? ?? 0;
    final Color color = Color(colorVal);
    final IconData icon = getPaymentIconByName(iconName);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          _buildIconBadge(icon, color),
          const HGapMd(),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildUsageBadge(context, count),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildUsageBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleFillColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count usages',
        style: TextStyle(
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ==================== ADD SHEET ====================

class _AddPaymentModeSheet extends StatefulWidget {
  final Future<void> Function(String label, String iconName, int colorValue) onAdd;

  const _AddPaymentModeSheet({required this.onAdd});

  @override
  State<_AddPaymentModeSheet> createState() => _AddPaymentModeSheetState();
}

class _AddPaymentModeSheetState extends State<_AddPaymentModeSheet> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _handleClose() => Navigator.pop(context);

  void _handleIconSelected(int index) {
    setState(() {
      _selectedIconIndex = index;
    });
  }

  void _handleColorSelected(int index) {
    setState(() {
      _selectedColorIndex = index;
    });
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final iconName = _availablePaymentIcons[_selectedIconIndex]['name'] as String;
    final colorVal = _availablePaymentColors[_selectedColorIndex].toARGB32();

    widget.onAdd(name, iconName, colorVal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.borderColor(context), width: 1),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const VGapLg(),
              _buildNameInput(),
              const VGapLg(),
              _buildIconSelector(),
              const VGapLg(),
              _buildColorSelector(),
              const VGapXl(),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Add Payment Mode',
          style: AppTheme.headingMedium.copyWith(fontSize: 20),
        ),
        IconButton(
          onPressed: _handleClose,
          icon: Icon(Icons.close, color: AppTheme.textSecondaryColor(context)),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Mode Name'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'e.g. HDFC Debit Card',
            hintStyle: TextStyle(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: AppTheme.surface(context).withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Icon'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_availablePaymentIcons.length, (index) {
            final item = _availablePaymentIcons[index];
            final IconData icon = item['icon'] as IconData;
            final isSelected = _selectedIconIndex == index;

            return GestureDetector(
              onTap: () => _handleIconSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.subtleFillColor(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Color'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_availablePaymentColors.length, (index) {
            final Color color = _availablePaymentColors[index];
            final isSelected = _selectedColorIndex == index;

            return GestureDetector(
              onTap: () => _handleColorSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Add Payment Mode',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
