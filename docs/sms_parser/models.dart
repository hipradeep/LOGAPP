/// Enums representing transaction, account, and card properties for SMS parsing.
library;

/// Transaction type: debit (outgoing) or credit (incoming).
enum TransactionType {
  debit,
  credit,
}

/// Type of financial account identified in the SMS.
enum AccountType {
  account,
  card,
  wallet,
}

/// Type of card: credit or debit.
enum CardType {
  credit,
  debit,
}

/// Card payment scheme.
enum CardScheme {
  visa,
  mastercard,
  rupay,
  maestro,
  amex,
  diners,
  sbiMaestro,
}

/// Balance classification.
enum BalanceKeywordType {
  available,
  outstanding,
}
