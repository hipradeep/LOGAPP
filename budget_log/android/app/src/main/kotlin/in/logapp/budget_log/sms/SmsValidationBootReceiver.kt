package `in`.logapp.budget_log.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsValidationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> SmsValidationScheduler.restore(context)
        }
    }
}
