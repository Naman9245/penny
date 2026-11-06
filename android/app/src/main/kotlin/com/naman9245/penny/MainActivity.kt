package com.naman9245.penny

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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
    private var own: MethodChannel? = null

    // This copy of Penny, as a reader of what's waiting. Sharing can open a
    // second copy, with its own.
    private val reader = "app-${System.identityHashCode(this)}"

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
        own = MethodChannel(messenger, "penny/notifications").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(listenerAllowed())
                    "openSettings" -> {
                        openListenerSettings()
                        result.success(null)
                    }
                    "peek" -> result.success(CaptureQueue.take(this@MainActivity, reader))
                    "catchUp" -> result.success(PaymentNotificationListener.catchUpNow())
                    "drop" -> {
                        val count = (call.arguments as? Number)?.toInt() ?: 0
                        CaptureQueue.drop(this@MainActivity, reader, count)
                        result.success(null)
                    }
                    "notify" -> {
                        PennyNotifier.notify(
                            this@MainActivity,
                            call.argument<String>("title").orEmpty(),
                            call.argument<String>("text").orEmpty(),
                            call.argument<List<String>>("lines").orEmpty(),
                        )
                        result.success(null)
                    }
                    "canNotify" -> result.success(PennyNotifier.allowed(this@MainActivity))
                    "askToNotify" -> askToNotify(call.arguments as? Boolean ?: true, result)
                    else -> result.notImplemented()
                }
            }
        }
        notifications = own
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (notifications === own) notifications = null
        own = null
        CaptureQueue.release(reader)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // Penny's notification tapped, or a share, while Penny is already open.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(OPEN_HOME, false)) {
            intent.removeExtra(OPEN_HOME)
            own?.invokeMethod("openHome", null)
            return
        }
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

    // Waits for the answer to Android's "Allow Penny to send you
    // notifications?"
    private var notifyAnswer: MethodChannel.Result? = null

    /**
     * Asks whether Penny may post notifications, with Android's own question
     * where it still asks it: Android 13 and later, the first time, and once
     * more after a no. Where it doesn't, and [orSettings], it opens Penny's
     * notification settings instead. Answers whether she may now.
     */
    private fun askToNotify(orSettings: Boolean, result: MethodChannel.Result) {
        if (PennyNotifier.allowed(this)) return result.success(true)
        val permission = Manifest.permission.POST_NOTIFICATIONS
        val asked = getSharedPreferences("penny_android", MODE_PRIVATE)
        val canAsk = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED &&
            (!asked.getBoolean("asked_to_notify", false) ||
                shouldShowRequestPermissionRationale(permission))
        if (canAsk && notifyAnswer == null) {
            asked.edit().putBoolean("asked_to_notify", true).apply()
            notifyAnswer = result
            requestPermissions(arrayOf(permission), ASK_TO_NOTIFY)
            return
        }
        if (orSettings) openNotificationSettings()
        result.success(false)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ASK_TO_NOTIFY) return
        notifyAnswer?.success(PennyNotifier.allowed(this))
        notifyAnswer = null
    }

    /** Penny's notification settings, or her app info where there are none. */
    private fun openNotificationSettings() {
        val settings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        try {
            startActivity(settings)
        } catch (e: ActivityNotFoundException) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", packageName, null)),
            )
        }
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
        private const val ASK_TO_NOTIFY = 7

        /** On the intent of Penny's notification: open Home. */
        const val OPEN_HOME = "com.naman9245.penny.OPEN_HOME"

        /** Dart's side of "penny/notifications", while Penny is running. */
        private var notifications: MethodChannel? = null

        /**
         * Tells Penny, if she's running, that payments are waiting. Whether
         * she was. On the main thread.
         */
        fun capturesArrived(): Boolean {
            val open = notifications ?: return false
            open.invokeMethod("captured", null)
            return true
        }

        /**
         * Tells Penny, if she's running, that her hidden copy just read
         * payments, so she shows them and takes anything newer. Whether she
         * was. On the main thread.
         */
        fun refresh(): Boolean {
            val open = notifications ?: return false
            open.invokeMethod("refresh", null)
            return true
        }
    }
}
