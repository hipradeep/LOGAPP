import 'package:flutter/foundation.dart';
import '../models/diet_item.dart';

class DietController extends ChangeNotifier {
  final List<DietItem> _dietItems = [
    DietItem(foodName: 'Oatmeal with Berries', calories: 350, mealType: 'Breakfast'),
    DietItem(foodName: 'Grilled Chicken Salad', calories: 450, mealType: 'Lunch'),
    DietItem(foodName: 'Protein Shake', calories: 200, mealType: 'Snack'),
  ];

  bool _isLoading = false;
  String? _errorMessage;

  List<DietItem> get dietItems => _dietItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalCalories {
    return _dietItems.fold(0, (sum, item) => sum + item.calories);
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    // Simulate network fetch
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;
    notifyListeners();
  }

  void addDietItem(DietItem item) {
    _dietItems.add(item);
    notifyListeners();
  }

  void removeDietItem(int index) {
    if (index >= 0 && index < _dietItems.length) {
      _dietItems.removeAt(index);
      notifyListeners();
    }
  }
}
