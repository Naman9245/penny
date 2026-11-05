package com.naman9245.penny

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands text shared to Penny (a bank SMS from the Messages app) to Dart over
 * the "penny/share" channel. The text is only passed along, never stored here.
 *
 * Over "penny/notifications" it also says whether Penny may read
 * notifications, opens Android's page to allow it, and hands Dart the
 * payment notifications [PaymentNotificationListener] kept.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // A share that started the app waits here until Dart asks for it.
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = takeSharedText(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, "penny/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
        notifications = MethodChannel(messenger, "penny/notifications").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(listenerAllowed())
                    "openSettings" -> {
                        openListenerSettings()
                        result.success(null)
                    }
                    "peek" -> result.success(CaptureQueue.peek(this@MainActivity))
                    "drop" -> {
                        val count = (call.arguments as? Number)?.toInt() ?: 0
                        CaptureQueue.drop(this@MainActivity, count)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        notifications = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // A share while Penny is already open and on top.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = takeSharedText(intent) ?: return
        val open = channel
        if (open != null) open.invokeMethod("shared", text) else pending = text
    }

    private fun takeSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        // So a recreated activity doesn't import the same share twice.
        intent.removeExtra(Intent.EXTRA_TEXT)
        return text
    }

    private val listener get() = ComponentName(this, PaymentNotificationListener::class.java)

    /** Whether the user allowed Penny on Android's Notification access page. */
    private fun listenerAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return getSystemService(NotificationManager::class.java)
                .isNotificationListenerAccessGranted(listener)
        }
        val allowed = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        return allowed.split(':').any { ComponentName.unflattenFromString(it) == listener }
    }

    /** Penny's own entry on that page where there is one, or the list. */
    private fun openListenerSettings() {
        val list = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        val own = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                listener.flattenToString(),
            )
        } else {
            list
        }
        try {
            startActivity(own)
        } catch (e: ActivityNotFoundException) {
            startActivity(list)
        }
    }

    companion object {
        /** Dart's side of "penny/notifications", while Penny is running. */
        @Volatile
        private var notifications: MethodChannel? = null

        /** Tells Penny, if it's running, that payments are waiting. */
        fun capturesArrived() {
            Handler(Looper.getMainLooper()).post {
                notifications?.invokeMethod("captured", null)
            }
        }
    }
}
