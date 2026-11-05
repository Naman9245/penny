package com.naman9245.penny

import android.app.Notification
import android.os.Bundle
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject

/**
 * Reads the notifications of a few apps only: the phone's SMS app, GPay,
 * PhonePe and Paytm. One that mentions money waits in Penny's private
 * storage, as its title, text and time, until Penny takes it to read. Every
 * other notification is ignored as it arrives. Nothing is parsed here, and
 * nothing leaves the phone.
 *
 * Android runs this only once the user allows Penny on its Notification
 * access page.
 */
class PaymentNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val notification = sbn.notification ?: return
        // A group's summary repeats what its notifications already say.
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val app = appOf(sbn.packageName) ?: return
        val extras = notification.extras ?: return
        val title = (extras.getCharSequence(Notification.EXTRA_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE))
            ?.toString().orEmpty()
        var kept = false
        for ((text, at) in textsOf(extras, sbn.postTime)) {
            if (!MONEY.containsMatchIn("$title $text")) continue
            CaptureQueue.add(
                this,
                JSONObject()
                    .put("app", app)
                    .put("title", title)
                    .put("text", text)
                    .put("at", at),
            )
            kept = true
        }
        if (kept) BackgroundReader.wake(this)
    }

    /** Which of the apps Penny reads [pkg] is, or null for any other. */
    private fun appOf(pkg: String): String? = when (pkg) {
        GPAY -> "gpay"
        PHONEPE -> "phonepe"
        PAYTM -> "paytm"
        // Test notifications, which only a computer over USB can post.
        SHELL -> "sms"
        in SMS_APPS -> "sms"
        else -> if (pkg == Telephony.Sms.getDefaultSmsPackage(this)) "sms" else null
    }

    /** Each message the notification carries, with when it came. */
    private fun textsOf(extras: Bundle, posted: Long): List<Pair<String, Long>> {
        // A Messages app shows a conversation: every message in it, newest
        // last.
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (!messages.isNullOrEmpty()) {
            return messages.mapNotNull { message ->
                val bundle = message as? Bundle ?: return@mapNotNull null
                val text = bundle.getCharSequence("text")?.toString()
                    ?: return@mapNotNull null
                text to bundle.getLong("time", posted)
            }
        }
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (!lines.isNullOrEmpty()) return lines.map { it.toString() to posted }
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()
        return if (text.isNullOrBlank()) emptyList() else listOf(text to posted)
    }

    companion object {
        private const val GPAY = "com.google.android.apps.nbu.paisa.user"
        private const val PHONEPE = "com.phonepe.app"
        private const val PAYTM = "net.one97.paytm"
        private const val SHELL = "com.android.shell"

        /** Messages apps, in case the phone doesn't say which is its own. */
        private val SMS_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.android.messaging",
            "com.oneplus.mms",
            "com.samsung.android.messaging",
        )

        /** ₹, Rs or INR next to a number, either way round. */
        private val MONEY = Regex(
            """(?:₹|\brs\.?|\binr)\s*\d|\d\s*(?:₹|rs\b|inr\b)""",
            RegexOption.IGNORE_CASE,
        )
    }
}
