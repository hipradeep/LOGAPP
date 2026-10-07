package com.logapp.studylog

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.logapp.studylog/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
