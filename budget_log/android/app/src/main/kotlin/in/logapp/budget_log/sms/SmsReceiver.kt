package `in`.logapp.budget_log.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!SmsValidationScheduler.isBackgroundEnabled(context)) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val sender = messages.firstOrNull()?.originatingAddress.orEmpty()
            val body = messages.joinToString(separator = "") {
                it.messageBody.orEmpty()
            }.trim()
            if (body.isEmpty()) return
            if (!SmsCandidateFilter.isCandidate(sender, body)) return

            val timestamp = messages.first().timestampMillis
            val record = SmsRecord(
                sourceKey = SmsIdentity.sourceKey(sender, timestamp, body),
                sender = sender,
                body = body,
                timestamp = timestamp,
                providerId = null,
            )
            val amountInfo = SmsAmountParser.parse(body)
            SmsCaptureStore.append(context, record)
            SmsValidationScheduler.enqueue(
                context,
                SmsValidationItem(
                    id = record.sourceKey,
                    kind = "candidate",
                    amount = amountInfo.amount,
                    direction = amountInfo.direction,
                    title = sender,
                ),
            )
        } catch (_: Exception) {
            // A malformed PDU must never crash the receiver.
        }
    }
}
