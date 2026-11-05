package com.naman9245.penny

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * Penny's own notification about the payments she just read: one, updated
 * in place, on a channel of its own so the user can mute just these. Its
 * words come from Dart, which read the payments.
 */
object PennyNotifier {
    private const val CHANNEL = "payments_read"
    private const val ID = 1001

    /** Whether Penny may post notifications at all. */
    fun allowed(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Shows [title] and [text], with [lines] below when there are several. */
    fun notify(context: Context, title: String, text: String, lines: List<String>) {
        if (!allowed(context)) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Payments Penny read",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "When Penny reads a payment from a notification" },
            )
        }
        // Penny's Home, in the copy that's open if there is one.
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .putExtra(MainActivity.OPEN_HOME, true)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_penny)
            .setColor(0xFFFFD84D.toInt())
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setStyle(
                if (lines.isEmpty()) {
                    Notification.BigTextStyle().bigText(text)
                } else {
                    Notification.InboxStyle().also { style ->
                        lines.forEach { style.addLine(it) }
                        style.setSummaryText(text)
                    }
                },
            )
        manager.notify(ID, builder.build())
    }
}
