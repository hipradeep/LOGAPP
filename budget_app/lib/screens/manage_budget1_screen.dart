import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_title_input.dart';
import '../controllers/manage_budget1_controller.dart';
import 'budget_rules_screen.dart';

class ManageBudget1Screen extends StatefulWidget {
  const ManageBudget1Screen({super.key});

  @override
  State<ManageBudget1Screen> createState() => _ManageBudget1ScreenState();
}

class _ManageBudget1ScreenState extends State<ManageBudget1Screen> {
  late final ManageBudget1Controller _controller;
  late final TextEditingController _salaryInputController;
  final TextEditingController _budgetNameController = TextEditingController();
  final FocusNode _salaryFocus = FocusNode();
  bool _isUserTyping = false;

  @override
  void initState() {
    super.initState();
    _controller = ManageBudget1Controller();
    _salaryInputController = TextEditingController(
      text: _controller.salary.toStringAsFixed(0),
    );
    _budgetNameController.text = _controller.budgetName;
    _controller.addListener(_syncSalaryText);
  }

  void _syncSalaryText() {
    if (_isUserTyping || _salaryFocus.hasFocus) return;
    final modelSalary = _controller.salary.toStringAsFixed(0);
    if (_salaryInputController.text != modelSalary && !_controller.isLoading) {
      _salaryInputController.text = modelSalary;
      _salaryInputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _salaryInputController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSalaryText);
    _controller.dispose();
    _salaryInputController.dispose();
    _budgetNameController.dispose();
    _salaryFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final success = await _controller.saveBudgetPlan();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Budget plan activated successfully!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save budget: ${_controller.errorMessage}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: _controller.startDate,
        end: _controller.endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surface(context),
              onSurface: AppTheme.textPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _controller.updateDateRange(picked.start, picked.end);
    }
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return FullScreenPage(
          showScaffold: true,
          title: 'Manage Budget 1',
          showBackButton: true,
          actions: [
            if (_controller.isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _handleSave,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: AppTheme.primaryAccentColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
          backgroundWidgets: [
            GlowBlob(
              top: -30,
              right: -30,
              size: 200,
              color: AppTheme.primaryColor,
              opacity: 0.12,
            ),
            GlowBlob(
              bottom: 40,
              left: -40,
              size: 220,
              color: AppTheme.secondaryColor,
              opacity: 0.09,
            ),
          ],
          children: [
            const VGapSm(),
            // Budget Name
            AppTitleInput(
              controller: _budgetNameController,
              label: 'Budget Name',
              hintText: 'e.g. My Monthly Budget',
              icon: Icons.bookmark_rounded,
              onChanged: _controller.updateBudgetName,
            ),
            // Compact date row — small, sits right below name
            _CompactDateRow(
              startDate: _controller.startDate,
              endDate: _controller.endDate,
              onTap: _selectDateRange,
            ),
            const VGapMd(),
            _SalaryInputField(
              salaryController: _salaryInputController,
              focusNode: _salaryFocus,
              onSalaryChanged: (val) {
                _isUserTyping = true;
                final amount = double.tryParse(val.replaceAll(',', '').trim());
                if (amount != null && amount >= 0) {
                  _controller.updateSalary(amount);
                }
                _isUserTyping = false;
              },
            ),
            const VGapMd(),
            _SalaryDivisionCard(
              controller: _controller,
            ),
            const VGapLg(),
            if (_controller.isThreeWaySplit) ...[
              _SubCategorySection(
                title: 'NEEDS',
                categoryAmount: _controller.needsAmount,
                percentages: _controller.needsSubPercentages,
                sumPercentage: _controller.needsSubPercentageSum,
                accentColor: AppTheme.primaryColor,
                iconMap: const {
                  'Grocery': Icons.shopping_basket_rounded,
                  'Bills': Icons.receipt_long_rounded,
                  'Transport': Icons.directions_bus_rounded,
                },
                onSliderChanged: (name, val) =>
                    _controller.updateNeedsSubPercentage(name, val),
              ),
              const VGapLg(),
              _SubCategorySection(
                title: 'WANTS',
                categoryAmount: _controller.wantsAmount,
                percentages: _controller.wantsSubPercentages,
                sumPercentage: _controller.wantsSubPercentageSum,
                accentColor: AppTheme.secondaryColor,
                iconMap: const {
                  'Eating Out': Icons.restaurant_rounded,
                  'Entertainment': Icons.movie_rounded,
                  'Travel': Icons.flight_takeoff_rounded,
                  'Hobbies': Icons.palette_rounded,
                },
                onSliderChanged: (name, val) =>
                    _controller.updateWantsSubPercentage(name, val),
              ),
            ] else ...[
              _SubCategorySection(
                title: 'EXPENSES',
                categoryAmount: _controller.expenseAmount,
                percentages: _controller.expenseSubPercentages,
                sumPercentage: _controller.expenseSubPercentageSum,
                accentColor: AppTheme.primaryColor,
                iconMap: const {
                  'Grocery': Icons.shopping_basket_rounded,
                  'Bills': Icons.receipt_long_rounded,
                  'Travel': Icons.directions_car_rounded,
                  'Dining': Icons.restaurant_rounded,
                  'Shopping': Icons.local_mall_rounded,
                },
                onSliderChanged: (name, val) =>
                    _controller.updateExpenseSubPercentage(name, val),
              ),
            ],
            const VGapLg(),
            _SubCategorySection(
              title: 'SAVINGS',
              categoryAmount: _controller.savingsAmount,
              percentages: _controller.savingsSubPercentages,
              sumPercentage: _controller.savingsSubPercentageSum,
              accentColor: AppTheme.successColor,
              iconMap: const {
                'Invest (Stocks & MF)': Icons.trending_up_rounded,
                'Fixed Deposit (FD)': Icons.account_balance_rounded,
                'Emergency Fund': Icons.shield_rounded,
              },
              onSliderChanged: (name, val) =>
                  _controller.updateSavingsSubPercentage(name, val),
            ),
            const VGapBottomNav(),
          ],
        );
      },
    );
  }
}

// ==================== COMPACT DATE ROW ====================
class _CompactDateRow extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onTap;

  const _CompactDateRow({
    required this.startDate,
    required this.endDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    final label = '${fmt.format(startDate)} – ${fmt.format(endDate)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 13, color: AppTheme.textSecondaryColor(context)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded,
                size: 11, color: AppTheme.primaryLight),
          ],
        ),
      ),
    );
  }
}

// ==================== SALARY INPUT ====================
class _SalaryInputField extends StatelessWidget {
  final TextEditingController salaryController;
  final FocusNode? focusNode;
  final ValueChanged<String> onSalaryChanged;

  const _SalaryInputField({
    required this.salaryController,
    this.focusNode,
    required this.onSalaryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppTitleInput(
      controller: salaryController,
      focusNode: focusNode,
      label: 'Salary (₹)',
      hintText: 'e.g. 50,000',
      icon: Icons.currency_rupee_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onSalaryChanged,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Please enter salary';
        }
        return null;
      },
    );
  }
}

// ==================== SALARY DIVISION CARD ====================
class _SalaryDivisionCard extends StatelessWidget {
  final ManageBudget1Controller controller;

  const _SalaryDivisionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isThreeWay = controller.isThreeWaySplit;
    final expRatio = controller.activeRule.expenseRatio;
    final savRatio = controller.activeRule.savingsRatio;
    final needsRatio = controller.activeRule.needsRatio ?? 0.50;
    final wantsRatio = controller.activeRule.wantsRatio ?? 0.30;
    final needsPct = (needsRatio * 100).toInt();
    final wantsPct = (wantsRatio * 100).toInt();
    final savPct = (savRatio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'SALARY DIVISION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              // Selected Rule with Edit Button navigating to Budget Rules Guide
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BudgetRulesScreen(controller: controller),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.borderColor(context).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rule: ',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          controller.activeRule.id.startsWith('custom')
                              ? controller.activeRule.title
                              : controller.activeRule.id,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const HGapXs(),
                        Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: AppTheme.primaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Row(
                children: isThreeWay
                    ? [
                        _RatioBarSegment(
                          flex: needsPct.clamp(1, 100),
                          title: 'Needs ($needsPct%)',
                          amount: currency.format(controller.needsAmount),
                          color: AppTheme.primaryColor,
                        ),
                        Container(
                          width: 2,
                          height: 48,
                          color: AppTheme.surface(context),
                        ),
                        _RatioBarSegment(
                          flex: wantsPct.clamp(1, 100),
                          title: 'Wants ($wantsPct%)',
                          amount: currency.format(controller.wantsAmount),
                          color: AppTheme.secondaryColor,
                        ),
                        Container(
                          width: 2,
                          height: 48,
                          color: AppTheme.surface(context),
                        ),
                        _RatioBarSegment(
                          flex: savPct.clamp(1, 100),
                          title: 'Savings ($savPct%)',
                          amount: currency.format(controller.savingsAmount),
                          color: AppTheme.successColor,
                        ),
                      ]
                    : [
                        _RatioBarSegment(
                          flex: (expRatio * 100).toInt().clamp(1, 100),
                          title: 'Expenses (${(expRatio * 100).toInt()}%)',
                          amount: currency.format(controller.expenseAmount),
                          color: AppTheme.primaryColor,
                        ),
                        Container(
                          width: 2,
                          height: 48,
                          color: AppTheme.surface(context),
                        ),
                        _RatioBarSegment(
                          flex: (savRatio * 100).toInt().clamp(1, 100),
                          title: 'Savings (${(savRatio * 100).toInt()}%)',
                          amount: currency.format(controller.savingsAmount),
                          color: AppTheme.successColor,
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioBarSegment extends StatelessWidget {
  final int flex;
  final String title;
  final String amount;
  final Color color;

  const _RatioBarSegment({
    required this.flex,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        color: color,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CATEGORY ALLOCATION SECTION ====================
class _SubCategorySection extends StatelessWidget {
  final String title;
  final double categoryAmount;
  final Map<String, double> percentages;
  final double sumPercentage;
  final Color accentColor;
  final Map<String, IconData> iconMap;
  final void Function(String, double) onSliderChanged;
  final VoidCallback? onAdjustPressed;

  const _SubCategorySection({
    required this.title,
    required this.categoryAmount,
    required this.percentages,
    required this.sumPercentage,
    required this.accentColor,
    required this.iconMap,
    required this.onSliderChanged,
    this.onAdjustPressed,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isOver100 = sumPercentage > 100.1;
    final totalAllocatedAmount = (sumPercentage / 100.0) * categoryAmount;

    final badgeBg = isOver100
        ? AppTheme.errorColor.withValues(alpha: 0.15)
        : accentColor.withValues(alpha: 0.15);
    final badgeBorder = isOver100
        ? AppTheme.errorColor
        : accentColor.withValues(alpha: 0.4);
    final badgeTextColor = isOver100 ? AppTheme.errorColor : accentColor;
    final badgeLabel = (sumPercentage - 100.0).abs() < 0.1
        ? currency.format(categoryAmount)
        : currency.format(totalAllocatedAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),
          ...percentages.entries.map((entry) {
            final subName = entry.key;
            final pct = entry.value;
            final subAmount = (pct / 100.0) * categoryAmount;
            final icon = iconMap[subName] ?? Icons.circle;

            return _SubCategoryTile(
              key: ValueKey(subName),
              name: subName,
              icon: icon,
              percentage: pct,
              amount: subAmount,
              categoryAmount: categoryAmount,
              accentColor: accentColor,
              onSliderChanged: (newVal) => onSliderChanged(subName, newVal),
            );
          }),
          const VGapSm(),
          _buildAdjustButton(context),
        ],
      ),
    );
  }

  Widget _buildAdjustButton(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onAdjustPressed ?? () {},
        icon: Icon(Icons.tune_rounded, size: 16, color: accentColor),
        label: Text(
          'Adjust',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: accentColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(
            color: accentColor.withValues(alpha: 0.5),
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _SubCategoryTile extends StatefulWidget {
  final String name;
  final IconData icon;
  final double percentage;
  final double amount;
  final double categoryAmount;
  final Color accentColor;
  final ValueChanged<double> onSliderChanged;

  const _SubCategoryTile({
    super.key,
    required this.name,
    required this.icon,
    required this.percentage,
    required this.amount,
    required this.categoryAmount,
    required this.accentColor,
    required this.onSliderChanged,
  });

  @override
  State<_SubCategoryTile> createState() => _SubCategoryTileState();
}

class _SubCategoryTileState extends State<_SubCategoryTile> {
  bool _isUnlocked = false;
  Timer? _lockTimer;

  double _getStepSize(double total) {
    if (total >= 5000) return 500.0;
    if (total >= 1000) return 100.0;
    return 50.0;
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    _lockTimer?.cancel();
    setState(() => _isUnlocked = true);
    // Auto-relock after 4 seconds of no interaction
    _lockTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isUnlocked = false);
    });
  }

  void _resetLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isUnlocked = false);
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final maxAmount = widget.categoryAmount > 0 ? widget.categoryAmount : 100.0;
    final stepSize = _getStepSize(widget.categoryAmount);
    final rawDivisions = (maxAmount / stepSize).round();
    final divisions = rawDivisions > 0 ? rawDivisions : 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.accentColor),
              const HGapSm(),
              Expanded(
                child: Text(
                  widget.name,
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                currency.format(widget.amount),
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          // GestureDetector sits OUTSIDE AbsorbPointer so it always
          // receives events. AbsorbPointer blocks Slider when locked.
          GestureDetector(
            onLongPress: _onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isUnlocked
                      ? widget.accentColor.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.0,
                ),
                color: _isUnlocked
                    ? widget.accentColor.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: AbsorbPointer(
                // Locked → block slider touches so GestureDetector
                // above can detect the long press without conflict.
                absorbing: !_isUnlocked,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: _isUnlocked
                        ? widget.accentColor
                        : widget.accentColor.withValues(alpha: 0.35),
                    inactiveTrackColor: widget.accentColor.withValues(alpha: 0.15),
                    thumbColor: _isUnlocked
                        ? widget.accentColor
                        : widget.accentColor.withValues(alpha: 0.4),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: _isUnlocked
                        ? const RoundSliderOverlayShape(overlayRadius: 14)
                        : const RoundSliderOverlayShape(overlayRadius: 0),
                    showValueIndicator: _isUnlocked
                        ? ShowValueIndicator.always
                        : ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: widget.amount.clamp(0.0, maxAmount),
                    min: 0.0,
                    max: maxAmount,
                    divisions: divisions,
                    label: currency.format(widget.amount),
                    onChanged: (newAmount) {
                      _resetLockTimer(); // reset auto-lock on each move
                      final snapped = (newAmount / stepSize).round() * stepSize;
                      final clamped = snapped.clamp(0.0, widget.categoryAmount);
                      final newPct = widget.categoryAmount > 0
                          ? (clamped / widget.categoryAmount) * 100.0
                          : 0.0;
                      widget.onSliderChanged(newPct);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
