import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/log_service.dart';
import 'app_spacers.dart';
import 'app_toast.dart';

class CalorieLogSheet extends StatefulWidget {
  const CalorieLogSheet({super.key});

  @override
  State<CalorieLogSheet> createState() => _CalorieLogSheetState();
}

class _CalorieLogSheetState extends State<CalorieLogSheet> {
  final LogService _logService = LogService();
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  String _selectedMeal = 'Snack';
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  bool _isSaving = false;

  @override
  void dispose() {
    _foodController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final food = _foodController.text.trim();
    final calVal = int.tryParse(_caloriesController.text) ?? 0;
    if (food.isEmpty || calVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter food name and valid calories.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _logService.createEntry(
        'Logged $_selectedMeal: $food',
        'Logged $calVal kcal of $food for $_selectedMeal.',
        '🍎',
        ['Diet', _selectedMeal],
      );
      if (mounted) {
        Navigator.pop(context);
        AppToast.show(
          context: context,
          message: 'Logged $calVal kcal diet entry successfully!',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log calorie entry: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VGapMd(),
            Text('Log Calories 🍎', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
            const VGapMd(),
            Text('Food Name', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
            const VGapSm(),
            TextField(
              controller: _foodController,
              style: AppTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'e.g. Banana, Chicken Salad',
              ),
            ),
            const VGapMd(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calories (kcal)', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      const VGapSm(),
                      TextField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        style: AppTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 350',
                        ),
                      ),
                    ],
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meal Type', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      const VGapSm(),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMeal,
                        dropdownColor: AppTheme.surfaceColor,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _mealTypes.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m, style: AppTheme.bodyLarge));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMeal = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const VGapLg(),
            SizedBox(
              width: double.infinity,
              height: AppTheme.buttonHeight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log Calorie Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
