import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_title_input.dart';
import '../controllers/manage_budget2_controller.dart';

class ManageBudget2Screen extends StatefulWidget {
  const ManageBudget2Screen({super.key});

  @override
  State<ManageBudget2Screen> createState() => _ManageBudget2ScreenState();
}

class _ManageBudget2ScreenState extends State<ManageBudget2Screen>
    with SingleTickerProviderStateMixin {
  late final ManageBudget2Controller _c;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  // Step 1 controllers
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Step 2
  final _salaryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = ManageBudget2Controller();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _anim.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _animateTo(VoidCallback fn) {
    _anim.reverse().then((_) {
      fn();
      _anim.forward();
    });
  }

  Future<void> _handleSave() async {
    final ok = await _c.save();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Budget created successfully!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${_c.error}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return FullScreenPage(
          showScaffold: true,
          title: 'Manage Budget 2',
          showBackButton: true,
          actions: [
            if (_c.step == 3)
              _c.isSaving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
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
            GlowBlob(top: -30, right: -30, size: 200, color: AppTheme.primaryColor, opacity: 0.12),
            GlowBlob(bottom: 40, left: -40, size: 220, color: AppTheme.secondaryColor, opacity: 0.09),
          ],
          children: [
            const VGapSm(),
            _StepIndicator(current: _c.step),
            const VGapLg(),
            FadeTransition(
              opacity: _fade,
              child: _buildStepContent(),
            ),
            const VGapLg(),
            _buildBottomBar(),
            const VGapBottomNav(),
          ],
        );
      },
    );
  }

  Widget _buildStepContent() {
    return switch (_c.step) {
      1 => _Step1Form(
          c: _c,
          nameCtrl: _nameCtrl,
          amountCtrl: _amountCtrl,
          descCtrl: _descCtrl,
        ),
      2 => _Step2Salary(c: _c, salaryCtrl: _salaryCtrl),
      _ => _Step3Allocations(c: _c),
    };
  }

  Widget _buildBottomBar() {
    if (_c.step == 3) return const SizedBox.shrink();
    return Row(
      children: [
        if (_c.step > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: () => _animateTo(_c.prevStep),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.borderColor(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Back',
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
          ),
        if (_c.step > 1) const HGapMd(),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _c.canGoNext
                ? () => _animateTo(_c.nextStep)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _c.step == 2 ? 'Next — Allocations' : 'Next — Salary',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP INDICATOR
// ══════════════════════════════════════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Details', 'Salary', 'Allocations'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final idx = i + 1;
        final isDone = idx < current;
        final isActive = idx == current;
        final color = isActive
            ? AppTheme.primaryColor
            : isDone
                ? AppTheme.successColor
                : AppTheme.borderColor(context);
        final textColor = (isActive || isDone)
            ? Colors.white
            : AppTheme.textSecondaryColor(context);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 6)]
                            : [],
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                            : Text(
                                '$idx',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                        color: isActive
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: isDone ? AppTheme.successColor : AppTheme.borderColor(context),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 1 — Budget Details
// ══════════════════════════════════════════════════════════════════════════════
class _Step1Form extends StatelessWidget {
  final ManageBudget2Controller c;
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController descCtrl;

  const _Step1Form({
    required this.c,
    required this.nameCtrl,
    required this.amountCtrl,
    required this.descCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTitleInput(
          controller: nameCtrl,
          label: 'Budget Name',
          hintText: 'e.g. June Monthly Budget',
          icon: Icons.bookmark_rounded,
          onChanged: c.updateBudgetName,
        ),
        const VGapMd(),
        AppTitleInput(
          controller: amountCtrl,
          label: 'Budget Amount (₹)',
          hintText: 'e.g. 40,000',
          icon: Icons.currency_rupee_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final val = double.tryParse(v.replaceAll(',', '').trim());
            if (val != null) c.updateAmount(val);
          },
        ),
        const VGapMd(),
        // Category Dropdown
        _DropdownField(
          label: 'BUDGET CATEGORY',
          value: c.category,
          items: ManageBudget2Controller.categories,
          onChanged: c.updateCategory,
        ),
        const VGapMd(),
        // Threshold Slider
        _ThresholdSlider(value: c.threshold, onChanged: c.updateThreshold),
        const VGapMd(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Icon(Icons.notes_rounded, color: AppTheme.primaryLight, size: 20),
              ),
              const HGapMd(),
              Expanded(
                child: TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Notes about this budget...',
                    hintStyle: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 14),
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12),
                  ),
                  onChanged: c.updateDescription,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.category_rounded, color: AppTheme.primaryLight, size: 20),
          const HGapMd(),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppTheme.surface(context),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) { if (v != null) onChanged(v); },
                hint: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ThresholdSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
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
            children: [
              Text(
                'ALERT THRESHOLD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              thumbColor: AppTheme.primaryColor,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value,
              min: 0.5,
              max: 1.0,
              divisions: 10,
              onChanged: onChanged,
            ),
          ),
          Text(
            'Alert when $pct% of budget is spent',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 2 — Salary & Division
// ══════════════════════════════════════════════════════════════════════════════
class _Step2Salary extends StatelessWidget {
  final ManageBudget2Controller c;
  final TextEditingController salaryCtrl;

  const _Step2Salary({required this.c, required this.salaryCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTitleInput(
          controller: salaryCtrl,
          label: 'Monthly Salary (₹)',
          hintText: 'e.g. 50,000',
          icon: Icons.currency_rupee_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            final val = double.tryParse(v.replaceAll(',', '').trim());
            if (val != null) c.updateSalary(val);
          },
        ),
        const VGapLg(),
        _DivisionCard(c: c),
      ],
    );
  }
}

class _DivisionCard extends StatelessWidget {
  final ManageBudget2Controller c;
  const _DivisionCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final needsPct = (c.needsRatio * 100).round();
    final wantsPct = (c.wantsRatio * 100).round();
    final savPct = (c.savingsRatio * 100).round();

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
          Text(
            'SALARY DIVISION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapMd(),
          // Visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  _BarSeg(flex: needsPct.clamp(1, 100), label: 'Needs ($needsPct%)', amt: currency.format(c.needsAmount), color: AppTheme.primaryColor),
                  Container(width: 2, height: 48, color: AppTheme.surface(context)),
                  _BarSeg(flex: wantsPct.clamp(1, 100), label: 'Wants ($wantsPct%)', amt: currency.format(c.wantsAmount), color: AppTheme.secondaryColor),
                  Container(width: 2, height: 48, color: AppTheme.surface(context)),
                  _BarSeg(flex: savPct.clamp(1, 100), label: 'Savings ($savPct%)', amt: currency.format(c.savingsAmount), color: AppTheme.successColor),
                ],
              ),
            ),
          ),
          const VGapLg(),
          // Sliders (long-press to unlock)
          _DivSlider(label: 'Needs', value: c.needsRatio, color: AppTheme.primaryColor, onChanged: c.updateNeedsRatio),
          const VGapSm(),
          _DivSlider(label: 'Wants', value: c.wantsRatio, color: AppTheme.secondaryColor, onChanged: c.updateWantsRatio),
          const VGapSm(),
          _DivSlider(label: 'Savings', value: c.savingsRatio, color: AppTheme.successColor, onChanged: c.updateSavingsRatio),
        ],
      ),
    );
  }
}

class _BarSeg extends StatelessWidget {
  final int flex;
  final String label;
  final String amt;
  final Color color;
  const _BarSeg({required this.flex, required this.label, required this.amt, required this.color});

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
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)))),
            FittedBox(fit: BoxFit.scaleDown, child: Text(amt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
      ),
    );
  }
}

class _DivSlider extends StatefulWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _DivSlider({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  State<_DivSlider> createState() => _DivSliderState();
}

class _DivSliderState extends State<_DivSlider> {
  bool _unlocked = false;
  Timer? _timer;

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() => _unlocked = true);
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _unlocked = false);
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _unlocked = false);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.value * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            widget.label,
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onLongPress: _onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _unlocked ? widget.color.withValues(alpha: 0.6) : Colors.transparent,
                ),
                color: _unlocked ? widget.color.withValues(alpha: 0.06) : Colors.transparent,
              ),
              child: AbsorbPointer(
                absorbing: !_unlocked,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: _unlocked ? widget.color : widget.color.withValues(alpha: 0.35),
                    inactiveTrackColor: widget.color.withValues(alpha: 0.15),
                    thumbColor: _unlocked ? widget.color : widget.color.withValues(alpha: 0.4),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    showValueIndicator: _unlocked ? ShowValueIndicator.always : ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: widget.value,
                    min: 0.05,
                    max: 0.90,
                    divisions: 17,
                    label: '$pct%',
                    onChanged: (v) { _resetTimer(); widget.onChanged(v); },
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: widget.color,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STEP 3 — Subcategory Allocations
// ══════════════════════════════════════════════════════════════════════════════
class _Step3Allocations extends StatelessWidget {
  final ManageBudget2Controller c;
  const _Step3Allocations({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AllocSection(
          title: 'NEEDS',
          categoryAmount: c.needsAmount,
          percentages: c.needsSubs,
          sumPercentage: c.needsSubSum,
          accentColor: AppTheme.primaryColor,
          iconMap: const {
            'Grocery': Icons.shopping_basket_rounded,
            'Bills': Icons.receipt_long_rounded,
            'Transport': Icons.directions_bus_rounded,
          },
          onSliderChanged: c.updateNeedsSub,
        ),
        const VGapLg(),
        _AllocSection(
          title: 'WANTS',
          categoryAmount: c.wantsAmount,
          percentages: c.wantsSubs,
          sumPercentage: c.wantsSubSum,
          accentColor: AppTheme.secondaryColor,
          iconMap: const {
            'Eating Out': Icons.restaurant_rounded,
            'Entertainment': Icons.movie_rounded,
            'Travel': Icons.flight_takeoff_rounded,
            'Hobbies': Icons.palette_rounded,
          },
          onSliderChanged: c.updateWantsSub,
        ),
        const VGapLg(),
        _AllocSection(
          title: 'SAVINGS',
          categoryAmount: c.savingsAmount,
          percentages: c.savingsSubs,
          sumPercentage: c.savingsSubSum,
          accentColor: AppTheme.successColor,
          iconMap: const {
            'Invest (Stocks & MF)': Icons.trending_up_rounded,
            'Fixed Deposit (FD)': Icons.account_balance_rounded,
            'Emergency Fund': Icons.shield_rounded,
          },
          onSliderChanged: c.updateSavingsSub,
        ),
      ],
    );
  }
}

class _AllocSection extends StatelessWidget {
  final String title;
  final double categoryAmount;
  final Map<String, double> percentages;
  final double sumPercentage;
  final Color accentColor;
  final Map<String, IconData> iconMap;
  final void Function(String, double) onSliderChanged;

  const _AllocSection({
    required this.title,
    required this.categoryAmount,
    required this.percentages,
    required this.sumPercentage,
    required this.accentColor,
    required this.iconMap,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isOver = sumPercentage > 100.1;
    final allocated = (sumPercentage / 100.0) * categoryAmount;

    final badgeBg = isOver ? AppTheme.errorColor.withValues(alpha: 0.15) : accentColor.withValues(alpha: 0.15);
    final badgeBorder = isOver ? AppTheme.errorColor : accentColor.withValues(alpha: 0.4);
    final badgeColor = isOver ? AppTheme.errorColor : accentColor;
    final badgeLabel = (sumPercentage - 100.0).abs() < 0.1
        ? currency.format(categoryAmount)
        : currency.format(allocated);

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
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppTheme.textSecondaryColor(context))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: badgeBorder)),
                child: Text(badgeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
              ),
            ],
          ),
          const VGapMd(),
          ...percentages.entries.map((e) {
            final pct = e.value;
            final subAmt = (pct / 100.0) * categoryAmount;
            return _AllocTile(
              key: ValueKey(e.key),
              name: e.key,
              icon: iconMap[e.key] ?? Icons.circle,
              percentage: pct,
              amount: subAmt,
              categoryAmount: categoryAmount,
              accentColor: accentColor,
              onSliderChanged: (v) => onSliderChanged(e.key, v),
            );
          }),
        ],
      ),
    );
  }
}

class _AllocTile extends StatefulWidget {
  final String name;
  final IconData icon;
  final double percentage;
  final double amount;
  final double categoryAmount;
  final Color accentColor;
  final ValueChanged<double> onSliderChanged;

  const _AllocTile({
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
  State<_AllocTile> createState() => _AllocTileState();
}

class _AllocTileState extends State<_AllocTile> {
  bool _unlocked = false;
  Timer? _timer;

  double _stepSize() {
    final t = widget.categoryAmount;
    if (t >= 5000) return 500;
    if (t >= 1000) return 100;
    return 50;
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() => _unlocked = true);
    _timer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _unlocked = false); });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () { if (mounted) setState(() => _unlocked = false); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final max = widget.categoryAmount > 0 ? widget.categoryAmount : 100.0;
    final step = _stepSize();
    final divs = (max / step).round().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.accentColor),
              const HGapSm(),
              Expanded(child: Text(widget.name, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text(currency.format(widget.amount), style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor(context))),
            ],
          ),
          GestureDetector(
            onLongPress: _onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _unlocked ? widget.accentColor.withValues(alpha: 0.6) : Colors.transparent),
                color: _unlocked ? widget.accentColor.withValues(alpha: 0.06) : Colors.transparent,
              ),
              child: AbsorbPointer(
                absorbing: !_unlocked,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    activeTrackColor: _unlocked ? widget.accentColor : widget.accentColor.withValues(alpha: 0.35),
                    inactiveTrackColor: widget.accentColor.withValues(alpha: 0.15),
                    thumbColor: _unlocked ? widget.accentColor : widget.accentColor.withValues(alpha: 0.4),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    showValueIndicator: _unlocked ? ShowValueIndicator.always : ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: widget.amount.clamp(0, max),
                    min: 0,
                    max: max,
                    divisions: divs,
                    label: currency.format(widget.amount),
                    onChanged: (v) {
                      _resetTimer();
                      final snapped = (v / step).round() * step;
                      final clamped = snapped.clamp(0.0, widget.categoryAmount);
                      final pct = widget.categoryAmount > 0 ? (clamped / widget.categoryAmount) * 100 : 0.0;
                      widget.onSliderChanged(pct);
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
