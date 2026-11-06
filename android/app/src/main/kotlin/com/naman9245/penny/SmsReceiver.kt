package com.naman9245.penny

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * Each SMS as it arrives, handed over by Android once the user lets Penny
 * receive SMS, even while she's closed. A bank's money message is queued
 * and read; any other is passed over at once.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // A long SMS comes in parts.
        var kept = 0
        for ((sender, pieces) in parts.filterNotNull().groupBy { it.displayOriginatingAddress.orEmpty() }) {
            val body = pieces.joinToString("") { it.displayMessageBody.orEmpty() }
            val at = pieces.first().timestampMillis
            if (SmsInbox.keep(context, sender, body, at)) kept++
        }
        if (kept > 0) {
            // What's logged says what happened, never what an SMS said.
            Log.i("Penny", "Kept $kept SMS as it came")
            BackgroundReader.wake(context)
        }
    }
}
