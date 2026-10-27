package `in`.logapp.budget_log.sms

data class SmsRecord(
    val sourceKey: String,
    val sender: String,
    val body: String,
    val timestamp: Long,
    val providerId: String?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "sourceKey" to sourceKey,
        "sender" to sender,
        "body" to body,
        "timestamp" to timestamp,
        "providerId" to providerId,
    )
}

data class SmsValidationItem(
    val id: String,
    val kind: String,
    val amount: Double? = null,
    val direction: String? = null,
    val title: String? = null,
)
