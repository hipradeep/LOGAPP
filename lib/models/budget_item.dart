import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetExpense {
  final String id;
  final String tag;
  final String description;
  final double amount;
  final DateTime timestamp;

  BudgetExpense({
    required this.id,
    required this.tag,
    required this.description,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag': tag,
      'description': description,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory BudgetExpense.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final DateTime dateTime;
    if (rawTimestamp is Timestamp) {
      dateTime = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      dateTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      dateTime = DateTime.now();
    }

    return BudgetExpense(
      id: map['id'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: dateTime,
    );
  }
}

class BudgetItem {
  final String id;
  final String category;
  final double limit;
  final String period; // 'daily', 'weekly', 'monthly', 'custom'
  final List<BudgetExpense> expenses;
  final String description;
  final List<int> repeatDays;
  final String? scheduledTime; // e.g. "09:00"
  final DateTime? startDate;
  final DateTime? endDate;
  final bool repeat;
  final bool checked;

  BudgetItem({
    required this.id,
    required this.category,
    required this.limit,
    required this.period,
    required this.expenses,
    this.description = '',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduledTime,
    this.startDate,
    this.endDate,
    this.repeat = true,
    this.checked = true,
  });

  double get spentForCurrentPeriod {
    final now = DateTime.now();
    double sum = 0.0;
    for (final exp in expenses) {
      // Filter by repeatDays if set
      if (repeatDays.isNotEmpty && !repeatDays.contains(exp.timestamp.weekday)) {
        continue;
      }

      if (period == 'daily') {
        if (exp.timestamp.year == now.year &&
            exp.timestamp.month == now.month &&
            exp.timestamp.day == now.day) {
          sum += exp.amount;
        }
      } else if (period == 'weekly') {
        // Start of week (Monday)
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final expDate = DateTime(exp.timestamp.year, exp.timestamp.month, exp.timestamp.day);
        if (expDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            expDate.isBefore(now.add(const Duration(days: 1)))) {
          sum += exp.amount;
        }
      } else if (period == 'monthly') {
        if (exp.timestamp.year == now.year &&
            exp.timestamp.month == now.month) {
          sum += exp.amount;
        }
      } else if (period == 'custom' || (startDate != null && endDate != null)) {
        final expDate = DateTime(exp.timestamp.year, exp.timestamp.month, exp.timestamp.day);
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

  bool get isOverBudget => spentForCurrentPeriod > limit;

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'limit': limit,
      'period': period,
      'description': description,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'repeat': repeat,
      'checked': checked,
    };
  }

  factory BudgetItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawExpenses = data['expenses'] as List? ?? [];
    final parsedExpenses = rawExpenses
        .map((e) => BudgetExpense.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final Timestamp? firestoreStartDate = data['startDate'] as Timestamp?;
    final Timestamp? firestoreEndDate = data['endDate'] as Timestamp?;

    final rawRepeatDays = data['repeatDays'];
    final List<int> parsedRepeatDays = rawRepeatDays is List
        ? rawRepeatDays.map<int>((e) => (e as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];

    return BudgetItem(
      id: doc.id,
      category: data['category'] as String? ?? '',
      limit: (data['limit'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? 'monthly',
      expenses: parsedExpenses,
      description: data['description'] as String? ?? '',
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: firestoreStartDate?.toDate(),
      endDate: firestoreEndDate?.toDate(),
      repeat: data['repeat'] as bool? ?? true,
      checked: data['checked'] as bool? ?? true,
    );
  }

  factory BudgetItem.fromMap(String id, Map<String, dynamic> data) {
    final rawExpenses = data['expenses'] as List? ?? [];
    final parsedExpenses = rawExpenses
        .map((e) => BudgetExpense.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

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

    return BudgetItem(
      id: id,
      category: data['category'] as String? ?? '',
      limit: (data['limit'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? 'monthly',
      expenses: parsedExpenses,
      description: data['description'] as String? ?? '',
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      repeat: data['repeat'] as bool? ?? true,
      checked: data['checked'] as bool? ?? true,
    );
  }

  BudgetItem copyWith({
    String? id,
    String? category,
    double? limit,
    String? period,
    List<BudgetExpense>? expenses,
    String? description,
    List<int>? repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    bool? repeat,
    bool? checked,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      expenses: expenses ?? this.expenses,
      description: description ?? this.description,
      repeatDays: repeatDays ?? this.repeatDays,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      repeat: repeat ?? this.repeat,
      checked: checked ?? this.checked,
    );
  }
}
