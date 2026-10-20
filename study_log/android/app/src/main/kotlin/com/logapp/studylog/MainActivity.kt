package com.logapp.studylog

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.logapp.studylog/share"
    private var initialSharedText: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (Intent.ACTION_SEND == intent.action && intent.type?.startsWith("text/") == true) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrBlank()) {
                val channel = methodChannel
                if (channel != null) {
                    channel.invokeMethod("onSharedTextReceived", sharedText)
                } else {
                    initialSharedText = sharedText
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = initialSharedText
                    initialSharedText = null
                    result.success(text)
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val title = call.argument<String>("title") ?: "Share Course JSON"
                    val mimeType = call.argument<String>("mimeType") ?: "application/json"
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val contentUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, contentUri)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooserIntent = Intent.createChooser(sendIntent, title).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(chooserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.localizedMessage ?: "Failed to open file share", null)
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: "Share Course JSON"
                    try {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                        }
                        val chooserIntent = Intent.createChooser(sendIntent, title)
                        startActivity(chooserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.localizedMessage ?: "Failed to open share", null)
                    }
                }
                "openUrl" -> {
                    val rawUrl = call.argument<String>("url") ?: ""
                    try {
                        val formattedUrl = if (rawUrl.startsWith("http://") || rawUrl.startsWith("https://")) {
                            rawUrl
                        } else {
                            "https://$rawUrl"
                        }
                        val browserIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(formattedUrl)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(browserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("URL_ERROR", e.localizedMessage ?: "Failed to open URL", null)
                    }
                }
                "sendToBackground" -> {
                    try {
                        moveTaskToBack(true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BACKGROUND_ERROR", e.localizedMessage ?: "Failed to move task to back", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
