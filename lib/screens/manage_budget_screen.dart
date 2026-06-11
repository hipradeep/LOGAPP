import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../models/budget_item.dart';
import '../services/budget_service.dart';
import 'add_budget_screen.dart';

class ManageBudgetScreen extends StatefulWidget {
  const ManageBudgetScreen({super.key});

  @override
  State<ManageBudgetScreen> createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  final BudgetService _budgetService = BudgetService();

  void _navigateToAddBudget() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddBudgetScreen(),
      ),
    );
  }

  void _navigateToEditBudget(BudgetItem budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBudgetScreen(
          existingBudget: budget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsStream = _budgetService.getBudgetsStream();

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
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
      backgroundWidgets: const [
        GlowBlob(
          top: -40,
          left: -40,
          size: 240,
          color: AppTheme.primaryColor,
          opacity: 0.1,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 280,
          color: AppTheme.secondaryColor,
          opacity: 0.05,
        ),
      ],
      children: [
        Padding(
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
        ),
        const VGapMd(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: StreamBuilder<List<BudgetItem>>(
            stream: budgetsStream,
            builder: (context, budgetsSnapshot) {
              if (budgetsSnapshot.connectionState == ConnectionState.waiting && !budgetsSnapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                );
              }

              final budgets = budgetsSnapshot.data ?? [];
              return _buildContentBody(budgets);
            },
          ),
        ),
        const VGapXxl(),
        const VGapXxl(),
      ],
    );
  }

  Widget _buildContentBody(List<BudgetItem> budgets) {
    if (budgets.isEmpty) {
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

    final active = budgets.where((b) => b.checked).toList();
    final completed = budgets.where((b) => !b.checked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('Active Budgets (${active.length})', AppTheme.primaryColor),
          const VGapSm(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: active.length,
            itemBuilder: (context, index) {
              final budget = active[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBudgetCard(budget),
              );
            },
          ),
          const VGapMd(),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionHeader('Completed Budgets (${completed.length})', AppTheme.successColor),
          const VGapSm(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completed.length,
            itemBuilder: (context, index) {
              final budget = completed[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBudgetCard(budget),
              );
            },
          ),
          const VGapMd(),
        ],
      ],
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

  Widget _buildBudgetCard(BudgetItem budget) {
    final isActive = budget.checked;
    final isOver = budget.isOverBudget;
    final percent = budget.limit > 0 ? (budget.spentForCurrentPeriod / budget.limit).clamp(0.0, 1.0) : 0.0;
    
    final Color accentColor = !isActive
        ? AppTheme.successColor
        : (isOver 
            ? AppTheme.errorColor 
            : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor));

    final String periodLabel = budget.period.toUpperCase();
    final Color periodColor = budget.period == 'weekly' ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () => _navigateToEditBudget(budget),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
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
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Stack(
            children: [
              // Whole card background progress bar (light color representing spending)
              if (percent > 0 && isActive)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent,
                    child: Container(
                      color: accentColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              IntrinsicHeight(
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
                            Row(
                              children: [
                                // Budget Status Icon
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
                                    budget.category,
                                    style: AppTheme.bodyLarge.copyWith(
                                      color: isActive ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      decoration: !isActive ? TextDecoration.lineThrough : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const HGapSm(),
                                // Period Badge
                                Container(
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
                                ),
                              ],
                            ),
                            const VGapSm(),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Limit and Spent chip
                                _buildMetaChip(
                                  icon: Icons.attach_money_rounded,
                                  label: 'Spent: ₹${budget.spentForCurrentPeriod.toStringAsFixed(0)} / ₹${budget.limit.toStringAsFixed(0)}',
                                  color: !isActive
                                      ? AppTheme.textSecondary
                                      : (isOver ? AppTheme.errorColor : AppTheme.successColor),
                                ),
                                // Scheduled Time Reminder
                                if (budget.scheduledTime != null)
                                  _buildMetaChip(
                                    icon: Icons.access_time_rounded,
                                    label: _formatScheduledTime(budget.scheduledTime!),
                                    color: AppTheme.primaryLight,
                                  ),
                                // Repeat days tag (if fewer than 7 days)
                                if (budget.repeatDays.isNotEmpty && budget.repeatDays.length < 7)
                                  _buildMetaChip(
                                    icon: Icons.calendar_view_week_rounded,
                                    label: _getRepeatDaysLabel(budget.repeatDays),
                                    color: AppTheme.textSecondary,
                                  ),
                                // Date range
                                if (budget.startDate != null && budget.endDate != null)
                                  _buildMetaChip(
                                    icon: Icons.date_range_rounded,
                                    label: '${DateFormat('MMM d').format(budget.startDate!)} - ${DateFormat('MMM d').format(budget.endDate!)}',
                                    color: AppTheme.textSecondary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          const SizedBox(width: 4),
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
