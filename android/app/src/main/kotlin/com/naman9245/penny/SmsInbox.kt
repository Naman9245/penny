package com.naman9245.penny

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony
import android.util.Log
import org.json.JSONObject

/**
 * Bank SMS read straight from the phone's SMS, so one whose notification
 * was missed or cleared is still read. Only a bank's, wallet's or
 * investment's message with money in it is kept, in the waiting file;
 * every other SMS is passed over and never stored. Nothing leaves the
 * phone here.
 */
object SmsInbox {
    private const val TAG = "Penny"
    private const val PREFS = "penny_android"
    private const val LOOKED_UNTIL = "sms_looked_until"

    /** How far back the first look goes. */
    private const val FIRST_LOOK_MS = 2L * 24 * 60 * 60 * 1000

    /** Whether the user let Penny receive and read SMS. */
    fun allowed(context: Context): Boolean =
        listOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS).all {
            context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }

    /**
     * Queues the SMS [body] from [sender], received [at], if it may be a
     * payment. Whether it was new.
     */
    fun keep(context: Context, sender: String, body: String, at: Long): Boolean {
        if (!MoneyFilter.looksLikeMoney(body)) return false
        if (!MoneyFilter.fromMoneySender(sender, body)) return false
        return CaptureQueue.add(
            context,
            JSONObject()
                .put("app", "sms")
                .put("title", sender)
                .put("text", body)
                .put("at", at),
        )
    }

    /**
     * Looks at the SMS that came since the last look (the first time, the
     * last two days) and queues the payments among them. How many were new.
     */
    @Synchronized
    fun lookAgain(context: Context): Int {
        if (!allowed(context)) return 0
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val since = prefs.getLong(LOOKED_UNTIL, System.currentTimeMillis() - FIRST_LOOK_MS)
        var newest = since
        var kept = 0
        try {
            context.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} ASC",
            )?.use { rows ->
                while (rows.moveToNext()) {
                    val date = rows.getLong(2)
                    if (date > newest) newest = date
                    if (keep(context, rows.getString(0).orEmpty(), rows.getString(1).orEmpty(), date)) {
                        kept++
                    }
                }
            }
        } catch (e: RuntimeException) {
            Log.e(TAG, "Couldn't look at the SMS", e)
            return kept
        }
        prefs.edit().putLong(LOOKED_UNTIL, newest).apply()
        if (kept > 0) Log.i(TAG, "Found $kept new money SMS")
        return kept
    }
}
