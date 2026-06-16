package com.pradeepapp.log

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pradeepapp.log/sms_scanner")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSmsScannerEnabled") {
                    val enabled = call.arguments as? Boolean ?: false
                    val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("sms_scanner_enabled", enabled).apply()
                    result.success(null)
                } else if (call.method == "openNotificationListenerSettings") {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not open settings: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
