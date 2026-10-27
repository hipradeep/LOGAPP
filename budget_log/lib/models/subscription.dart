import 'model_utils.dart';

class Subscription {
  final String id;
  final String name;
  final double amount;
  final String? categoryId;
  final String? paymentModeId;
  final String frequency;
  final DateTime nextDueDate;
  final int reminderDaysBefore;
  final bool isActive;
  final bool isAutopay;
  final String? notes;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    this.categoryId,
    this.paymentModeId,
    this.frequency = 'monthly',
    required this.nextDueDate,
    this.reminderDaysBefore = 1,
    this.isActive = true,
    this.isAutopay = false,
    this.notes,
    required this.createdAt,
  });

  bool get isDaily => frequency == 'daily';
  bool get isWeekly => frequency == 'weekly';
  bool get isMonthly => frequency == 'monthly';
  bool get isQuarterly => frequency == 'quarterly';
  bool get isYearly => frequency == 'yearly';

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'category_id': categoryId,
    'payment_mode_id': paymentModeId,
    'frequency': frequency,
    'next_due_date': epochFromDate(nextDueDate),
    'reminder_days_before': reminderDaysBefore,
    'is_active': isActive ? 1 : 0,
    'is_autopay': isAutopay ? 1 : 0,
    'notes': notes,
    'created_at': epochFromDate(createdAt),
  };

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: stringValue(map['id']),
    name: stringValue(map['name'], 'Untitled'),
    amount: asDouble(map['amount']),
    categoryId: nullableString(map['category_id']),
    paymentModeId: nullableString(map['payment_mode_id']),
    frequency: stringValue(map['frequency'], 'monthly'),
    nextDueDate: dateFromValue(map['next_due_date']) ?? DateTime.now(),
    reminderDaysBefore: asInt(map['reminder_days_before'], 1),
    isActive: asBool(map['is_active'], true),
    isAutopay: asBool(map['is_autopay'], false),
    notes: nullableString(map['notes']),
    createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
  );

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    String? paymentModeId,
    String? frequency,
    DateTime? nextDueDate,
    int? reminderDaysBefore,
    bool? isActive,
    bool? isAutopay,
    String? notes,
    DateTime? createdAt,
  }) => Subscription(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    paymentModeId: paymentModeId ?? this.paymentModeId,
    frequency: frequency ?? this.frequency,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    isActive: isActive ?? this.isActive,
    isAutopay: isAutopay ?? this.isAutopay,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
}
