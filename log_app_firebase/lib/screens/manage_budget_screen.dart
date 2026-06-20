import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_popup_menu_button.dart';
import '../models/budget.dart';
import '../controllers/budget_controller.dart';
import 'add_budget_screen.dart';
import 'expense_category_screen.dart';
import 'payment_mode_screen.dart';

class ManageBudgetScreen extends StatefulWidget {
  const ManageBudgetScreen({super.key});

  @override
  State<ManageBudgetScreen> createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  late final BudgetController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BudgetController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToAddBudget() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
    );
  }

  void _navigateToEditBudget(Budget budget) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddBudgetScreen(existingBudget: budget)),
    );
  }

  void _navigateToExpenseCategory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpenseCategoryScreen()),
    );
  }

  void _navigateToPaymentMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentModeScreen()),
    );
  }

  void _handleMenuSelection(String value) {
    if (value == 'expense_category') {
      _navigateToExpenseCategory();
    } else if (value == 'payment_mode') {
      _navigateToPaymentMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Manage Budget',
      showBackButton: true,
      padding: EdgeInsets.zero,
      actions: [
        GestureDetector(
          onTap: _navigateToAddBudget,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.subtleFillColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add,
              color: AppTheme.textPrimaryColor(context),
              size: 20,
            ),
          ),
        ),
        const HGapSm(),
        AppPopupMenuButton(
          onSelected: _handleMenuSelection,
          itemBuilder: _buildMenuItems,
        ),
      ],

      children: [
        const VGapMd(),
        _buildSectionLabel(),
        const VGapMd(),
        _buildStreamContent(),
        const VGapXxl(),
        const VGapXxl(),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      PopupMenuItem(
        value: 'expense_category',
        child: Row(
          children: [
            Icon(Icons.category_rounded, color: AppTheme.primaryAccentColor(context), size: 18),
            const HGapSm(),
            Text(
              'Expense Category',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'payment_mode',
        child: Row(
          children: [
            Icon(Icons.payment_rounded, color: AppTheme.primaryAccentColor(context), size: 18),
            const HGapSm(),
            Text(
              'Payment Mode',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Active budget categories and limits'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            );
          }
          return _buildContentBody();
        },
      ),
    );
  }

  Widget _buildContentBody() {
    final budgets = _controller.budgets;
    final transactions = _controller.transactions;

    if (budgets.isEmpty) {
      return _buildEmptyState();
    }

    final active = budgets.where((b) => b.isActive).toList();
    final completed = budgets.where((b) => !b.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('Active Budgets (${active.length})', AppTheme.primaryColor),
          const VGapSm(),
          _buildBudgetList(active, transactions),
          const VGapMd(),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionHeader('Completed Budgets (${completed.length})', AppTheme.successColor),
          const VGapSm(),
          _buildBudgetList(completed, transactions),
          const VGapMd(),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const VGapMd(),
            Text(
              'No Budget Limits Added',
              style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const VGapSm(),
            const Text(
              'Tap the (+) button at the top to create a budget category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetList(List<Budget> budgets, List<Transaction> transactions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _BudgetCard(
            budget: budget,
            transactions: transactions,
            onTap: _navigateToEditBudget,
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const HGapSm(),
          Text(
            title.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== BUDGET CARD ====================

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final List<Transaction> transactions;
  final ValueChanged<Budget> onTap;

  const _BudgetCard({
    required this.budget,
    required this.transactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = budget.isActive;
    final isOver = budget.isOverBudget(transactions);
    final spent = budget.spentForCurrentPeriod(transactions);
    final percent = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final Color accentColor = _resolveAccentColor(isActive, isOver, percent);

    return GestureDetector(
      onTap: () => onTap(budget),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: _buildCardDecoration(isActive, isOver, accentColor),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Stack(
            children: [
              if (percent > 0 && isActive) _buildProgressFill(percent, accentColor),
              _buildCardContent(context, isActive, isOver, accentColor, spent, percent),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveAccentColor(bool isActive, bool isOver, double percent) {
    if (!isActive) return AppTheme.successColor;
    if (isOver) return AppTheme.errorColor;
    if (percent >= 0.7) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  BoxDecoration _buildCardDecoration(bool isActive, bool isOver, Color accentColor) {
    return BoxDecoration(
      color: !isActive
          ? AppTheme.successColor.withValues(alpha: 0.03)
          : (isOver
              ? AppTheme.errorColor.withValues(alpha: 0.06)
              : AppTheme.primaryColor.withValues(alpha: 0.06)),
      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
      border: Border.all(
        color: accentColor.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  Widget _buildProgressFill(double percent, Color accentColor) {
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percent,
        child: Container(
          color: accentColor.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, bool isActive, bool isOver, Color accentColor, double spent, double percent) {
    final String periodLabel = budget.period.toUpperCase();
    final Color periodColor = budget.period == 'weekly' ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.defaultBorderRadius),
                bottomLeft: Radius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(context, isActive, isOver, accentColor, periodLabel, periodColor),
                  const VGapSm(),
                  _buildMetaChips(isActive, isOver, spent, accentColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isActive, bool isOver, Color accentColor, String periodLabel, Color periodColor) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
          ),
          child: Icon(
            !isActive
                ? Icons.check_rounded
                : (isOver ? Icons.warning_rounded : Icons.check_circle_outline_rounded),
            size: 14,
            color: Colors.white,
          ),
        ),
        const HGapMd(),
        Expanded(
          child: Text(
            '${budget.name} (${budget.categoryName})',
            style: AppTheme.bodyLarge.copyWith(
              color: isActive
                  ? AppTheme.textPrimaryColor(context)
                  : AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.w600,
              decoration: !isActive ? TextDecoration.lineThrough : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const HGapSm(),
        _buildPeriodBadge(periodLabel, periodColor),
      ],
    );
  }

  Widget _buildPeriodBadge(String periodLabel, Color periodColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: periodColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: periodColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        periodLabel,
        style: TextStyle(
          color: periodColor.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetaChips(bool isActive, bool isOver, double spent, Color accentColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildMetaChip(
          icon: Icons.attach_money_rounded,
          label: 'Spent: ₹${spent.toStringAsFixed(0)} / ₹${budget.limit.toStringAsFixed(0)}',
          color: !isActive
              ? AppTheme.textSecondary
              : (isOver ? AppTheme.errorColor : AppTheme.successColor),
        ),
        if (budget.scheduledTime != null)
          _buildMetaChip(
            icon: Icons.access_time_rounded,
            label: _formatScheduledTime(budget.scheduledTime!),
            color: AppTheme.primaryLight,
          ),
        if (budget.startDate != null && budget.endDate != null)
          _buildMetaChip(
            icon: Icons.date_range_rounded,
            label: '${DateFormat('MMM d').format(budget.startDate!)} - ${DateFormat('MMM d').format(budget.endDate!)}',
            color: AppTheme.textSecondary,
          ),
      ],
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const HGapXs(),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element — kept for future use when repeatDays chip is re-enabled
  String _getRepeatDaysLabel(List<int> days) {
    const dayLabelsShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekends';
    return days.map((d) => dayLabelsShort[d - 1][0]).join(', ');
  }

  String _formatScheduledTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final t = TimeOfDay(hour: hour, minute: minute);
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
