import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

import '../models/diet_item.dart';
import '../controllers/diet_controller.dart';
import 'base_management_tab.dart';

class DietTab extends StatefulWidget {
  const DietTab({super.key});

  @override
  State<DietTab> createState() => _DietTabState();
}

class _DietTabState extends State<DietTab> {
  late DietController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DietController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<DietController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.dietItems.isEmpty,
      emptyIcon: Icons.restaurant_menu,
      emptyMessage: 'No diet logs added today.',
      onRefresh: () async => await _controller.refresh(),
      onFabPressed: _showAddDietDialog,
      builder: (context, controller) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Diet & Nutrition Log', style: AppTheme.headingSmall),
              ],
            ),
            const VGapSm(),
            Card(
              color: AppTheme.surfaceColor.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daily Calorie Intake', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${controller.totalCalories} kcal', style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryLight)),
                  ],
                ),
              ),
            ),
            const VGapSm(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.dietItems.length,
              itemBuilder: (context, index) {
                final meal = controller.dietItems[index];
                return Card(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    dense: true,
                    title: Text(meal.foodName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text(meal.mealType, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${meal.calories} kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const HGapSm(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 18),
                          onPressed: () {
                            controller.removeDietItem(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        );
      },
    );
  }

  void _showAddDietDialog() {
    final foodController = TextEditingController();
    final caloriesController = TextEditingController();
    String selectedMealType = 'Breakfast';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Log Food Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: foodController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Apple, Chicken Breast',
                      labelText: 'Food Name',
                    ),
                  ),
                  const VGapSm(),
                  TextField(
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Calories in kcal',
                      labelText: 'Calories',
                    ),
                  ),
                  const VGapSm(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Meal Type:', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        dropdownColor: AppTheme.surfaceColor,
                        value: selectedMealType,
                        items: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedMealType = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    final cal = int.tryParse(caloriesController.text) ?? 0;
                    if (foodController.text.isNotEmpty && cal > 0) {
                      _controller.addDietItem(DietItem(
                        foodName: foodController.text,
                        calories: cal,
                        mealType: selectedMealType,
                      ));
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Log', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

}
