import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/water_log_controller.dart';
import 'app_spacers.dart';
import 'glass_modal_sheet.dart';
import 'app_toast.dart';
import '../services/water_service.dart';
import '../services/service_locator.dart';

class WaterLogSheet extends StatefulWidget {
  const WaterLogSheet({super.key});

  @override
  State<WaterLogSheet> createState() => _WaterLogSheetState();
}

class _WaterLogSheetState extends State<WaterLogSheet> {
  double _selectedAmount = 250.0;
  late final WaterLogController _controller;

  final List<Map<String, dynamic>> _cups = [
    {'amount': 100.0, 'label': '100 ml', 'icon': Icons.local_cafe_outlined, 'color': Colors.amber.shade300},
    {'amount': 250.0, 'label': '250 ml', 'icon': Icons.local_drink_outlined, 'color': Colors.blue.shade300},
    {'amount': 300.0, 'label': '300 ml', 'icon': Icons.water_drop_rounded, 'color': Colors.cyan.shade300},
    {'amount': 500.0, 'label': '500 ml', 'icon': Icons.water_drop_outlined, 'color': Colors.teal.shade300},
  ];

  @override
  void initState() {
    super.initState();
    _controller = WaterLogController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final todayTotal = _controller.todayTotal;
        final dailyGoal = _controller.settings.dailyGoal;
        final progress = _controller.todayProgress;
        final remaining = dailyGoal - todayTotal;

        return GlassModalSheet(
          title: 'Log Water Intake',
          subtitle: 'Add to your daily hydration progress',
          children: [
            _SheetProgressRing(
              progress: progress,
              todayTotal: todayTotal,
              remaining: remaining,
            ),
            const VGapLg(),
            _SheetCupSelector(
              selectedAmount: _selectedAmount,
              cups: _cups,
              onAmountSelected: (amount) {
                setState(() {
                  _selectedAmount = amount;
                });
              },
            ),
            const VGapLg(),
            // Log button
            ElevatedButton(
              onPressed: () async {
                try {
                  final waterService = getIt<WaterService>();
                  await waterService.addWaterLog(_selectedAmount);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  AppToast.show(
                    context: context,
                    message: 'Logged ${_selectedAmount.toInt()} ml water! 💧',
                    backgroundColor: AppTheme.successColor,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  AppToast.show(
                    context: context,
                    message: 'Failed to log water: $e',
                    backgroundColor: AppTheme.errorColor,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Text(
                'Log ${_selectedAmount.toInt()} ml',
                style: AppTheme.headingSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const VGapMd(),
          ],
        );
      },
    );
  }
}

class _SheetProgressRing extends StatelessWidget {
  final double progress;
  final double todayTotal;
  final double remaining;

  const _SheetProgressRing({
    required this.progress,
    required this.todayTotal,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surface(context).withValues(alpha: 0.15),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle ring
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.borderColor(context).withValues(alpha: 0.2),
                  width: 8,
                ),
              ),
            ),
            // Circular Progress Indicator
            SizedBox(
              width: 124,
              height: 124,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.transparent,
                color: Colors.blue.shade400,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Text inside the circle
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTheme.headingMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${todayTotal.toInt()} ml',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining > 0 ? '-${remaining.toInt()} ml' : 'Goal met',
                  style: AppTheme.bodySmall.copyWith(
                    color: remaining > 0
                        ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.6)
                        : AppTheme.successColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetCupSelector extends StatelessWidget {
  final double selectedAmount;
  final List<Map<String, dynamic>> cups;
  final ValueChanged<double> onAmountSelected;

  const _SheetCupSelector({
    required this.selectedAmount,
    required this.cups,
    required this.onAmountSelected,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Cup Capacity',
            style: AppTheme.headingSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        const VGapMd(),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cups.length,
            itemBuilder: (context, index) {
              final cup = cups[index];
              final amount = cup['amount'] as double;
              final isSelected = selectedAmount == amount;
              final color = cup['color'] as Color;

              return GestureDetector(
                onTap: () => onAmountSelected(amount),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.teal.shade50.withValues(alpha: AppTheme.isDarkMode(context) ? 0.08 : 0.7)
                        : AppTheme.surface(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.teal.shade400
                          : AppTheme.borderColor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cup['icon'] as IconData,
                        color: isSelected ? Colors.teal.shade400 : color,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cup['label'] as String,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.teal.shade400
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
