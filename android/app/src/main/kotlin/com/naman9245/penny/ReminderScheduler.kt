package com.naman9245.penny

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray

/**
 * Penny's autopay reminders, as Android alarms, so each comes at its time
 * even with Penny closed. Dart works them out; this only sets them. The
 * list is kept, so [BootReceiver] can set them again after a restart.
 */
object ReminderScheduler {
    private const val PREFS = "penny_reminders"
    private const val LIST = "list"

    /** Replaces the reminders with [json]: [{id, at, title, text}, …]. */
    fun schedule(context: Context, json: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        cancel(context, prefs.getString(LIST, null))
        prefs.edit().putString(LIST, json).apply()
        set(context, json)
    }

    /** Sets the kept reminders again, as after a restart or an update. */
    fun restore(context: Context) {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(LIST, null) ?: return
        set(context, json)
    }

    private fun set(context: Context, json: String) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val now = System.currentTimeMillis()
        val list = JSONArray(json)
        for (i in 0 until list.length()) {
            val item = list.getJSONObject(i)
            val at = item.getLong("at")
            if (at <= now) continue
            // Not exact to the minute: no special permission, and Android may
            // batch it a little to save battery.
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                at,
                intentFor(context, item.getInt("id"), item.getString("title"), item.getString("text")),
            )
        }
    }

    private fun cancel(context: Context, json: String?) {
        if (json == null) return
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val list = JSONArray(json)
        for (i in 0 until list.length()) {
            val item = list.getJSONObject(i)
            alarms.cancel(
                intentFor(context, item.getInt("id"), item.getString("title"), item.getString("text")),
            )
        }
    }

    private fun intentFor(context: Context, id: Int, title: String, text: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, ReminderReceiver::class.java)
                .putExtra(ReminderReceiver.ID, id)
                .putExtra(ReminderReceiver.TITLE, title)
                .putExtra(ReminderReceiver.TEXT, text),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
}
