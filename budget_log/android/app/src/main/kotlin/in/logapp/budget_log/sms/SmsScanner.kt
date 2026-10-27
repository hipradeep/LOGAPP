package `in`.logapp.budget_log.sms

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.content.ContextCompat

object SmsScanner {
    private const val DAY_MILLIS = 24L * 60L * 60L * 1000L

    fun scan(
        context: Context,
        days: Int = 30,
        limit: Int = 500,
    ): List<SmsRecord> {
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_SMS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("READ_SMS permission is required")
        }

        val safeDays = days.coerceIn(1, 365)
        val safeLimit = limit.coerceIn(1, 1000)
        val cutoff = System.currentTimeMillis() - (safeDays * DAY_MILLIS)
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )

        val records = mutableListOf<SmsRecord>()
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(cutoff.toString()),
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)

            while (cursor.moveToNext() && records.size < safeLimit) {
                val body = cursor.getString(bodyIndex)?.trim().orEmpty()
                if (body.isEmpty()) continue

                val sender = cursor.getString(addressIndex)?.trim().orEmpty()
                val timestamp = cursor.getLong(dateIndex)
                val providerId = cursor.getString(idIndex)
                records.add(
                    SmsRecord(
                        sourceKey = SmsIdentity.sourceKey(sender, timestamp, body),
                        sender = sender,
                        body = body,
                        timestamp = timestamp,
                        providerId = providerId,
                    ),
                )
            }
        }
        return records
    }
}
