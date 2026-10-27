package `in`.logapp.budget_log.sms

import java.text.NumberFormat
import java.util.Locale

object SmsAmountParser {
    private val currencyAmount = Regex(
        "(?:inr|rs\\.?|₹)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE,
    )
    private val actionAmount = Regex(
        "(?:debited|credited|spent|paid|received|withdrawn|deposited|purchase)" +
            "\\s+(?:by|with|for|of)?\\s*(?:inr|rs\\.?|₹)?\\s*" +
            "([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE,
    )
    private val debitWord = Regex(
        "\\b(?:debit(?:ed)?|spent|paid|withdrawn|purchase|sent)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val creditWord = Regex(
        "\\b(?:credit(?:ed)?|received|deposited|refund(?:ed)?)\\b",
        RegexOption.IGNORE_CASE,
    )

    data class AmountInfo(
        val amount: Double?,
        val direction: String?,
    )

    fun parse(body: String): AmountInfo {
        val amountMatch = currencyAmount.find(body) ?: actionAmount.find(body)
        val amount = amountMatch?.groupValues?.getOrNull(1)
            ?.replace(",", "")
            ?.toDoubleOrNull()
            ?.takeIf { it > 0 }
        return AmountInfo(amount = amount, direction = direction(body))
    }

    fun format(amount: Double): String {
        val formatter = NumberFormat.getNumberInstance(
            Locale.forLanguageTag("en-IN"),
        ).apply {
            maximumFractionDigits = 2
            minimumFractionDigits = 0
        }
        return "₹${formatter.format(amount)}"
    }

    private fun direction(body: String): String? {
        val debit = debitWord.find(body)
        val credit = creditWord.find(body)
        if (debit == null && credit == null) return null
        if (debit != null && credit != null) {
            return if (debit.range.first <= credit.range.first) "debit" else "credit"
        }
        return if (debit != null) "debit" else "credit"
    }
}
