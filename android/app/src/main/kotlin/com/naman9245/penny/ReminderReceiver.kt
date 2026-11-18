package com.naman9245.penny

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Shows one autopay reminder when its alarm goes off. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(TITLE) ?: return
        PennyNotifier.remind(
            context,
            intent.getIntExtra(ID, 0),
            title,
            intent.getStringExtra(TEXT).orEmpty(),
        )
    }

    companion object {
        const val ID = "id"
        const val TITLE = "title"
        const val TEXT = "text"
    }
}
