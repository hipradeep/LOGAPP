package `in`.logapp.budget_log.sms

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var pendingTarget: Map<String, Any>? = null

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
        eventChannel.setStreamHandler(this)
    }

    fun handleIntent(intent: Intent?) {
        val id = intent?.getStringExtra(SmsValidationNotifier.EXTRA_VALIDATION_ID)
            ?.takeIf { it.isNotBlank() }
            ?: return
        val kind = intent.getStringExtra(SmsValidationNotifier.EXTRA_VALIDATION_KIND)
            ?.takeIf { it.isNotBlank() }
            ?: "staged"
        val target = mapOf("id" to id, "kind" to kind)
        pendingTarget = target
        emitPendingTarget()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emitPendingTarget()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        pendingTarget = null
    }

    private fun emitPendingTarget() {
        val sink = eventSink ?: return
        val target = pendingTarget ?: return
        sink.success(target)
        pendingTarget = null
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanInbox" -> {
                val days = call.argument<Int>("days") ?: 30
                val limit = call.argument<Int>("limit") ?: 500
                try {
                    val records = SmsScanner.scan(context, days, limit)
                    result.success(records.map { it.toMap() })
                } catch (error: SecurityException) {
                    result.error("permission_denied", error.message, null)
                } catch (error: Exception) {
                    result.error("scan_failed", error.message, null)
                }
            }

            "drainCaptured" -> {
                try {
                    result.success(SmsCaptureStore.drain(context).map { it.toMap() })
                } catch (error: Exception) {
                    result.error("capture_failed", error.message, null)
                }
            }

            "syncPendingValidations" -> {
                val ids = call.argument<List<*>>("ids")
                    ?.mapNotNull { it as? String }
                    ?.toSet()
                    .orEmpty()
                SmsValidationScheduler.syncPendingValidations(context, ids)
                result.success(true)
            }

            "removeValidation" -> {
                val id = call.argument<String>("id")
                if (id.isNullOrBlank()) {
                    result.error("invalid_id", "Validation id is required", null)
                } else {
                    SmsValidationScheduler.removeValidation(context, id)
                    result.success(true)
                }
            }

            "setBackgroundEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                SmsValidationScheduler.setBackgroundEnabled(context, enabled)
                result.success(true)
            }

            "getBackgroundEnabled" -> {
                result.success(SmsValidationScheduler.isBackgroundEnabled(context))
            }

            "getLaunchTarget" -> {
                val target = pendingTarget
                pendingTarget = null
                result.success(target)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "in.logapp.budget_log/sms"
        private const val EVENT_CHANNEL = "in.logapp.budget_log/sms_events"
    }
}
