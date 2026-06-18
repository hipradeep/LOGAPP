import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../services/cache_service.dart';

// ==================== ICON/COLOR CONSTANTS ====================

const List<Map<String, dynamic>> _availableIcons = [
  {'name': 'flight_rounded', 'icon': Icons.flight_rounded},
  {'name': 'fastfood_rounded', 'icon': Icons.fastfood_rounded},
  {'name': 'local_cafe_rounded', 'icon': Icons.local_cafe_rounded},
  {'name': 'local_grocery_store_rounded', 'icon': Icons.local_grocery_store_rounded},
  {'name': 'storefront_rounded', 'icon': Icons.storefront_rounded},
  {'name': 'shopping_bag_rounded', 'icon': Icons.shopping_bag_rounded},
  {'name': 'receipt_long_rounded', 'icon': Icons.receipt_long_rounded},
  {'name': 'dinner_dining_rounded', 'icon': Icons.dinner_dining_rounded},
  {'name': 'local_gas_station_rounded', 'icon': Icons.local_gas_station_rounded},
  {'name': 'medical_services_rounded', 'icon': Icons.medical_services_rounded},
  {'name': 'school_rounded', 'icon': Icons.school_rounded},
  {'name': 'sports_esports_rounded', 'icon': Icons.sports_esports_rounded},
  {'name': 'pets_rounded', 'icon': Icons.pets_rounded},
  {'name': 'home_rounded', 'icon': Icons.home_rounded},
  {'name': 'directions_car_rounded', 'icon': Icons.directions_car_rounded},
];

const List<Color> _availableColors = [
  Colors.indigo,
  Colors.orange,
  Colors.brown,
  Colors.green,
  Colors.deepPurpleAccent,
  Colors.pinkAccent,
  Colors.redAccent,
  Colors.amber,
  Colors.blue,
  Colors.teal,
  Colors.grey,
];

IconData getIconDataByName(String name) {
  switch (name) {
    case 'flight_rounded': return Icons.flight_rounded;
    case 'fastfood_rounded': return Icons.fastfood_rounded;
    case 'local_cafe_rounded': return Icons.local_cafe_rounded;
    case 'local_grocery_store_rounded': return Icons.local_grocery_store_rounded;
    case 'storefront_rounded': return Icons.storefront_rounded;
    case 'shopping_bag_rounded': return Icons.shopping_bag_rounded;
    case 'receipt_long_rounded': return Icons.receipt_long_rounded;
    case 'dinner_dining_rounded': return Icons.dinner_dining_rounded;
    case 'local_gas_station_rounded': return Icons.local_gas_station_rounded;
    case 'medical_services_rounded': return Icons.medical_services_rounded;
    case 'school_rounded': return Icons.school_rounded;
    case 'sports_esports_rounded': return Icons.sports_esports_rounded;
    case 'pets_rounded': return Icons.pets_rounded;
    case 'home_rounded': return Icons.home_rounded;
    case 'directions_car_rounded': return Icons.directions_car_rounded;
    default: return Icons.more_horiz_rounded;
  }
}

// ==================== CONTROLLER ====================

class ExpenseCategoryController extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;

  ExpenseCategoryController() {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await _cacheService.getExpenseCategories();
    _categories = list;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String label, String iconName, int colorValue) async {
    final updated = List<Map<String, dynamic>>.from(_categories);
    updated.add({
      'label': label,
      'icon': iconName,
      'color': colorValue,
      'count': 0,
    });
    await _cacheService.saveExpenseCategories(updated);
    _categories = updated;
    notifyListeners();
  }
}

// ==================== SCREEN ====================

class ExpenseCategoryScreen extends StatefulWidget {
  const ExpenseCategoryScreen({super.key});

  @override
  State<ExpenseCategoryScreen> createState() => _ExpenseCategoryScreenState();
}

class _ExpenseCategoryScreenState extends State<ExpenseCategoryScreen> {
  late final ExpenseCategoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExpenseCategoryController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleShowAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCategorySheet(onAdd: _controller.addCategory),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Expense Categories',
      showBackButton: true,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 80,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleShowAddSheet,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      children: [
        const VGapMd(),
        _buildSectionLabel(),
        const VGapMd(),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildCategoryBody(),
        ),
      ],
    );
  }

  Widget _buildSectionLabel() {
    return Text(
      'Manage transaction tags & usage frequency'.toUpperCase(),
      style: AppTheme.bodySmall.copyWith(
        color: AppTheme.textSecondaryColor(context),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildCategoryBody() {
    if (_controller.isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }
    if (_controller.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No categories defined.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor(context)),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _controller.categories.length,
      itemBuilder: (context, index) => _CategoryItem(
        data: _controller.categories[index],
      ),
    );
  }
}

// ==================== CATEGORY LIST ITEM ====================

class _CategoryItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CategoryItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final String label = data['label'] as String? ?? 'Other';
    final String iconName = data['icon'] as String? ?? 'more_horiz_rounded';
    final int colorVal = data['color'] as int? ?? Colors.grey.toARGB32();
    final int count = data['count'] as int? ?? 0;
    final Color color = Color(colorVal);
    final IconData icon = getIconDataByName(iconName);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          _buildIconBadge(icon, color),
          const HGapMd(),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildUsageBadge(context, count),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildUsageBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleFillColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count usages',
        style: TextStyle(
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ==================== ADD CATEGORY BOTTOM SHEET ====================

class _AddCategorySheet extends StatefulWidget {
  final Future<void> Function(String label, String iconName, int colorValue) onAdd;

  const _AddCategorySheet({required this.onAdd});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _handleClose() => Navigator.pop(context);

  void _handleIconSelected(int index) {
    setState(() {
      _selectedIconIndex = index;
    });
  }

  void _handleColorSelected(int index) {
    setState(() {
      _selectedColorIndex = index;
    });
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final iconName = _availableIcons[_selectedIconIndex]['name'] as String;
    final colorVal = _availableColors[_selectedColorIndex].toARGB32();

    widget.onAdd(name, iconName, colorVal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.borderColor(context), width: 1),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const VGapLg(),
              _buildNameInput(),
              const VGapLg(),
              _buildIconSelector(),
              const VGapLg(),
              _buildColorSelector(),
              const VGapXl(),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Add Category',
          style: AppTheme.headingMedium.copyWith(fontSize: 20),
        ),
        IconButton(
          onPressed: _handleClose,
          icon: Icon(Icons.close, color: AppTheme.textSecondaryColor(context)),
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Name'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'e.g. Subscriptions',
            hintStyle: TextStyle(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: AppTheme.surface(context).withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Icon'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_availableIcons.length, (index) {
            final item = _availableIcons[index];
            final IconData icon = item['icon'] as IconData;
            final isSelected = _selectedIconIndex == index;

            return GestureDetector(
              onTap: () => _handleIconSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.subtleFillColor(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Color'.toUpperCase(),
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const VGapSm(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_availableColors.length, (index) {
            final Color color = _availableColors[index];
            final isSelected = _selectedColorIndex == index;

            return GestureDetector(
              onTap: () => _handleColorSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Add Category',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
