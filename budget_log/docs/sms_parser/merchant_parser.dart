import 'keywords.dart';

/// Parsed merchant and reference ID container.
class MerchantInfo {
  final String? merchant;
  final String? referenceNo;

  const MerchantInfo({this.merchant, this.referenceNo});
}

/// Parser for merchant name, VPA handles, and UPI reference/UTR numbers.
class MerchantParser {
  const MerchantParser._();

  static MerchantInfo extract(String rawMessage, List<String> words) {
    String? merchant;
    String? referenceNo;

    // 1. Extract from VPA (e.g., 'to VPA user@okhdfcbank')
    final vpaIdx = words.indexOf('vpa');
    if (vpaIdx != -1 && vpaIdx + 1 < words.length) {
      final vpaStr = words[vpaIdx + 1].replaceAll(RegExp(r'[\(\)]'), ' ');
      merchant = vpaStr.split('@').first.trim();
    }

    // 2. Extract UPI Reference / UTR
    final refMatch = RegExp(
      r'(?:ref\s*no\.?|upi\s*ref|rrn|utr)\s*[:\-]?\s*([0-9]{6,16})',
      caseSensitive: false,
    ).firstMatch(rawMessage);
    if (refMatch != null) {
      referenceNo = refMatch.group(1);
    }

    // 3. Fallback: Extract from 'at <MERCHANT>' or 'to <MERCHANT>'
    if (merchant == null) {
      final merchantMatch = RegExp(
        r'(?:to|at|info)\s+([A-Za-z0-9\.\-_\s]{2,20}?)(?=\s+(?:on|ref|avl|bal|using|via|\.|$))',
        caseSensitive: false,
      ).firstMatch(rawMessage);
      merchant = merchantMatch?.group(1)?.trim();
    }

    // 4. Fallback: Search known UPI handles
    if (merchant == null) {
      final handleRegex = RegExp(
        '[a-zA-Z0-9_.-]+(${SmsKeywords.upiHandles.join('|')})',
        caseSensitive: false,
      );
      final match = handleRegex.firstMatch(rawMessage);
      if (match != null) {
        merchant = match.group(0);
      }
    }

    return MerchantInfo(merchant: merchant, referenceNo: referenceNo);
  }
}
