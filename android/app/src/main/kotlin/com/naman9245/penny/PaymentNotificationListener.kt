package com.naman9245.penny

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.util.Log
import android.service.notification.StatusBarNotification
import org.json.JSONObject

/**
 * Reads the notifications of a few apps only: the phone's SMS app, GPay,
 * PhonePe, Paytm, and the wallet and investing apps in
 * [WALLETS_AND_INVESTING]. One that mentions money waits in Penny's private
 * storage, as its title, text and time, until Penny takes it to read. Every
 * other notification is ignored as it arrives. Nothing is parsed here, and
 * nothing leaves the phone.
 *
 * Android runs this only once the user allows Penny on its Notification
 * access page.
 */
class PaymentNotificationListener : NotificationListenerService() {

    // What's logged says what happened, never what a notification said.
    override fun onListenerConnected() {
        Log.i(TAG, "Listening for payment notifications")
        connected = this
        // Android doesn't replay what came while the listener was down
        // (some phones stop it every few minutes), so look at what's still
        // showing.
        catchUp()
    }

    override fun onListenerDisconnected() {
        if (connected === this) connected = null
        Log.i(TAG, "Disconnected: asking to listen again")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, PaymentNotificationListener::class.java))
        }
    }

    override fun onDestroy() {
        if (connected === this) connected = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val app = keep(sbn) ?: return
        Log.i(TAG, "Kept a notification from $app")
        BackgroundReader.wake(this)
    }

    /** Queues the payment notifications still showing. How many were new. */
    private fun catchUp(): Int {
        val showing = try {
            activeNotifications
        } catch (e: RuntimeException) {
            null
        } ?: return 0
        val kept = showing.count { keep(it) != null }
        if (kept > 0) {
            Log.i(TAG, "Caught up on $kept notification(s) still showing")
            BackgroundReader.wake(this)
        }
        return kept
    }

    /**
     * Queues what in [sbn] looks like a payment, if it's from an app Penny
     * reads and wasn't queued lately. The app's name when anything was.
     */
    private fun keep(sbn: StatusBarNotification): String? {
        val notification = sbn.notification ?: return null
        // A group's summary repeats what its notifications already say.
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return null
        val app = appOf(sbn.packageName) ?: return null
        val extras = notification.extras ?: return null
        val title = (extras.getCharSequence(Notification.EXTRA_TITLE)
            ?: extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE))
            ?.toString().orEmpty()
        var kept = false
        for ((text, at) in textsOf(extras, sbn.postTime)) {
            if (!MONEY.containsMatchIn("$title $text")) continue
            val added = CaptureQueue.add(
                this,
                JSONObject()
                    .put("app", app)
                    .put("title", title)
                    .put("text", text)
                    .put("at", at),
            )
            kept = kept || added
        }
        return if (kept) app else null
    }

    /** Which of the apps Penny reads [pkg] is, or null for any other. */
    private fun appOf(pkg: String): String? = when (pkg) {
        GPAY -> "gpay"
        PHONEPE -> "phonepe"
        PAYTM -> "paytm"
        in WALLETS_AND_INVESTING -> WALLETS_AND_INVESTING[pkg]
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
        private const val TAG = "Penny"

        /** The listener while Android has it connected. */
        @Volatile
        private var connected: PaymentNotificationListener? = null

        /**
         * Queues the payment notifications still showing, as Penny opens.
         * How many were new; 0 while the listener isn't connected. On the
         * main thread.
         */
        fun catchUpNow(): Int = connected?.catchUp() ?: 0
        private const val GPAY = "com.google.android.apps.nbu.paisa.user"
        private const val PHONEPE = "com.phonepe.app"
        private const val PAYTM = "net.one97.paytm"
        private const val SHELL = "com.android.shell"

        /** Wallet and investing apps, by package, as Dart names them. */
        private val WALLETS_AND_INVESTING = mapOf(
            "com.hdfcbank.payzapp" to "payzapp",
            "com.mobikwik_new" to "mobikwik",
            "com.dreamplug.androidapp" to "cred",
            "in.org.npci.upiapp" to "bhim",
            "money.super.payments" to "supermoney",
            "com.nextbillion.groww" to "groww",
            "com.zerodha.kite3" to "kite",
            "in.upstox.app" to "upstox",
            "in.indwealth" to "indmoney",
            "com.paytmmoney" to "paytmmoney",
        )

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
