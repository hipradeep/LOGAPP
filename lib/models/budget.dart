import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String budgetId;
  final String tag;
  final String description;
  final double amount;
  final DateTime entryDate;
  final DateTime expenseDate;
  final bool isValidated;
  final String? rawBody;

  Transaction({
    required this.id,
    required this.budgetId,
    required this.tag,
    required this.description,
    required this.amount,
    required this.entryDate,
    required this.expenseDate,
    this.isValidated = true,
    this.rawBody,
  });

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'tag': tag,
      'description': description,
      'amount': amount,
      'entryDate': Timestamp.fromDate(entryDate),
      'expenseDate': Timestamp.fromDate(expenseDate),
      'isValidated': isValidated,
      'rawBody': rawBody,
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
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      entryDate: parsedEntryDate,
      expenseDate: parsedExpenseDate,
      isValidated: map['isValidated'] as bool? ?? true,
      rawBody: map['rawBody'] as String?,
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
  final List<int> repeatDays; // Weekdays (1=Mon…7=Sun) for notification scheduling only — NOT used to filter transactions
  final String? scheduledTime; // e.g. "09:00"
  final DateTime? startDate;
  final DateTime? endDate;
  final bool repeat;
  final bool isActive;
  final double alertThreshold; // 0.0–1.0, e.g. 0.7 = alert at 70% of limit

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
  });

  double spentForCurrentPeriod(List<Transaction> allTransactions) {
    final now = DateTime.now();
    double sum = 0.0;
    
    // Filter transactions belonging to this budget
    final budgetTransactions = allTransactions.where((t) => t.budgetId == id);

    for (final exp in budgetTransactions) {
      if (period == 'daily') {
        if (exp.expenseDate.year == now.year &&
            exp.expenseDate.month == now.month &&
            exp.expenseDate.day == now.day) {
          sum += exp.amount;
        }
      } else if (period == 'weekly') {
        // Start of week (Monday)
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final expDate = DateTime(exp.expenseDate.year, exp.expenseDate.month, exp.expenseDate.day);
        if (expDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            expDate.isBefore(now.add(const Duration(days: 1)))) {
          sum += exp.amount;
        }
      } else if (period == 'monthly') {
        if (exp.expenseDate.year == now.year &&
            exp.expenseDate.month == now.month) {
          sum += exp.amount;
        }
      } else if (period == 'custom' || (startDate != null && endDate != null)) {
        final expDate = DateTime(exp.expenseDate.year, exp.expenseDate.month, exp.expenseDate.day);
        final start = startDate != null ? DateTime(startDate!.year, startDate!.month, startDate!.day) : null;
        final end = endDate != null ? DateTime(endDate!.year, endDate!.month, endDate!.day) : null;
        bool inRange = true;
        if (start != null && expDate.isBefore(start)) inRange = false;
        if (end != null && expDate.isAfter(end)) inRange = false;
        if (inRange) {
          sum += exp.amount;
        }
      } else {
        sum += exp.amount;
      }
    }
    return sum;
  }

  bool isOverBudget(List<Transaction> allTransactions) =>
      spentForCurrentPeriod(allTransactions) > limit;

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
      isActive: data['isActive'] as bool? ?? data['checked'] as bool? ?? true,
      alertThreshold: (data['alertThreshold'] as num?)?.toDouble() ?? 0.7,
    );
  }

  factory Budget.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsedStartDate;
    final rawStartDate = data['startDate'];
    if (rawStartDate is Timestamp) {
      parsedStartDate = rawStartDate.toDate();
    } else if (rawStartDate is String) {
      parsedStartDate = DateTime.tryParse(rawStartDate);
    }

    DateTime? parsedEndDate;
    final rawEndDate = data['endDate'];
    if (rawEndDate is Timestamp) {
      parsedEndDate = rawEndDate.toDate();
    } else if (rawEndDate is String) {
      parsedEndDate = DateTime.tryParse(rawEndDate);
    }

    final rawRepeatDays = data['repeatDays'];
    final List<int> parsedRepeatDays = rawRepeatDays is List
        ? rawRepeatDays.map<int>((e) => (e as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];

    return Budget(
      id: id,
      name: data['name'] as String? ?? data['category'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? data['category'] as String? ?? '',
      limit: (data['limit'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? 'monthly',
      description: data['description'] as String? ?? '',
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      repeat: data['repeat'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? data['checked'] as bool? ?? true,
      alertThreshold: (data['alertThreshold'] as num?)?.toDouble() ?? 0.7,
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
    );
  }
}
