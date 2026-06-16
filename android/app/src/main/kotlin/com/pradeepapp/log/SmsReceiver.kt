package com.pradeepapp.log

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {
    private val TAG = "SmsReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val body = sms.messageBody ?: continue
                val sender = sms.originatingAddress ?: "Alert"
                Log.d(TAG, "Received SMS from $sender: $body")
                
                processSms(context, sender, body)
            }
        }
    }

    private fun processSms(context: Context, sender: String, body: String) {
        val lowerBody = body.lowercase()
        
        // 1. Check if it is a transaction text and not promo
        if (!isTransactionText(lowerBody) || isPromotional(lowerBody)) {
            Log.d(TAG, "SMS is not a transaction or is promotional. Skipping.")
            return
        }

        // 2. Extract amount
        val amount = extractAmount(body) ?: return
        if (amount <= 0) return

        // 3. Determine if credit or debit
        val isCredit = isCreditText(lowerBody)
        val description = extractDescription(lowerBody, sender)
        val tag = getTagForDescription(description)

        Log.d(TAG, "Transaction Intercepted: Rs. $amount, isCredit=$isCredit, tag=$tag, desc=$description")

        try {
            // Ensure Firebase is initialized
            if (FirebaseApp.getApps(context).isEmpty()) {
                FirebaseApp.initializeApp(context)
            }

            val db = FirebaseFirestore.getInstance()

            // Fetch active budget (checked = true)
            db.collection("budgets")
                .whereEqualTo("checked", true)
                .limit(1)
                .get()
                .addOnSuccessListener { querySnapshot ->
                    val doc = querySnapshot.documents.firstOrNull()
                    val budgetId = doc?.id ?: ""
                    
                    if (budgetId.isEmpty()) {
                        Log.d(TAG, "No active budget found. Skipping transaction save.")
                        return@addOnSuccessListener
                    }
                    
                    // Create transaction document
                    val transactionData = hashMapOf(
                        "budgetId" to budgetId,
                        "tag" to tag,
                        "description" to description,
                        "amount" to if (isCredit) -amount else amount,
                        "entryDate" to com.google.firebase.Timestamp.now(),
                        "expenseDate" to com.google.firebase.Timestamp.now(),
                        "isValidated" to false,
                        "rawBody" to "SMS: $sender: $body"
                    )

                    db.collection("transactions").add(transactionData)
                        .addOnSuccessListener {
                            Log.d(TAG, "Successfully auto-logged transaction from SMS to Firestore.")
                        }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "Error inserting SMS transaction: ${e.message}")
                        }
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "Error getting active budget: ${e.message}")
                }
        } catch (e: Exception) {
            Log.e(TAG, "Firebase operation failed: ${e.message}")
        }
    }

    private fun isTransactionText(body: String): Boolean {
        return body.contains("rs.") ||
                body.contains("inr") ||
                body.contains("₹") ||
                body.contains("debited") ||
                body.contains("credited") ||
                body.contains("spent") ||
                body.contains("paid") ||
                body.contains("purchase") ||
                body.contains("withdrawal") ||
                body.contains("withdrawn") ||
                body.contains("transfer") ||
                body.contains("transaction") ||
                body.contains("trf") ||
                body.contains("ref no") ||
                body.contains("utr")
    }

    private fun isPromotional(body: String): Boolean {
        return body.contains("personal loan") ||
                body.contains("pre-approved") ||
                body.contains("apply now") ||
                body.contains("exclusive offer") ||
                body.contains("demat") ||
                body.contains("mutual fund") ||
                body.contains("fixed deposit")
    }

    private fun isCreditText(body: String): Boolean {
        if (body.contains("debited")) return false
        return body.contains("credited") ||
                body.contains("received") ||
                body.contains("deposited") ||
                body.contains("refund") ||
                body.contains("cashback")
    }

    private fun extractAmount(body: String): Double? {
        val patterns = arrayOf(
            Pattern.compile("rs\\.?\\s*([\\d,]+\\.?\\d*)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("inr\\s*([\\d,]+\\.?\\d*)", Pattern.CASE_INSENSITIVE),
            Pattern.compile("₹\\s*([\\d,]+\\.?\\d*)"),
            Pattern.compile("([\\d,]+\\.?\\d*)\\s*(rs|inr)", Pattern.CASE_INSENSITIVE)
        )
        for (pattern in patterns) {
            val matcher = pattern.matcher(body)
            if (matcher.find()) {
                val clean = matcher.group(1)?.replace(",", "")
                val parsed = clean?.toDoubleOrNull()
                if (parsed != null && parsed > 0) return parsed
            }
        }
        return null
    }

    private fun extractDescription(body: String, sender: String): String {
        val keywords = mapOf(
            "Bill" to arrayOf("bill", "recharge", "electricity", "water", "internet", "dth", "broadband"),
            "Dinner" to arrayOf("restaurant", "cafe", "dinner", "lunch", "food", "zomato", "swiggy", "eat"),
            "Drink" to arrayOf("drink", "bar", "coffee", "tea", "chai", "starbucks"),
            "Fuel" to arrayOf("fuel", "petrol", "diesel", "gas"),
            "Grocery" to arrayOf("grocery", "supermarket", "dmart", "blinkit", "zepto", "instamart", "blinkit"),
            "Shopping" to arrayOf("amazon", "flipkart", "myntra", "shopping", "meesho", "ajio"),
            "Travel" to arrayOf("flight", "train", "uber", "ola", "metro", "cab")
        )
        val lower = body.lowercase()
        for ((key, words) in keywords) {
            for (word in words) {
                if (lower.contains(word)) return "$key - $sender"
            }
        }
        return sender
    }

    private fun getTagForDescription(desc: String): String {
        val lower = desc.lowercase()
        val tags = arrayOf("Bill", "Dinner", "Drink", "Fuel", "Grocery", "Shopping", "Travel")
        for (tag in tags) {
            if (lower.contains(tag.lowercase())) return tag
        }
        return "Other"
    }
}
