package `in`.logapp.budget_log.sms

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object SmsValidationScheduler {
    const val ALARM_ACTION = "in.logapp.budget_log.SMS_VALIDATION_ALARM"
    const val GAP_MS = 10L * 60L * 1000L

    private const val PREFS = "sms_validation_prefs"
    private const val KEY_QUEUE = "queue"
    private const val KEY_LAST_SHOWN = "last_shown"
    private const val KEY_CURRENT_ID = "current_id"
    private const val KEY_CURRENT_KIND = "current_kind"
    private const val KEY_BACKGROUND_ENABLED = "background_enabled"
    private const val ALARM_REQUEST_CODE = 7301

    private val lock = Any()

    fun isBackgroundEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_BACKGROUND_ENABLED, true)

    fun setBackgroundEnabled(context: Context, enabled: Boolean) {
        synchronized(lock) {
            prefs(context).edit().putBoolean(KEY_BACKGROUND_ENABLED, enabled).apply()
            if (!enabled) {
                val items = loadQueue(context)
                val currentKind = prefs(context).getString(KEY_CURRENT_KIND, null)
                val kept = items.filterNot { it.kind == "candidate" }.toMutableList()
                saveQueue(context, kept)
                if (currentKind == "candidate") {
                    SmsValidationNotifier.cancel(context)
                    clearCurrent(context)
                }
                refreshSchedule(context, kept)
            }
        }
    }

    fun enqueue(context: Context, item: SmsValidationItem) {
        synchronized(lock) {
            val items = loadQueue(context)
            val existingIndex = items.indexOfFirst { it.id == item.id }
            if (existingIndex >= 0) {
                items[existingIndex] = merge(existing = items[existingIndex], incoming = item)
            } else {
                items.add(item)
            }
            saveQueue(context, items)
            ensureScheduled(context, items)
        }
    }

    fun syncPendingValidations(context: Context, pending: List<SmsValidationItem>) {
        synchronized(lock) {
            val items = loadQueue(context)
            val incomingById = pending.associateBy { it.id }
            val kept = items
                .filter { item -> item.kind != "staged" || incomingById.containsKey(item.id) }
                .map { item -> incomingById[item.id]?.let { merge(item, it) } ?: item }
                .toMutableList()

            for (item in pending) {
                if (kept.none { it.id == item.id }) {
                    kept.add(item.copy(kind = "staged"))
                }
            }

            saveQueue(context, kept)
            val currentId = prefs(context).getString(KEY_CURRENT_ID, null)
            if (currentId != null && kept.none { it.id == currentId }) {
                SmsValidationNotifier.cancel(context)
                clearCurrent(context)
            }
            refreshSchedule(context, kept)
        }
    }

    fun removeValidation(context: Context, id: String) {
        synchronized(lock) {
            val kept = loadQueue(context).filterNot { it.id == id }.toMutableList()
            saveQueue(context, kept)
            if (prefs(context).getString(KEY_CURRENT_ID, null) == id) {
                SmsValidationNotifier.cancel(context)
                clearCurrent(context)
            }
            refreshSchedule(context, kept)
        }
    }

    fun restore(context: Context) {
        synchronized(lock) {
            SmsValidationNotifier.ensureChannel(context)
            val items = loadQueue(context)
            refreshSchedule(context, items)
        }
    }

    fun showNext(context: Context) {
        synchronized(lock) {
            val items = loadQueue(context)
            if (items.isEmpty()) {
                SmsValidationNotifier.cancel(context)
                clearCurrent(context)
                prefs(context).edit().putLong(KEY_LAST_SHOWN, 0L).apply()
                cancelAlarm(context)
                return
            }

            if (!SmsValidationNotifier.canNotify(context)) {
                cancelAlarm(context)
                return
            }

            val item = items.removeAt(0)
            items.add(item)
            saveQueue(context, items)
            prefs(context).edit()
                .putLong(KEY_LAST_SHOWN, System.currentTimeMillis())
                .putString(KEY_CURRENT_ID, item.id)
                .putString(KEY_CURRENT_KIND, item.kind)
                .apply()

            if (SmsValidationNotifier.show(context, item)) {
                scheduleAlarm(context, GAP_MS)
            } else {
                cancelAlarm(context)
            }
        }
    }

    private fun ensureScheduled(
        context: Context,
        items: List<SmsValidationItem>,
    ) {
        if (items.isEmpty()) {
            cancelAlarm(context)
            return
        }
        val now = System.currentTimeMillis()
        val lastShown = prefs(context).getLong(KEY_LAST_SHOWN, 0L)
        val delay = if (lastShown <= 0L) {
            0L
        } else {
            (lastShown + GAP_MS - now).coerceAtLeast(0L)
        }
        scheduleAlarm(context, delay)
    }

    private fun refreshSchedule(
        context: Context,
        items: List<SmsValidationItem>,
    ) {
        if (items.isEmpty()) {
            SmsValidationNotifier.cancel(context)
            clearCurrent(context)
            prefs(context).edit().putLong(KEY_LAST_SHOWN, 0L).apply()
            cancelAlarm(context)
        } else {
            ensureScheduled(context, items)
        }
    }

    private fun scheduleAlarm(context: Context, delayMs: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = System.currentTimeMillis() + delayMs
        val pendingIntent = alarmPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(alarmPendingIntent(context))
    }

    private fun alarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, SmsValidationAlarmReceiver::class.java)
            .setAction(ALARM_ACTION)
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            pendingIntentFlags(),
        )
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun clearCurrent(context: Context) {
        prefs(context).edit()
            .remove(KEY_CURRENT_ID)
            .remove(KEY_CURRENT_KIND)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun merge(
        existing: SmsValidationItem,
        incoming: SmsValidationItem,
    ): SmsValidationItem = SmsValidationItem(
        id = existing.id,
        kind = incoming.kind,
        amount = incoming.amount ?: existing.amount,
        direction = incoming.direction ?: existing.direction,
        title = incoming.title ?: existing.title,
    )

    private fun loadQueue(context: Context): MutableList<SmsValidationItem> {
        val raw = prefs(context).getString(KEY_QUEUE, null) ?: return mutableListOf()
        return try {
            val array = JSONArray(raw)
            val items = mutableListOf<SmsValidationItem>()
            for (index in 0 until array.length()) {
                val json = array.optJSONObject(index) ?: continue
                val id = json.optString("id")
                val kind = json.optString("kind", "staged")
                if (id.isEmpty()) continue
                items.add(
                    SmsValidationItem(
                        id = id,
                        kind = kind,
                        amount = json.optDouble("amount", Double.NaN).takeUnless { it.isNaN() },
                        direction = json.optString("direction").takeIf { it.isNotEmpty() },
                        title = json.optString("title").takeIf { it.isNotEmpty() },
                    ),
                )
            }
            items
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun saveQueue(context: Context, items: List<SmsValidationItem>) {
        val array = JSONArray()
        for (item in items) {
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("kind", item.kind)
                    .putOpt("amount", item.amount)
                    .putOpt("direction", item.direction)
                    .putOpt("title", item.title),
            )
        }
        prefs(context).edit().putString(KEY_QUEUE, array.toString()).apply()
    }
}
