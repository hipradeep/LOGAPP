package `in`.logapp.budget_log

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import `in`.logapp.budget_log.sms.SmsBridge

class MainActivity : FlutterActivity() {
    private var smsBridge: SmsBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger).also {
            it.handleIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        smsBridge?.handleIntent(intent)
    }

    override fun onDestroy() {
        smsBridge?.dispose()
        smsBridge = null
        super.onDestroy()
    }
}
