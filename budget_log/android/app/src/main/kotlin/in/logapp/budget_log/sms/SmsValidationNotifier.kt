package `in`.logapp.budget_log.sms

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import `in`.logapp.budget_log.MainActivity
import `in`.logapp.budget_log.R

object SmsValidationNotifier {
    const val CHANNEL_ID = "budget_sms_validation"
    const val NOTIFICATION_ID = 7401
    const val EXTRA_VALIDATION_ID = "sms_validation_id"
    const val EXTRA_VALIDATION_KIND = "sms_validation_kind"
    const val EXTRA_VALIDATION_ACTION = "sms_validation_action"
    const val ACTION_VALIDATE = "validate"
    const val ACTION_IGNORE = "ignore"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SMS transaction validation",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Prompts to review credit and debit transactions found in SMS."
        }
        manager.createNotificationChannel(channel)
    }

    fun canNotify(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun show(context: Context, item: SmsValidationItem): Boolean {
        if (!canNotify(context)) return false
        ensureChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_VALIDATION_ID, item.id)
            putExtra(EXTRA_VALIDATION_KIND, item.kind)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            item.id.hashCode(),
            intent,
            pendingIntentFlags(),
        )

        val validateIntent = validationActionIntent(context, item, ACTION_VALIDATE)
        val ignoreIntent = validationActionIntent(context, item, ACTION_IGNORE)
        val requestBase = item.id.hashCode() and 0x7FFFFFFF
        val validatePendingIntent = PendingIntent.getActivity(
            context,
            requestBase + 1,
            validateIntent,
            pendingIntentFlags(),
        )
        val ignorePendingIntent = PendingIntent.getActivity(
            context,
            requestBase + 2,
            ignoreIntent,
            pendingIntentFlags(),
        )

        val direction = when (item.direction) {
            "credit" -> "credited"
            "debit" -> "debited"
            else -> null
        }
        val amount = item.amount
        val title = if (amount != null) {
            listOfNotNull(SmsAmountParser.format(amount), direction).joinToString(" ")
        } else {
            "Transaction needs review"
        }
        val details = item.title?.takeIf { it.isNotBlank() }
        val content = if (details != null) {
            "$details · Tap to validate."
        } else {
            "Tap to validate."
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_budget)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setContentIntent(pendingIntent)
            .addAction(R.drawable.ic_stat_budget, "Validate", validatePendingIntent)
            .addAction(R.drawable.ic_stat_budget, "Ignore", ignorePendingIntent)
            .build()

        return try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun validationActionIntent(
        context: Context,
        item: SmsValidationItem,
        action: String,
    ): Intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(EXTRA_VALIDATION_ID, item.id)
        putExtra(EXTRA_VALIDATION_KIND, item.kind)
        putExtra(EXTRA_VALIDATION_ACTION, action)
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }
}
