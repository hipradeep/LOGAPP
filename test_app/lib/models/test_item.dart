class TestItem {
  final String id;
  final String content;
  final DateTime createdAt;
  final bool isSynced;

  const TestItem({
    required this.id,
    required this.content,
    required this.createdAt,
    this.isSynced = false,
  });

  TestItem copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return TestItem(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory TestItem.fromJson(Map<String, dynamic> json) {
    return TestItem(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }
}
