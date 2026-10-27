import 'model_utils.dart';

class DebtRecord {
  final String id;
  final String contactId;
  final String? transactionId;
  final String direction;
  final double amount;
  final double settledAmount;
  final String status;
  final DateTime? dueDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime? settledAt;

  const DebtRecord({
    required this.id,
    required this.contactId,
    this.transactionId,
    required this.direction,
    required this.amount,
    this.settledAmount = 0,
    this.status = 'pending',
    this.dueDate,
    this.notes,
    required this.createdAt,
    this.settledAt,
  });

  bool get isGiven => direction == 'give';
  bool get isTaken => direction == 'take';
  bool get isSettled => status == 'settled';
  double get outstanding =>
      (amount - settledAmount).clamp(0, amount).toDouble();

  Map<String, dynamic> toMap() => {
    'id': id,
    'contact_id': contactId,
    'transaction_id': transactionId,
    'direction': direction,
    'amount': amount,
    'settled_amount': settledAmount,
    'status': status,
    'due_date': epochFromDate(dueDate),
    'notes': notes,
    'created_at': epochFromDate(createdAt),
    'settled_at': epochFromDate(settledAt),
  };

  factory DebtRecord.fromMap(Map<String, dynamic> map) => DebtRecord(
    id: stringValue(map['id']),
    contactId: stringValue(map['contact_id']),
    transactionId: nullableString(map['transaction_id']),
    direction: stringValue(map['direction'], 'give'),
    amount: asDouble(map['amount']),
    settledAmount: asDouble(map['settled_amount']),
    status: stringValue(map['status'], 'pending'),
    dueDate: dateFromValue(map['due_date']),
    notes: nullableString(map['notes']),
    createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
    settledAt: dateFromValue(map['settled_at']),
  );

  DebtRecord copyWith({
    String? id,
    String? contactId,
    String? transactionId,
    String? direction,
    double? amount,
    double? settledAmount,
    String? status,
    DateTime? dueDate,
    String? notes,
    DateTime? createdAt,
    DateTime? settledAt,
  }) => DebtRecord(
    id: id ?? this.id,
    contactId: contactId ?? this.contactId,
    transactionId: transactionId ?? this.transactionId,
    direction: direction ?? this.direction,
    amount: amount ?? this.amount,
    settledAmount: settledAmount ?? this.settledAmount,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    settledAt: settledAt ?? this.settledAt,
  );
}
