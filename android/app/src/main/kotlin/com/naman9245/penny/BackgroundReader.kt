package com.naman9245.penny

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Reads payments that arrive while Penny is closed. A hidden copy of her,
 * with no screen, runs Dart's `readInBackground` (lib/background.dart): it
 * reads them with the same rules as the open app, posts Penny's
 * notification, and says when it's done. Then it's closed again.
 *
 * Everything here runs on the main thread.
 */
object BackgroundReader {
    private const val READER = "background"

    // What's logged says what happened, never what was read.
    private const val TAG = "Penny"

    /** If Dart never says it's done, it's closed anyway after this long. */
    private const val LIMIT_MS = 60_000L

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var starting = false

    // More arrived while the hidden copy was reading.
    private var again = false

    private var app: Context? = null
    private val giveUp = Runnable {
        Log.w(TAG, "The hidden copy took too long, so it was closed")
        finish()
    }

    /** Payments are waiting: Penny reads them if she's open, or else a hidden copy does. */
    fun wake(context: Context) {
        main.post {
            if (MainActivity.capturesArrived()) {
                Log.i(TAG, "Penny is open: she reads them herself")
            } else {
                start(context.applicationContext)
            }
        }
    }

    private fun start(context: Context) {
        if (engine != null || starting) {
            again = true
            return
        }
        starting = true
        app = context
        // Any SMS whose notification was missed, while it's here.
        SmsInbox.lookAgain(context)
        Log.i(TAG, "Starting a hidden copy of Penny to read them")
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationCompleteAsync(context, null, main) {
                starting = false
                // Penny opened meanwhile: she reads them herself.
                if (MainActivity.capturesArrived()) return@ensureInitializationCompleteAsync
                try {
                    run(context, loader.findAppBundlePath())
                } catch (e: Exception) {
                    Log.e(TAG, "The hidden copy couldn't start", e)
                    finish()
                }
            }
        } catch (e: Exception) {
            starting = false
            Log.e(TAG, "The hidden copy couldn't start", e)
        }
    }

    private fun run(context: Context, bundle: String) {
        val flutter = FlutterEngine(context)
        engine = flutter
        again = false
        MethodChannel(flutter.dartExecutor.binaryMessenger, "penny/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "peek" -> result.success(CaptureQueue.take(context, READER))
                    "drop" -> {
                        val count = (call.arguments as? Number)?.toInt() ?: 0
                        CaptureQueue.drop(context, READER, count)
                        result.success(null)
                    }
                    "notify" -> {
                        PennyNotifier.notify(
                            context,
                            call.argument<String>("title").orEmpty(),
                            call.argument<String>("text").orEmpty(),
                            call.argument<List<String>>("lines").orEmpty(),
                        )
                        result.success(null)
                    }
                    "scheduleReminders" -> {
                        ReminderScheduler.schedule(context, call.arguments as? String ?: "[]")
                        result.success(null)
                    }
                    "again" -> {
                        result.success(again)
                        again = false
                    }
                    "done" -> {
                        result.success(null)
                        Log.i(TAG, "The hidden copy is done")
                        main.post { finish() }
                    }
                    else -> result.notImplemented()
                }
            }
        main.postDelayed(giveUp, LIMIT_MS)
        flutter.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(bundle, "readInBackground"),
        )
        Log.i(TAG, "The hidden copy is reading")
    }

    private fun finish() {
        main.removeCallbacks(giveUp)
        val flutter = engine ?: return
        engine = null
        CaptureQueue.release(READER)
        flutter.destroy()
        // Penny may have opened meanwhile: she shows what was just read, and
        // takes anything that came after.
        if (MainActivity.refresh()) {
            again = false
            return
        }
        val context = app ?: return
        if (again) {
            again = false
            start(context)
        }
    }
}
