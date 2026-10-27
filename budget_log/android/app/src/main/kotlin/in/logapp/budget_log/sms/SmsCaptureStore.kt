package `in`.logapp.budget_log.sms

import android.content.Context
import org.json.JSONObject
import java.io.File

object SmsCaptureStore {
    private const val FILE_NAME = "sms_capture.jsonl"
    private const val MAX_RECORDS = 200
    private val lock = Any()

    fun append(context: Context, record: SmsRecord) {
        synchronized(lock) {
            val file = captureFile(context)
            val line = JSONObject()
                .put("sourceKey", record.sourceKey)
                .put("sender", record.sender)
                .put("body", record.body)
                .put("timestamp", record.timestamp)
                .put("providerId", record.providerId)
                .toString()

            val lines = if (file.exists()) file.readLines() else emptyList()
            val trimmed = (lines + line).takeLast(MAX_RECORDS)
            file.parentFile?.mkdirs()
            file.writeText(trimmed.joinToString("\n", postfix = "\n"))
        }
    }

    fun drain(context: Context): List<SmsRecord> {
        synchronized(lock) {
            val file = captureFile(context)
            if (!file.exists()) return emptyList()
            val lines = file.readLines()
            file.delete()
            return lines.mapNotNull(::parseRecord)
        }
    }

    private fun captureFile(context: Context): File =
        File(context.noBackupFilesDir, FILE_NAME)

    private fun parseRecord(line: String): SmsRecord? {
        if (line.isBlank()) return null
        return try {
            val json = JSONObject(line)
            SmsRecord(
                sourceKey = json.optString("sourceKey"),
                sender = json.optString("sender"),
                body = json.optString("body"),
                timestamp = json.optLong("timestamp"),
                providerId = json.optString("providerId").takeIf { it.isNotEmpty() },
            )
        } catch (_: Exception) {
            null
        }
    }
}
