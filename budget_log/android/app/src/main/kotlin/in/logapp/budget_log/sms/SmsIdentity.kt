package `in`.logapp.budget_log.sms

import java.security.MessageDigest

object SmsIdentity {
    fun sourceKey(sender: String?, timestamp: Long, body: String?): String {
        val normalizedSender = sender?.trim()?.lowercase().orEmpty()
        val normalizedBody = body?.trim().orEmpty()
        val input = "$normalizedSender|$timestamp|$normalizedBody"
        val digest = MessageDigest.getInstance("SHA-1")
            .digest(input.toByteArray(Charsets.UTF_8))
        val hex = buildString(digest.size * 2) {
            digest.forEach { byte ->
                append("%02x".format(byte.toInt() and 0xff))
            }
        }
        return "sms_$hex"
    }
}
