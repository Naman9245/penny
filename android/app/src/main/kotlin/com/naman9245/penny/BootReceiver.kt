package com.naman9245.penny

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android forgets alarms when the phone restarts, and when Penny is
 * updated: this sets her autopay reminders again from the kept list.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> ReminderScheduler.restore(context)
        }
    }
}
