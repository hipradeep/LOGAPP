import 'package:flutter/material.dart';

class CategoryVisuals {
  CategoryVisuals._();

  static IconData categoryIcon(String? name) {
    return switch (name?.toLowerCase()) {
      'food' => Icons.restaurant_rounded,
      'groceries' => Icons.shopping_basket_rounded,
      'transport' => Icons.directions_car_rounded,
      'shopping' => Icons.shopping_bag_rounded,
      'bills' => Icons.receipt_long_rounded,
      'entertainment' => Icons.movie_rounded,
      'health' => Icons.medical_services_rounded,
      'education' => Icons.school_rounded,
      'rent' => Icons.home_rounded,
      'salary' => Icons.payments_rounded,
      _ => Icons.category_rounded,
    };
  }

  static IconData paymentModeIcon(String? type) {
    return switch (type?.toLowerCase()) {
      'cash' => Icons.payments_rounded,
      'bank' => Icons.account_balance_rounded,
      'card' => Icons.credit_card_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      _ => Icons.account_balance_wallet_outlined,
    };
  }
}
