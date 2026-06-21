import '../utils/db_utils.dart';
import '../utils/date_utils.dart';

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
  final String paymentMethod;

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
    this.paymentMethod = 'PNB',
  });

  // ─── SQLite serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'budgetId': budgetId,
      'tag': tag,
      'description': description,
      'amount': amount,
      'entryDate': DbUtils.dateToMs(entryDate),
      'expenseDate': DbUtils.dateToMs(expenseDate),
      'isValidated': isValidated ? 1 : 0,
      'rawBody': rawBody,
      'paymentMethod': paymentMethod,
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    final rawEntryDate = map['entryDate'];
    final DateTime parsedEntryDate = rawEntryDate is int
        ? DbUtils.msToDate(rawEntryDate)
        : (rawEntryDate is String ? DateTime.tryParse(rawEntryDate) ?? DateTime.now() : DateTime.now());

    final rawExpenseDate = map['expenseDate'];
    final DateTime parsedExpenseDate = rawExpenseDate is int
        ? DbUtils.msToDate(rawExpenseDate)
        : (rawExpenseDate is String ? DateTime.tryParse(rawExpenseDate) ?? parsedEntryDate : parsedEntryDate);

    return Transaction(
      id: id,
      budgetId: map['budgetId'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      entryDate: parsedEntryDate,
      expenseDate: parsedExpenseDate,
      isValidated: map['isValidated'] == 1 || map['isValidated'] == true,
      rawBody: map['rawBody'] as String?,
      paymentMethod: map['paymentMethod'] as String? ?? 'PNB',
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
  final double alertThreshold; // 0.0–1.0

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

  // ─── Business logic ───────────────────────────────────────────────────────

  double spentForCurrentPeriod(List<Transaction> allTransactions) {
    final now = DateTime.now();
    double sum = 0.0;
    final budgetTransactions = allTransactions.where((t) => t.budgetId == id);

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

  bool isOverBudget(List<Transaction> allTransactions) =>
      spentForCurrentPeriod(allTransactions) > limit;

  // ─── SQLite serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryName': categoryName,
      'limit_amount': limit,
      'period': period,
      'description': description,
      'repeatDays': DbUtils.encodeIntList(repeatDays),
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? DbUtils.dateToMs(startDate!) : null,
      'endDate': endDate != null ? DbUtils.dateToMs(endDate!) : null,
      'repeat': repeat ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'alertThreshold': alertThreshold,
    };
  }

  factory Budget.fromMap(String id, Map<String, dynamic> map) {
    final rawRepeatDays = map['repeatDays'];
    List<int> parsedRepeatDays;
    if (rawRepeatDays is String) {
      parsedRepeatDays = DbUtils.decodeIntList(rawRepeatDays);
    } else if (rawRepeatDays is List) {
      parsedRepeatDays = rawRepeatDays.map<int>((e) => (e as num).toInt()).toList();
    } else {
      parsedRepeatDays = const [1, 2, 3, 4, 5, 6, 7];
    }

    return Budget(
      id: id,
      name: map['name'] as String? ?? map['category'] as String? ?? '',
      categoryName: map['categoryName'] as String? ?? map['category'] as String? ?? '',
      // SQLite column is limit_amount to avoid reserved word conflict
      limit: (map['limit_amount'] as num? ?? map['limit'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] as String? ?? 'monthly',
      description: map['description'] as String? ?? '',
      repeatDays: parsedRepeatDays,
      scheduledTime: map['scheduledTime'] as String?,
      startDate: DbUtils.msToDateNullable(map['startDate'] as int?),
      endDate: DbUtils.msToDateNullable(map['endDate'] as int?),
      repeat: map['repeat'] == 1 || map['repeat'] == true,
      isActive: map['isActive'] == 1 || map['isActive'] == true,
      alertThreshold: (map['alertThreshold'] as num?)?.toDouble() ?? 0.7,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

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
