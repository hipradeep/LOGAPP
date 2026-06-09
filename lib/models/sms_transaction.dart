class SmsTransaction {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final String sender;
  final String rawBody;
  final bool isCredit;

  SmsTransaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.sender,
    required this.rawBody,
    this.isCredit = false,
  });
}
