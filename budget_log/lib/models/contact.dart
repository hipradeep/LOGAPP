import 'model_utils.dart';

class Contact {
  final String id;
  final String name;
  final String? phone;
  final String? upiId;
  final int avatarColorIndex;
  final DateTime createdAt;

  const Contact({
    required this.id,
    required this.name,
    this.phone,
    this.upiId,
    this.avatarColorIndex = 0,
    required this.createdAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'upi_id': upiId,
    'avatar_color_index': avatarColorIndex,
    'created_at': epochFromDate(createdAt),
  };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: stringValue(map['id']),
    name: stringValue(map['name'], 'Unknown'),
    phone: nullableString(map['phone']),
    upiId: nullableString(map['upi_id']),
    avatarColorIndex: asInt(map['avatar_color_index']),
    createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
  );

  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    String? upiId,
    int? avatarColorIndex,
    DateTime? createdAt,
  }) => Contact(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    upiId: upiId ?? this.upiId,
    avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
    createdAt: createdAt ?? this.createdAt,
  );
}
