import 'model_utils.dart';

class Category {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final int colorIndex;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.colorIndex = 0,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense' || type == 'both';
  bool get isIncome => type == 'income' || type == 'both';
  bool get isBoth => type == 'both';

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'color_index': colorIndex,
    'created_at': epochFromDate(createdAt),
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: stringValue(map['id']),
    name: stringValue(map['name'], 'Untitled'),
    type: stringValue(map['type'], 'expense'),
    icon: nullableString(map['icon']),
    colorIndex: asInt(map['color_index']),
    createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
  );

  Category copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    int? colorIndex,
    DateTime? createdAt,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
  );
}
