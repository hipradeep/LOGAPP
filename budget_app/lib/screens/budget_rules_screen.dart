import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../controllers/manage_budget1_controller.dart';

class BudgetRulesScreen extends StatefulWidget {
  final ManageBudget1Controller controller;

  const BudgetRulesScreen({
    super.key,
    required this.controller,
  });

  @override
  State<BudgetRulesScreen> createState() => _BudgetRulesScreenState();
}

class _BudgetRulesScreenState extends State<BudgetRulesScreen> {
  void _applyRule(String ruleId) {
    widget.controller.applyAndSaveRule(ruleId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activated "${widget.controller.activeRule.title}": Existing budget reorganized.'),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmAndApplyRule(PresetRuleInfo rule) {
    if (widget.controller.selectedRuleId == rule.id) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: AppTheme.primaryAccentColor(context),
                size: 20,
              ),
            ),
            const HGapSm(),
            Expanded(
              child: Text(
                'Reorganize Budget?',
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switching to "${rule.title}" will reorganize and divide your existing monthly budget according to this rule\'s ratio.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor(context),
                height: 1.4,
              ),
            ),
            const VGapMd(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryAccentColor(context),
                    size: 18,
                  ),
                  const HGapSm(),
                  Expanded(
                    child: Text(
                      'All current expense limits and savings goals will automatically adjust to match ${rule.title}.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimaryColor(context),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _applyRule(rule.id);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Apply',
              style: TextStyle(
                color: AppTheme.primaryAccentColor(context),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndDeleteRule(PresetRuleInfo rule) {
    final isCurrentlyUsed = widget.controller.isRuleInUse(rule);

    if (isCurrentlyUsed) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            side: BorderSide(color: AppTheme.borderColor(context)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  'Rule Is In Use',
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This rule "${rule.title}" is currently active and used in your monthly budget.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const VGapMd(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.warningColor,
                      size: 18,
                    ),
                    const HGapSm(),
                    Expanded(
                      child: Text(
                        'You cannot delete an active rule. Please switch your budget to a different rule first before deleting this one.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  color: AppTheme.primaryAccentColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Rule is NOT in use: show standard delete confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.errorColor,
                size: 20,
              ),
            ),
            const HGapSm(),
            Expanded(
              child: Text(
                'Delete Custom Rule?',
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${rule.title}"? This custom rule will be permanently removed.',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.controller.deleteCustomRule(rule.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted custom rule "${rule.title}".'),
                    backgroundColor: AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateCustomRuleModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateCustomRuleModal(
        onSave: (rule) async {
          await widget.controller.addCustomRule(rule);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved custom rule "${rule.title}"'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _openInfoDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: EdgeInsets.only(
          top: MediaQuery.paddingOf(ctx).top + 52,
          right: 16,
          left: 40,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const _HowBudgetRulesWorkDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeId = widget.controller.selectedRuleId;
        final customRules = widget.controller.customRules;

        return FullScreenPage(
          showScaffold: true,
          title: 'Budget Rules Guide',
          showBackButton: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.info_outline_rounded,
                color: AppTheme.textPrimaryColor(context),
                size: 22,
              ),
              tooltip: 'How Budget Rules Work',
              onPressed: _openInfoDialog,
            ),
          ],
          backgroundWidgets: [
            GlowBlob(
              top: -30,
              right: -30,
              size: 200,
              color: AppTheme.primaryColor,
              opacity: 0.10,
            ),
            GlowBlob(
              bottom: 40,
              left: -40,
              size: 220,
              color: AppTheme.secondaryColor,
              opacity: 0.08,
            ),
          ],
          children: [
            const VGapSm(),
            _buildSectionHeader(context, 'PRESET BUDGETING FRAMEWORKS'),
            const VGapSm(),
            ...ManageBudget1Controller.rules.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RuleCard(
                  rule: r,
                  isSelected: activeId == r.id,
                  onApply: () => _confirmAndApplyRule(r),
                ),
              ),
            ),
            const VGapMd(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(context, 'CUSTOM RULES'),
                OutlinedButton.icon(
                  onPressed: _openCreateCustomRuleModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Add Rule',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryAccentColor(context),
                    side: BorderSide(
                      color: AppTheme.borderColor(context),
                      width: 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const VGapSm(),
            if (customRules.isEmpty)
              _buildEmptyCustomRulesCard(context)
            else
              ...customRules.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RuleCard(
                    rule: r,
                    isSelected: activeId == r.id,
                    onApply: () => _confirmAndApplyRule(r),
                    onDelete: () => _confirmAndDeleteRule(r),
                  ),
                ),
              ),
            const VGapXl(),
          ],
        );
      },
    );
  }


  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: AppTheme.textSecondaryColor(context),
      ),
    );
  }

  Widget _buildEmptyCustomRulesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 36, color: AppTheme.textSecondaryColor(context)),
          const VGapSm(),
          Text(
            'No Custom Rules Yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapXs(),
          Text(
            'Create tailored ratios like 60/40 or 40/40/20 to suit your exact financial goals.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== RULE CARD ====================
class _RuleCard extends StatelessWidget {
  final PresetRuleInfo rule;
  final bool isSelected;
  final VoidCallback onApply;
  final VoidCallback? onDelete;

  const _RuleCard({
    required this.rule,
    required this.isSelected,
    required this.onApply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isThreeWay = rule.needsRatio != null && rule.wantsRatio != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onApply,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: AppTheme.isDarkMode(context) ? 0.12 : 0.08)
                : AppTheme.surface(context).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        rule.title,
                        style: AppTheme.headingSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      if (isSelected) ...[
                        const HGapSm(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryColor, width: 0.8),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAccentColor(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onDelete != null) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: AppTheme.errorColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Delete Rule',
                          onPressed: onDelete,
                        ),
                        const HGapXs(),
                      ],
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
              const VGapSm(),
              Text(
                rule.description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  height: 1.35,
                ),
              ),
              const VGapMd(),
              // Ratio Bar Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 28,
                  child: Row(
                    children: isThreeWay
                        ? [
                            Expanded(
                              flex: ((rule.needsRatio ?? 0.5) * 100).toInt(),
                              child: Container(
                                color: AppTheme.primaryColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Needs',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            Container(width: 1.5, color: AppTheme.surface(context)),
                            Expanded(
                              flex: ((rule.wantsRatio ?? 0.3) * 100).toInt(),
                              child: Container(
                                color: AppTheme.secondaryColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Wants',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            Container(width: 1.5, color: AppTheme.surface(context)),
                            Expanded(
                              flex: (rule.savingsRatio * 100).toInt(),
                              child: Container(
                                color: AppTheme.successColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Savings',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              flex: (rule.expenseRatio * 100).toInt(),
                              child: Container(
                                color: AppTheme.primaryColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Expenses',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            Container(width: 1.5, color: AppTheme.surface(context)),
                            Expanded(
                              flex: (rule.savingsRatio * 100).toInt(),
                              child: Container(
                                color: AppTheme.successColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Savings',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
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
    );
  }
}

// ==================== CREATE CUSTOM RULE MODAL ====================
class _CreateCustomRuleModal extends StatefulWidget {
  final Future<void> Function(PresetRuleInfo) onSave;

  const _CreateCustomRuleModal({required this.onSave});

  @override
  State<_CreateCustomRuleModal> createState() => _CreateCustomRuleModalState();
}

class _CreateCustomRuleModalState extends State<_CreateCustomRuleModal> {
  final TextEditingController _nameController = TextEditingController();
  bool _isThreeWay = false;
  bool _isCustomNameEdited = false;

  // 2-Way split default (60 / 40)
  double _expRatio = 60.0;
  double _savRatio = 40.0;

  // 3-Way split default (50 / 30 / 20)
  double _needsRatio = 45.0;
  double _wantsRatio = 35.0;
  double _savRatio3 = 20.0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = '60 / 40 Rule';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _currentSum => _isThreeWay
      ? (_needsRatio + _wantsRatio + _savRatio3)
      : (_expRatio + _savRatio);

  bool get _isValidSum => (_currentSum - 100.0).abs() < 0.5;

  void _handleSave() async {
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a rule name'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_isValidSum) return;

    setState(() => _isSaving = true);

    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final PresetRuleInfo rule;

    if (_isThreeWay) {
      rule = PresetRuleInfo(
        id: id,
        title: title,
        description: '${_needsRatio.toInt()}% Needs + ${_wantsRatio.toInt()}% Wants | ${_savRatio3.toInt()}% Savings',
        expenseRatio: (_needsRatio + _wantsRatio) / 100.0,
        savingsRatio: _savRatio3 / 100.0,
        needsRatio: _needsRatio / 100.0,
        wantsRatio: _wantsRatio / 100.0,
        isCustom: true,
      );
    } else {
      rule = PresetRuleInfo(
        id: id,
        title: title,
        description: '${_expRatio.toInt()}% Expenses | ${_savRatio.toInt()}% Savings',
        expenseRatio: _expRatio / 100.0,
        savingsRatio: _savRatio / 100.0,
        isCustom: true,
      );
    }

    try {
      await widget.onSave(rule);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rule: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VGapMd(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Custom Rule',
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const VGapSm(),
            // Rule Name
            TextField(
              controller: _nameController,
              onChanged: (val) {
                setState(() {
                  _isCustomNameEdited = val.trim().isNotEmpty;
                });
              },
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'RULE NAME',
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondaryColor(context),
                ),
                hintText: 'e.g. 60 / 40 Rule or My Plan',
                hintStyle: TextStyle(color: AppTheme.hintColor(context)),
                filled: true,
                fillColor: AppTheme.surface(context).withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
            const VGapMd(),
            // Split Type Toggle
            Text(
              'SPLIT STRUCTURE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const VGapXs(),
            Row(
              children: [
                Expanded(
                  child: _SegmentToggle(
                    label: '2-Way (Expenses & Savings)',
                    isSelected: !_isThreeWay,
                    onTap: () {
                      setState(() {
                        _isThreeWay = false;
                        _nameController.text = '${_expRatio.toInt()} / ${_savRatio.toInt()} Rule';
                      });
                    },
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: _SegmentToggle(
                    label: '3-Way (Needs, Wants, Sav)',
                    isSelected: _isThreeWay,
                    onTap: () {
                      setState(() {
                        _isThreeWay = true;
                        _nameController.text = '${_needsRatio.toInt()} / ${_wantsRatio.toInt()} / ${_savRatio3.toInt()} Rule';
                      });
                    },
                  ),
                ),
              ],
            ),
            const VGapMd(),
            if (!_isThreeWay) ...[
              _buildSliderRow(
                label: 'Expenses: ${_expRatio.toInt()}%',
                value: _expRatio,
                color: AppTheme.primaryColor,
                onChanged: (val) {
                  setState(() {
                    _expRatio = val.roundToDouble().clamp(0.0, 100.0);
                    _savRatio = 100.0 - _expRatio;
                    if (!_isCustomNameEdited) {
                      _nameController.text = '${_expRatio.toInt()} / ${_savRatio.toInt()} Rule';
                    }
                  });
                },
              ),
              const VGapSm(),
              _buildSliderRow(
                label: 'Savings: ${_savRatio.toInt()}%',
                value: _savRatio,
                color: AppTheme.successColor,
                onChanged: (val) {
                  setState(() {
                    _savRatio = val.roundToDouble().clamp(0.0, 100.0);
                    _expRatio = 100.0 - _savRatio;
                    if (!_isCustomNameEdited) {
                      _nameController.text = '${_expRatio.toInt()} / ${_savRatio.toInt()} Rule';
                    }
                  });
                },
              ),
            ] else ...[
              _buildSliderRow(
                label: 'Needs: ${_needsRatio.toInt()}%',
                value: _needsRatio,
                color: AppTheme.primaryColor,
                onChanged: (val) {
                  setState(() {
                    _needsRatio = val.roundToDouble().clamp(0.0, 100.0);
                    final remaining = 100.0 - _needsRatio;
                    if (_wantsRatio > remaining) {
                      _wantsRatio = remaining;
                      _savRatio3 = 0.0;
                    } else {
                      _savRatio3 = remaining - _wantsRatio;
                    }
                    if (!_isCustomNameEdited) {
                      _nameController.text = '${_needsRatio.toInt()} / ${_wantsRatio.toInt()} / ${_savRatio3.toInt()} Rule';
                    }
                  });
                },
              ),
              const VGapSm(),
              _buildSliderRow(
                label: 'Wants: ${_wantsRatio.toInt()}%',
                value: _wantsRatio,
                color: AppTheme.secondaryColor,
                onChanged: (val) {
                  setState(() {
                    final maxWants = 100.0 - _needsRatio;
                    _wantsRatio = val.roundToDouble().clamp(0.0, maxWants);
                    _savRatio3 = (100.0 - _needsRatio - _wantsRatio).clamp(0.0, 100.0);
                    if (!_isCustomNameEdited) {
                      _nameController.text = '${_needsRatio.toInt()} / ${_wantsRatio.toInt()} / ${_savRatio3.toInt()} Rule';
                    }
                  });
                },
              ),
              const VGapSm(),
              _buildSliderRow(
                label: 'Savings: ${_savRatio3.toInt()}%',
                value: _savRatio3,
                color: AppTheme.successColor,
                onChanged: (val) {
                  setState(() {
                    final maxSav = 100.0 - _needsRatio;
                    _savRatio3 = val.roundToDouble().clamp(0.0, maxSav);
                    _wantsRatio = (100.0 - _needsRatio - _savRatio3).clamp(0.0, 100.0);
                    if (!_isCustomNameEdited) {
                      _nameController.text = '${_needsRatio.toInt()} / ${_wantsRatio.toInt()} / ${_savRatio3.toInt()} Rule';
                    }
                  });
                },
              ),
            ],
            const VGapMd(),
            // Live Ratio Bar Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: _isThreeWay
                      ? [
                          Expanded(
                            flex: _needsRatio.toInt().clamp(1, 100),
                            child: Container(
                              color: AppTheme.primaryColor,
                              alignment: Alignment.center,
                              child: Text('Needs ${_needsRatio.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          Container(width: 1.5, color: AppTheme.surface(context)),
                          Expanded(
                            flex: _wantsRatio.toInt().clamp(1, 100),
                            child: Container(
                              color: AppTheme.secondaryColor,
                              alignment: Alignment.center,
                              child: Text('Wants ${_wantsRatio.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          Container(width: 1.5, color: AppTheme.surface(context)),
                          Expanded(
                            flex: _savRatio3.toInt().clamp(1, 100),
                            child: Container(
                              color: AppTheme.successColor,
                              alignment: Alignment.center,
                              child: Text('Sav ${_savRatio3.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            flex: _expRatio.toInt().clamp(1, 100),
                            child: Container(
                              color: AppTheme.primaryColor,
                              alignment: Alignment.center,
                              child: Text('Expenses ${_expRatio.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          Container(width: 1.5, color: AppTheme.surface(context)),
                          Expanded(
                            flex: _savRatio.toInt().clamp(1, 100),
                            child: Container(
                              color: AppTheme.successColor,
                              alignment: Alignment.center,
                              child: Text('Savings ${_savRatio.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                ),
              ),
            ),
            const VGapMd(),
            // Validation indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Allocation:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isValidSum ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isValidSum ? AppTheme.successColor : AppTheme.errorColor, width: 0.8),
                  ),
                  child: Text(
                    '${_currentSum.toInt()}% / 100%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isValidSum ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
            const VGapLg(),
            ElevatedButton(
              onPressed: _isValidSum && _nameController.text.trim().isNotEmpty && !_isSaving ? _handleSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(0.0, 100.0),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SegmentToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: AppTheme.isDarkMode(context) ? 0.2 : 0.12)
              : AppTheme.surface(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

// ==================== HOW BUDGET RULES WORK DIALOG ====================
class _HowBudgetRulesWorkDialog extends StatelessWidget {
  const _HowBudgetRulesWorkDialog();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryAccentColor(context),
                  size: 20,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  'How Budget Rules Work',
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.textSecondaryColor(context),
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const VGapMd(),
          Text(
            'Budgeting frameworks automatically allocate your monthly salary into specific buckets to keep your finances balanced and intentional:',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondaryColor(context),
              height: 1.4,
            ),
          ),
          const VGapMd(),
          _buildPillarRow(
            context,
            color: AppTheme.primaryColor,
            title: 'Needs',
            desc: 'Essentials like rent, bills, groceries & health.',
          ),
          const VGapSm(),
          _buildPillarRow(
            context,
            color: AppTheme.secondaryColor,
            title: 'Wants',
            desc: 'Lifestyle choices like dining out, entertainment & shopping.',
          ),
          const VGapSm(),
          _buildPillarRow(
            context,
            color: AppTheme.successColor,
            title: 'Savings',
            desc: 'Investments, fixed deposits & emergency reserves.',
          ),
          const VGapMd(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '💡 Tip: Pick a preset rule or create a custom ratio that fits your personal goals.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textPrimaryColor(context),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(
    BuildContext context, {
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const HGapSm(),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

