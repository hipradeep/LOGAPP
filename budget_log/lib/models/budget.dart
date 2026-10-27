import 'dart:convert';

import '../utils/date_utils.dart';
import 'budget_transaction.dart';
import 'model_utils.dart';

class BudgetSubCategory {
  final String name;
  final double percentage;
  final double amount;

  const BudgetSubCategory({
    required this.name,
    required this.percentage,
    required this.amount,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'percentage': percentage,
    'amount': amount,
  };

  factory BudgetSubCategory.fromMap(Map<String, dynamic> map) =>
      BudgetSubCategory(
        name: stringValue(map['name']),
        percentage: asDouble(map['percentage']),
        amount: asDouble(map['amount']),
      );

  BudgetSubCategory copyWith({
    String? name,
    double? percentage,
    double? amount,
  }) => BudgetSubCategory(
    name: name ?? this.name,
    percentage: percentage ?? this.percentage,
    amount: amount ?? this.amount,
  );
}

class BudgetCategoryAllocation {
  final String name;
  final double percentage;
  final double amount;
  final List<BudgetSubCategory> subCategories;

  const BudgetCategoryAllocation({
    required this.name,
    required this.percentage,
    required this.amount,
    this.subCategories = const [],
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'percentage': percentage,
    'amount': amount,
    'subCategories': subCategories.map((item) => item.toMap()).toList(),
  };

  factory BudgetCategoryAllocation.fromMap(Map<String, dynamic> map) {
    final rawSubCategories = map['subCategories'];
    final subCategories = rawSubCategories is List
        ? rawSubCategories
              .map((item) => BudgetSubCategory.fromMap(mapFromValue(item)))
              .toList()
        : <BudgetSubCategory>[];
    return BudgetCategoryAllocation(
      name: stringValue(map['name']),
      percentage: asDouble(map['percentage']),
      amount: asDouble(map['amount']),
      subCategories: subCategories,
    );
  }

  BudgetCategoryAllocation copyWith({
    String? name,
    double? percentage,
    double? amount,
    List<BudgetSubCategory>? subCategories,
  }) => BudgetCategoryAllocation(
    name: name ?? this.name,
    percentage: percentage ?? this.percentage,
    amount: amount ?? this.amount,
    subCategories: subCategories ?? this.subCategories,
  );
}

class Budget {
  final String id;
  final String name;
  final String categoryName;
  final double limit;
  final String period;
  final String description;
  final List<int> repeatDays;
  final String? scheduledTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool repeat;
  final bool isActive;
  final double alertThreshold;
  final double? salary;
  final String? rule;
  final List<BudgetCategoryAllocation> allocations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.limit,
    this.period = 'monthly',
    this.description = '',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduledTime,
    this.startDate,
    this.endDate,
    this.repeat = true,
    this.isActive = true,
    this.alertThreshold = 0.7,
    this.salary,
    this.rule,
    this.allocations = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPeriodOver {
    if (endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budgetEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return today.isAfter(budgetEnd);
  }

  double spentForCurrentPeriod(List<BudgetTransaction> allTransactions) {
    final now = DateTime.now();
    var total = 0.0;
    for (final transaction in allTransactions) {
      if (transaction.budgetId != id || !transaction.isExpense) continue;
      if (period == 'daily') {
        if (AppDateUtils.isSameDay(transaction.timestamp, now)) {
          total += transaction.amount;
        }
      } else if (period == 'weekly') {
        final startOfWeek = AppDateUtils.startOfWeek(now);
        final transactionDate = AppDateUtils.startOfDay(transaction.timestamp);
        if (!transactionDate.isBefore(startOfWeek) &&
            transactionDate.isBefore(now.add(const Duration(days: 1)))) {
          total += transaction.amount;
        }
      } else if (period == 'monthly') {
        if (transaction.timestamp.year == now.year &&
            transaction.timestamp.month == now.month) {
          total += transaction.amount;
        }
      } else if (period == 'custom' || (startDate != null && endDate != null)) {
        if (AppDateUtils.isDateInRange(
          transaction.timestamp,
          startDate,
          endDate,
        )) {
          total += transaction.amount;
        }
      } else {
        total += transaction.amount;
      }
    }
    return total;
  }

  double safeToSpendDaily(List<BudgetTransaction> allTransactions) {
    final spent = spentForCurrentPeriod(allTransactions);
    final remaining = (limit - spent).clamp(0, double.infinity).toDouble();
    final now = DateTime.now();

    var remainingDays = 1;
    if (period == 'daily') {
      remainingDays = 1;
    } else if (period == 'weekly') {
      remainingDays = 7 - (now.weekday - 1);
      if (remainingDays <= 0) remainingDays = 1;
    } else if (period == 'monthly') {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      remainingDays = daysInMonth - now.day + 1;
      if (remainingDays <= 0) remainingDays = 1;
    } else if (endDate != null) {
      final difference = endDate!.difference(now).inDays + 1;
      remainingDays = difference > 0 ? difference : 1;
    }

    return remaining / remainingDays;
  }

  bool isOverBudget(List<BudgetTransaction> allTransactions) =>
      spentForCurrentPeriod(allTransactions) > limit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category_name': categoryName,
    'limit_amount': limit,
    'period': period,
    'description': description,
    'repeat_days': jsonEncode(repeatDays),
    'scheduled_time': scheduledTime,
    'start_date': epochFromDate(startDate),
    'end_date': epochFromDate(endDate),
    'repeat': repeat ? 1 : 0,
    'is_active': isActive ? 1 : 0,
    'alert_threshold': alertThreshold,
    'salary': salary,
    'rule': rule,
    'allocations': jsonEncode(allocations.map((item) => item.toMap()).toList()),
    'created_at': epochFromDate(createdAt),
    'updated_at': epochFromDate(updatedAt),
  };

  factory Budget.fromMap(Map<String, dynamic> map) {
    final rawAllocations = map['allocations'];
    final allocations = rawAllocations is List
        ? rawAllocations
              .map(
                (item) => BudgetCategoryAllocation.fromMap(mapFromValue(item)),
              )
              .toList()
        : rawAllocations is String && rawAllocations.isNotEmpty
        ? (jsonDecode(rawAllocations) as List)
              .map(
                (item) => BudgetCategoryAllocation.fromMap(mapFromValue(item)),
              )
              .toList()
        : <BudgetCategoryAllocation>[];

    return Budget(
      id: stringValue(map['id']),
      name: stringValue(map['name'], 'Untitled'),
      categoryName: stringValue(map['category_name']),
      limit: asDouble(map['limit_amount']),
      period: stringValue(map['period'], 'monthly'),
      description: stringValue(map['description']),
      repeatDays: intListFromValue(map['repeat_days']),
      scheduledTime: nullableString(map['scheduled_time']),
      startDate: dateFromValue(map['start_date']),
      endDate: dateFromValue(map['end_date']),
      repeat: asBool(map['repeat'], true),
      isActive: asBool(map['is_active'], true),
      alertThreshold: asDouble(map['alert_threshold'], 0.7),
      salary: asDoubleOrNull(map['salary']),
      rule: nullableString(map['rule']),
      allocations: allocations,
      createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
      updatedAt: dateFromValue(map['updated_at']) ?? DateTime.now(),
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    String? categoryName,
    double? limit,
    String? period,
    String? description,
    List<int>? repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    bool? repeat,
    bool? isActive,
    double? alertThreshold,
    double? salary,
    String? rule,
    List<BudgetCategoryAllocation>? allocations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Budget(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryName: categoryName ?? this.categoryName,
    limit: limit ?? this.limit,
    period: period ?? this.period,
    description: description ?? this.description,
    repeatDays: repeatDays ?? this.repeatDays,
    scheduledTime: scheduledTime ?? this.scheduledTime,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    repeat: repeat ?? this.repeat,
    isActive: isActive ?? this.isActive,
    alertThreshold: alertThreshold ?? this.alertThreshold,
    salary: salary ?? this.salary,
    rule: rule ?? this.rule,
    allocations: allocations ?? this.allocations,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
