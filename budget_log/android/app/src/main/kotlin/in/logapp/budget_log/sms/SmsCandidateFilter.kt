package `in`.logapp.budget_log.sms

import java.util.Locale

object SmsCandidateFilter {
    private val amountPattern = Regex(
        """(?:inr|rs\.?|₹)\s*[\d][\d,]*(?:\.\d{1,2})?""",
        RegexOption.IGNORE_CASE,
    )

    private val blockedPhrases = listOf(
        "otp",
        "one time password",
        "one-time password",
        "verification code",
        "failed",
        "declined",
        "unsuccessful",
        "could not",
        "will be debited",
        "will get debited",
        "not a transaction",
    )

    private val debitWords = listOf(
        "debit",
        "debited",
        "spent",
        "withdrawn",
        "paid",
        "purchase",
        "sent",
    )

    private val creditWords = listOf(
        "credit",
        "credited",
        "received",
        "deposited",
        "refund",
    )

    private val bankSenderHints = listOf(
        "hdfc",
        "sbi",
        "icici",
        "axis",
        "kotak",
        "idfc",
        "pnb",
        "bob",
        "canara",
        "union",
        "yes",
        "indusind",
        "federal",
        "rbl",
        "paytm",
        "phonepe",
        "gpay",
        "googlepay",
        "amazonpay",
        "airtel",
        "jio",
        "vi",
        "bandhan",
        "citi",
        "hsbc",
        "scb",
        "dbs",
        "bank",
    )

    private val bankContextHints = listOf(
        "a/c",
        "ac no",
        "account",
        "card",
        "upi",
        "txn",
        "transaction",
        "ref no",
    )

    fun isCandidate(sender: String?, body: String?): Boolean {
        val text = body?.trim().orEmpty()
        if (text.isEmpty()) return false

        val lower = text.lowercase(Locale.ROOT)
        if (blockedPhrases.any(lower::contains)) return false
        if (!amountPattern.containsMatchIn(text)) return false

        val hasDebit = debitWords.any(lower::contains)
        val hasCredit = creditWords.any(lower::contains)
        if (!hasDebit && !hasCredit) return false

        val senderText = sender?.lowercase(Locale.ROOT).orEmpty()
        val hasBankSender = bankSenderHints.any(senderText::contains)
        val hasBankContext = bankContextHints.any(lower::contains)
        return hasBankSender || hasBankContext
    }
}
