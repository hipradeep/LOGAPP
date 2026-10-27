package `in`.logapp.budget_log.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsValidationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != SmsValidationScheduler.ALARM_ACTION) return
        SmsValidationScheduler.showNext(context)
    }
}
