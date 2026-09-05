import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_action_buttons.dart';
import '../services/preferences_service.dart';

const List<Map<String, dynamic>> _availableIcons = [
  {'name': 'local_grocery_store_rounded', 'icon': Icons.local_grocery_store_rounded},
  {'name': 'fastfood_rounded', 'icon': Icons.fastfood_rounded},
  {'name': 'restaurant_rounded', 'icon': Icons.restaurant_rounded},
  {'name': 'local_bar_rounded', 'icon': Icons.local_bar_rounded},
  {'name': 'flight_rounded', 'icon': Icons.flight_rounded},
  {'name': 'directions_car_rounded', 'icon': Icons.directions_car_rounded},
  {'name': 'receipt_long_rounded', 'icon': Icons.receipt_long_rounded},
  {'name': 'home_rounded', 'icon': Icons.home_rounded},
  {'name': 'shopping_bag_rounded', 'icon': Icons.shopping_bag_rounded},
  {'name': 'medication_rounded', 'icon': Icons.medication_rounded},
  {'name': 'medical_services_rounded', 'icon': Icons.medical_services_rounded},
  {'name': 'sports_esports_rounded', 'icon': Icons.sports_esports_rounded},
  {'name': 'school_rounded', 'icon': Icons.school_rounded},
  {'name': 'favorite_rounded', 'icon': Icons.favorite_rounded},
];

const List<Color> _availableColors = [
  Colors.green,
  Colors.orange,
  Colors.indigo,
  Colors.teal,
  Colors.deepPurple,
  Colors.pinkAccent,
  Colors.redAccent,
  Colors.amber,
  Colors.blue,
  Colors.blueGrey,
];

IconData getCategoryIcon(String name) {
  for (var i in _availableIcons) {
    if (i['name'] == name) return i['icon'] as IconData;
  }
  return Icons.category_rounded;
}

class ExpenseCategoryScreen extends StatefulWidget {
  const ExpenseCategoryScreen({super.key});

  @override
  State<ExpenseCategoryScreen> createState() => _ExpenseCategoryScreenState();
}

class _ExpenseCategoryScreenState extends State<ExpenseCategoryScreen> {
  final PreferencesService _prefs = PreferencesService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _prefs.getExpenseCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    }
  }

  void _showAddCategorySheet() {
    final labelController = TextEditingController();
    String selectedIcon = _availableIcons.first['name'] as String;
    Color selectedColor = _availableColors.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Expense Category', style: AppTheme.headingSmall),
              const VGapMd(),
              TextField(
                controller: labelController,
                style: AppTheme.bodyLarge,
                decoration: const InputDecoration(hintText: 'Category Name (e.g. Gym, Pet Care)'),
              ),
              const VGapLg(),
              Text('Select Icon', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              const VGapSm(),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableIcons.length,
                  separatorBuilder: (_, __) => const HGapSm(),
                  itemBuilder: (context, i) {
                    final item = _availableIcons[i];
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final isSel = selectedIcon == name;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedIcon = name),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryColor.withValues(alpha: 0.25) : AppTheme.background(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? AppTheme.primaryColor : AppTheme.borderColor(context),
                          ),
                        ),
                        child: Icon(icon, color: isSel ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context)),
                      ),
                    );
                  },
                ),
              ),
              const VGapLg(),
              Text('Select Color', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
              const VGapSm(),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableColors.length,
                  separatorBuilder: (_, __) => const HGapSm(),
                  itemBuilder: (context, i) {
                    final color = _availableColors[i];
                    final isSel = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VGapXl(),
              AppActionButtons(
                primaryLabel: 'Add Category',
                onPrimaryPressed: () async {
                  final text = labelController.text.trim();
                  if (text.isEmpty) return;
                  final updated = List<Map<String, dynamic>>.from(_categories);
                  updated.add({
                    'label': text,
                    'icon': selectedIcon,
                    'color': selectedColor.toARGB32(),
                    'count': 0,
                  });
                  await _prefs.saveExpenseCategories(updated);
                  setState(() => _categories = updated);
                  if (mounted) Navigator.pop(ctx);
                },
                cancelLabel: 'Cancel',
                onCancelPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteCategory(int index) async {
    final updated = List<Map<String, dynamic>>.from(_categories)..removeAt(index);
    await _prefs.saveExpenseCategories(updated);
    setState(() => _categories = updated);
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      title: 'Expense Categories',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: _showAddCategorySheet,
        ),
      ],
      children: [
        const VGapSm(),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final label = cat['label'] as String;
              final iconName = cat['icon'] as String? ?? 'category';
              final color = Color(cat['color'] as int? ?? 0xFF8B5CF6);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(getCategoryIcon(iconName), color: color, size: 20),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.errorColor),
                      onPressed: () => _deleteCategory(index),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
