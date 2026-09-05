import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_premium_fab.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import 'add_budget_screen.dart';
import 'expense_category_screen.dart';
import 'payment_mode_screen.dart';

class ManageBudgetScreen extends StatefulWidget {
  const ManageBudgetScreen({super.key});

  @override
  State<ManageBudgetScreen> createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  final BudgetService _budgetService = BudgetService();

  String _formatInr(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      title: 'Manage Budgets',
      showBackButton: true,
      floatingActionButton: AppPremiumFab(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
          );
        },
      ),
      children: [
        const VGapSm(),
        // Quick Links for Categories & Payment Modes
        Row(
          children: [
            Expanded(
              child: _buildQuickLinkCard(
                icon: Icons.category_rounded,
                title: 'Categories',
                subtitle: 'Manage tags',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExpenseCategoryScreen()),
                  );
                },
              ),
            ),
            const HGapMd(),
            Expanded(
              child: _buildQuickLinkCard(
                icon: Icons.payment_rounded,
                title: 'Payment Modes',
                subtitle: 'UPI, Cash, Cards',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentModeScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const VGapLg(),
        Text(
          'ALL BUDGETS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapSm(),
        StreamBuilder<List<Budget>>(
          stream: _budgetService.getBudgetsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final budgets = snapshot.data ?? [];
            if (budgets.isEmpty) {
              return AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Budgets',
                message: 'You have not added any budgets yet.',
                actionLabel: 'Create One',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
                  );
                },
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final b = budgets[index];
                return _buildBudgetItemCard(b);
              },
            );
          },
        ),
        const VGapBottomNav(),
      ],
    );
  }

  Widget _buildQuickLinkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryLight, size: 20),
            ),
            const HGapSm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItemCard(Budget b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: b.isActive ? AppTheme.primaryColor.withValues(alpha: 0.6) : AppTheme.borderColor(context),
          width: b.isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${b.categoryName} • ${b.period.toUpperCase()}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: b.isActive,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (val) => _budgetService.toggleBudget(b.id, val),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limit', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
                  Text(
                    _formatInr(b.limit),
                    style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryLight),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddBudgetScreen(existingBudget: b)),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface(context),
                          title: const Text('Delete Budget'),
                          content: Text('Delete "${b.name}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await _budgetService.deleteBudget(b.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
