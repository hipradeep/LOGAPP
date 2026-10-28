import 'models.dart';

/// Keywords, bank mappings, card schemes, and digital wallet identifiers for Indian financial SMS messages.
class SmsKeywords {
  const SmsKeywords._();

  /// Available balance trigger keywords.
  static const List<String> availableBalanceKeywords = [
    'avbl bal',
    'available balance',
    'available limit',
    'available credit limit',
    'avbl. credit limit',
    'limit available',
    'a/c bal',
    'ac bal',
    'available bal',
    'avl bal',
    'updated balance',
    'total balance',
    'new balance',
    'bal',
    'avl lmt',
    'available',
  ];

  /// Outstanding balance trigger keywords.
  static const List<String> outstandingBalanceKeywords = ['outstanding'];

  /// Supported digital wallet brand keywords.
  static const List<String> wallets = [
    'paytm',
    'simpl',
    'lazypay',
    'amazon_pay',
    'freecharge',
    'airtel_money',
    'oxigen',
    'ola_money',
    'jio_money',
    'itzcash',
    'payzapp',
    'yesbank_wallet',
    'mobikwik',
    'phonepe',
  ];

  /// UPI identifier triggers.
  static const List<String> upiKeywords = [
    'upi',
    'ref no',
    'upi ref',
    'upi ref no',
    'rrn',
    'utr',
  ];

  /// Card type triggers.
  static const List<String> creditCardKeywords = ['credit', 'cc'];
  static const List<String> debitCardKeywords = ['debit', 'dc'];

  /// Card scheme mappings.
  static const Map<String, CardScheme> cardSchemeKeywords = {
    'visa': CardScheme.visa,
    'mastercard': CardScheme.mastercard,
    'master': CardScheme.mastercard,
    'mast': CardScheme.mastercard,
    'maestro': CardScheme.maestro,
    'maes': CardScheme.maestro,
    'rupay': CardScheme.rupay,
    'amex': CardScheme.amex,
    'american express': CardScheme.amex,
    'diners': CardScheme.diners,
    'dinr': CardScheme.diners,
    'sbi maestro': CardScheme.sbiMaestro,
    'smae': CardScheme.sbiMaestro,
  };

  /// Common bank name aliases.
  static const Map<String, String> bankNameMap = {
    'sbi': 'State Bank of India',
    'hdfc': 'HDFC Bank',
    'icici': 'ICICI Bank',
    'axis': 'Axis Bank',
    'kotak': 'Kotak Mahindra Bank',
    'pnb': 'Punjab National Bank',
    'bob': 'Bank of Baroda',
    'boi': 'Bank of India',
    'idbi': 'IDBI Bank',
    'idfc': 'IDFC First Bank',
    'yes': 'Yes Bank',
    'rbl': 'RBL Bank',
    'indusind': 'IndusInd Bank',
    'canara': 'Canara Bank',
    'union': 'Union Bank of India',
  };

  /// Common Indian UPI handle suffixes.
  static const List<String> upiHandles = [
    '@okhdfcbank',
    '@okaxis',
    '@oksbi',
    '@okicici',
    '@ybl',
    '@ibl',
    '@axl',
    '@paytm',
    '@apl',
    '@upi',
  ];
}
