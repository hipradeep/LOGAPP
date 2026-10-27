import 'model_utils.dart';

class PaymentMode {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final DateTime createdAt;

  const PaymentMode({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    required this.createdAt,
  });

  bool get isCash => type == 'cash';
  bool get isBank => type == 'bank';
  bool get isCard => type == 'card';
  bool get isWallet => type == 'wallet';

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'icon': icon,
    'created_at': epochFromDate(createdAt),
  };

  factory PaymentMode.fromMap(Map<String, dynamic> map) => PaymentMode(
    id: stringValue(map['id']),
    name: stringValue(map['name'], 'Untitled'),
    type: stringValue(map['type'], 'cash'),
    icon: nullableString(map['icon']),
    createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
  );

  PaymentMode copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    DateTime? createdAt,
  }) => PaymentMode(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    createdAt: createdAt ?? this.createdAt,
  );
}
