import 'dart:convert';

import 'model_utils.dart';

class BudgetTagMapping {
  static const String expenseType = 'exp';
  static const String incomeType = 'income';
  static const String miscExpenseTag = 'misc_exp';
  static const String miscIncomeTag = 'misc_inc';

  final String id;
  final String budgetId;
  final String type;
  final List<String> tagIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetTagMapping({
    required this.id,
    required this.budgetId,
    required this.type,
    this.tagIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpense => type == expenseType;

  bool get isIncome => type == incomeType;

  bool get includesMiscExpense => isExpense && tagIds.contains(miscExpenseTag);

  bool get includesMiscIncome => isIncome && tagIds.contains(miscIncomeTag);

  Set<String> get tagIdSet => tagIds.toSet();

  Map<String, dynamic> toMap() => {
    'id': id,
    'budget_id': budgetId,
    'type': type,
    'tag_ids': jsonEncode(tagIds),
    'created_at': epochFromDate(createdAt),
    'updated_at': epochFromDate(updatedAt),
  };

  factory BudgetTagMapping.fromMap(Map<String, dynamic> map) =>
      BudgetTagMapping(
        id: stringValue(map['id']),
        budgetId: stringValue(map['budget_id']),
        type: stringValue(map['type'], expenseType),
        tagIds: stringListFromValue(map['tag_ids']),
        createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
        updatedAt: dateFromValue(map['updated_at']) ?? DateTime.now(),
      );

  BudgetTagMapping copyWith({
    String? id,
    String? budgetId,
    String? type,
    List<String>? tagIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BudgetTagMapping(
    id: id ?? this.id,
    budgetId: budgetId ?? this.budgetId,
    type: type ?? this.type,
    tagIds: tagIds ?? this.tagIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

List<String> stringListFromValue(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } on FormatException {
      return const [];
    }
  }
  return const [];
}
