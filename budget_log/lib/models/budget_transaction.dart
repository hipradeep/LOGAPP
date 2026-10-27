import 'model_utils.dart';

class BudgetTransaction {
  final String id;
  final double amount;
  final String type;
  final String? categoryId;
  final String? paymentModeId;
  final String? budgetId;
  final String title;
  final String? note;
  final DateTime timestamp;
  final DateTime createdAt;

  const BudgetTransaction({
    required this.id,
    required this.amount,
    this.type = 'expense',
    this.categoryId,
    this.paymentModeId,
    this.budgetId,
    required this.title,
    this.note,
    required this.timestamp,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'type': type,
    'category_id': categoryId,
    'payment_mode_id': paymentModeId,
    'budget_id': budgetId,
    'title': title,
    'note': note,
    'timestamp': epochFromDate(timestamp),
    'created_at': epochFromDate(createdAt),
  };

  factory BudgetTransaction.fromMap(Map<String, dynamic> map) =>
      BudgetTransaction(
        id: stringValue(map['id']),
        amount: asDouble(map['amount']),
        type: stringValue(map['type'], 'expense'),
        categoryId: nullableString(map['category_id']),
        paymentModeId: nullableString(map['payment_mode_id']),
        budgetId: nullableString(map['budget_id']),
        title: stringValue(map['title'], 'Untitled'),
        note: nullableString(map['note']),
        timestamp: dateFromValue(map['timestamp']) ?? DateTime.now(),
        createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
      );

  BudgetTransaction copyWith({
    String? id,
    double? amount,
    String? type,
    String? categoryId,
    String? paymentModeId,
    String? budgetId,
    String? title,
    String? note,
    DateTime? timestamp,
    DateTime? createdAt,
  }) => BudgetTransaction(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    paymentModeId: paymentModeId ?? this.paymentModeId,
    budgetId: budgetId ?? this.budgetId,
    title: title ?? this.title,
    note: note ?? this.note,
    timestamp: timestamp ?? this.timestamp,
    createdAt: createdAt ?? this.createdAt,
  );
}
