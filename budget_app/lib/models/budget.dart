import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_utils.dart';

class Transaction {
  final String id;
  final String budgetId;
  final String tag;
  final String description;
  final String? merchant;
  final String type; // 'expense', 'income', 'transfer'
  final double amount;
  final DateTime entryDate;
  final DateTime expenseDate;
  final bool isValidated;
  final String? rawBody;
  final String paymentMethod;

  Transaction({
    required this.id,
    required this.budgetId,
    required this.tag,
    required this.description,
    this.merchant,
    this.type = 'expense',
    required this.amount,
    required this.entryDate,
    required this.expenseDate,
    this.isValidated = true,
    this.rawBody,
    this.paymentMethod = 'Cash',
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'tag': tag,
      'description': description,
      'merchant': merchant,
      'type': type,
      'amount': amount,
      'entryDate': Timestamp.fromDate(entryDate),
      'expenseDate': Timestamp.fromDate(expenseDate),
      'isValidated': isValidated,
      'rawBody': rawBody,
      'paymentMethod': paymentMethod,
    };
  }

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Transaction.fromMap(doc.id, data);
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    final rawEntryDate = map['entryDate'];
    final DateTime parsedEntryDate;
    if (rawEntryDate is Timestamp) {
      parsedEntryDate = rawEntryDate.toDate();
    } else if (rawEntryDate is String) {
      parsedEntryDate = DateTime.tryParse(rawEntryDate) ?? DateTime.now();
    } else {
      parsedEntryDate = DateTime.now();
    }

    final rawExpenseDate = map['expenseDate'];
    final DateTime parsedExpenseDate;
    if (rawExpenseDate is Timestamp) {
      parsedExpenseDate = rawExpenseDate.toDate();
    } else if (rawExpenseDate is String) {
      parsedExpenseDate = DateTime.tryParse(rawExpenseDate) ?? parsedEntryDate;
    } else {
      parsedExpenseDate = parsedEntryDate;
    }

    return Transaction(
      id: id,
      budgetId: map['budgetId'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      description: map['description'] as String? ?? '',
      merchant: map['merchant'] as String?,
      type: map['type'] as String? ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      entryDate: parsedEntryDate,
      expenseDate: parsedExpenseDate,
      isValidated: map['isValidated'] as bool? ?? true,
      rawBody: map['rawBody'] as String?,
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
    );
  }
}

class BudgetSubCategory {
  final String name;
  final double percentage;
  final double amount;

  BudgetSubCategory({
    required this.name,
    required this.percentage,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'percentage': percentage,
      'amount': amount,
    };
  }

  factory BudgetSubCategory.fromMap(Map<String, dynamic> map) {
    return BudgetSubCategory(
      name: map['name'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BudgetSubCategory copyWith({
    String? name,
    double? percentage,
    double? amount,
  }) {
    return BudgetSubCategory(
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      amount: amount ?? this.amount,
    );
  }
}

class BudgetCategoryAllocation {
  final String name; // 'Expenses', 'Savings', 'Needs', 'Wants'
  final double percentage;
  final double amount;
  final List<BudgetSubCategory> subCategories;

  BudgetCategoryAllocation({
    required this.name,
    required this.percentage,
    required this.amount,
    this.subCategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'percentage': percentage,
      'amount': amount,
      'subCategories': subCategories.map((s) => s.toMap()).toList(),
    };
  }

  factory BudgetCategoryAllocation.fromMap(Map<String, dynamic> map) {
    final rawSub = map['subCategories'] as List<dynamic>? ?? [];
    return BudgetCategoryAllocation(
      name: map['name'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      subCategories: rawSub
          .map((s) => BudgetSubCategory.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  BudgetCategoryAllocation copyWith({
    String? name,
    double? percentage,
    double? amount,
    List<BudgetSubCategory>? subCategories,
  }) {
    return BudgetCategoryAllocation(
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      amount: amount ?? this.amount,
      subCategories: subCategories ?? this.subCategories,
    );
  }
}

class Budget {
  final String id;
  final String name;
  final String categoryName;
  final double limit;
  final String period; // 'daily', 'weekly', 'monthly', 'custom'
  final String description;
  final List<int> repeatDays;
  final String? scheduledTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool repeat;
  final bool isActive;
  final double alertThreshold;
  final double? salary;
  final String? rule; // '80/20', '70/30', '50/30/20', 'custom'
  final List<BudgetCategoryAllocation> allocations;

  Budget({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.limit,
    required this.period,
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
  });

  // Calculate total expense spent in the active period
  double spentForCurrentPeriod(List<Transaction> allTransactions) {
    final now = DateTime.now();
    double sum = 0.0;
    final budgetTransactions = allTransactions.where((t) => t.budgetId == id && t.isExpense);

    for (final exp in budgetTransactions) {
      if (period == 'daily') {
        if (AppDateUtils.isSameDay(exp.expenseDate, now)) sum += exp.amount;
      } else if (period == 'weekly') {
        final startOfWeek = AppDateUtils.startOfWeek(now);
        final expDate = AppDateUtils.startOfDay(exp.expenseDate);
        if (!expDate.isBefore(startOfWeek) && expDate.isBefore(now.add(const Duration(days: 1)))) {
          sum += exp.amount;
        }
      } else if (period == 'monthly') {
        if (exp.expenseDate.year == now.year && exp.expenseDate.month == now.month) {
          sum += exp.amount;
        }
      } else if (period == 'custom' || (startDate != null && endDate != null)) {
        if (AppDateUtils.isDateInRange(exp.expenseDate, startDate, endDate)) {
          sum += exp.amount;
        }
      } else {
        sum += exp.amount;
      }
    }
    return sum;
  }

  // Calculate safe-to-spend daily allowance in ₹
  double safeToSpendDaily(List<Transaction> allTransactions) {
    final spent = spentForCurrentPeriod(allTransactions);
    final remaining = (limit - spent).clamp(0.0, double.infinity);
    final now = DateTime.now();

    int remainingDays = 1;
    if (period == 'daily') {
      remainingDays = 1;
    } else if (period == 'weekly') {
      remainingDays = 7 - (now.weekday - 1);
      if (remainingDays <= 0) remainingDays = 1;
    } else if (period == 'monthly') {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      remainingDays = (daysInMonth - now.day) + 1;
      if (remainingDays <= 0) remainingDays = 1;
    } else if (endDate != null) {
      final diff = endDate!.difference(now).inDays + 1;
      remainingDays = diff > 0 ? diff : 1;
    }

    return remaining / remainingDays;
  }

  bool isOverBudget(List<Transaction> allTransactions) =>
      spentForCurrentPeriod(allTransactions) > limit;

  bool get isPeriodOver {
    if (endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budgetEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return today.isAfter(budgetEnd);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'categoryName': categoryName,
      'limit': limit,
      'period': period,
      'description': description,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'repeat': repeat,
      'isActive': isActive,
      'alertThreshold': alertThreshold,
      'salary': salary,
      'rule': rule,
      'allocations': allocations.map((a) => a.toMap()).toList(),
    };
  }

  factory Budget.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp? firestoreStartDate = data['startDate'] as Timestamp?;
    final Timestamp? firestoreEndDate = data['endDate'] as Timestamp?;

    final rawRepeatDays = data['repeatDays'];
    final List<int> parsedRepeatDays = rawRepeatDays is List
        ? rawRepeatDays.map<int>((e) => (e as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];

    final rawAllocations = data['allocations'] as List<dynamic>? ?? [];
    final parsedAllocations = rawAllocations
        .map((a) => BudgetCategoryAllocation.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();

    return Budget(
      id: doc.id,
      name: data['name'] as String? ?? data['category'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? data['category'] as String? ?? '',
      limit: (data['limit'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? 'monthly',
      description: data['description'] as String? ?? '',
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: firestoreStartDate?.toDate(),
      endDate: firestoreEndDate?.toDate(),
      repeat: data['repeat'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      alertThreshold: (data['alertThreshold'] as num?)?.toDouble() ?? 0.7,
      salary: (data['salary'] as num?)?.toDouble(),
      rule: data['rule'] as String?,
      allocations: parsedAllocations,
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
  }) {
    return Budget(
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
    );
  }
}
