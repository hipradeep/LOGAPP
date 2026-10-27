import 'model_utils.dart';

class StagedSmsTransaction {
  final String id;
  final String smsSender;
  final String rawBody;
  final double? extractedAmount;
  final String? extractedMerchant;
  final String? extractedType;
  final String? accountRef;
  final DateTime smsTimestamp;
  final String status;
  final DateTime createdAt;

  const StagedSmsTransaction({
    required this.id,
    required this.smsSender,
    required this.rawBody,
    this.extractedAmount,
    this.extractedMerchant,
    this.extractedType,
    this.accountRef,
    required this.smsTimestamp,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isDebit => extractedType == 'debit';
  bool get isCredit => extractedType == 'credit';

  Map<String, dynamic> toMap() => {
    'id': id,
    'sms_sender': smsSender,
    'raw_body': rawBody,
    'extracted_amount': extractedAmount,
    'extracted_merchant': extractedMerchant,
    'extracted_type': extractedType,
    'account_ref': accountRef,
    'sms_timestamp': epochFromDate(smsTimestamp),
    'status': status,
    'created_at': epochFromDate(createdAt),
  };

  factory StagedSmsTransaction.fromMap(Map<String, dynamic> map) =>
      StagedSmsTransaction(
        id: stringValue(map['id']),
        smsSender: stringValue(map['sms_sender']),
        rawBody: stringValue(map['raw_body']),
        extractedAmount: asDoubleOrNull(map['extracted_amount']),
        extractedMerchant: nullableString(map['extracted_merchant']),
        extractedType: nullableString(map['extracted_type']),
        accountRef: nullableString(map['account_ref']),
        smsTimestamp: dateFromValue(map['sms_timestamp']) ?? DateTime.now(),
        status: stringValue(map['status'], 'pending'),
        createdAt: dateFromValue(map['created_at']) ?? DateTime.now(),
      );

  StagedSmsTransaction copyWith({
    String? id,
    String? smsSender,
    String? rawBody,
    double? extractedAmount,
    String? extractedMerchant,
    String? extractedType,
    String? accountRef,
    DateTime? smsTimestamp,
    String? status,
    DateTime? createdAt,
  }) => StagedSmsTransaction(
    id: id ?? this.id,
    smsSender: smsSender ?? this.smsSender,
    rawBody: rawBody ?? this.rawBody,
    extractedAmount: extractedAmount ?? this.extractedAmount,
    extractedMerchant: extractedMerchant ?? this.extractedMerchant,
    extractedType: extractedType ?? this.extractedType,
    accountRef: accountRef ?? this.accountRef,
    smsTimestamp: smsTimestamp ?? this.smsTimestamp,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
