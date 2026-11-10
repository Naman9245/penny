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

    private const val DAY_MS = 24L * 60 * 60 * 1000

    /** How far back the first look goes: three months, so Penny starts full. */
    private const val FIRST_LOOK_MS = 90 * DAY_MS

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
     * last three months) and queues the payments among them. How many were
     * new.
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

    /**
     * Looks at the SMS from the last [days] days, after [after] when given,
     * oldest first, and queues the money ones not queued before, stopping
     * once [most] are: what Penny already knows is skipped. Says how many
     * were queued, the date of the last SMS looked at, and whether there
     * are no more, so the app reads each batch before asking for the next.
     */
    @Synchronized
    fun lookBack(context: Context, days: Int, after: Long?, most: Int): Map<String, Any?> {
        if (!allowed(context)) return mapOf("kept" to 0, "until" to null, "done" to true)
        val since = maxOf(System.currentTimeMillis() - days * DAY_MS, after ?: 0L)
        var until: Long? = null
        var kept = 0
        var done = true
        try {
            context.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} ASC",
            )?.use { rows ->
                while (rows.moveToNext()) {
                    if (kept >= most) {
                        done = false
                        break
                    }
                    val date = rows.getLong(2)
                    until = date
                    if (keep(context, rows.getString(0).orEmpty(), rows.getString(1).orEmpty(), date)) {
                        kept++
                    }
                }
            }
        } catch (e: RuntimeException) {
            Log.e(TAG, "Couldn't look back at the SMS", e)
        }
        // What's looked at needn't be looked at again.
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val looked = prefs.getLong(LOOKED_UNTIL, 0L)
        until?.let { if (it > looked) prefs.edit().putLong(LOOKED_UNTIL, it).apply() }
        if (kept > 0) Log.i(TAG, "Found $kept older money SMS")
        return mapOf("kept" to kept, "until" to until, "done" to done)
    }
}
