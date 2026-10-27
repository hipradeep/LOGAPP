class SmsInboxRecord {
  final String sourceKey;
  final String sender;
  final String body;
  final DateTime timestamp;
  final String? providerId;

  const SmsInboxRecord({
    required this.sourceKey,
    required this.sender,
    required this.body,
    required this.timestamp,
    this.providerId,
  });

  factory SmsInboxRecord.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    return SmsInboxRecord(
      sourceKey: (map['sourceKey'] as String?) ?? '',
      sender: (map['sender'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      timestamp: rawTimestamp is num
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
          : DateTime.now(),
      providerId: map['providerId'] as String?,
    );
  }
}

class SmsValidationTarget {
  final String id;
  final String kind;

  const SmsValidationTarget({required this.id, required this.kind});

  factory SmsValidationTarget.fromMap(Map<String, dynamic> map) {
    return SmsValidationTarget(
      id: (map['id'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'staged',
    );
  }
}
