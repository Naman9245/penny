package com.naman9245.penny

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands text shared to Penny (a bank SMS from the Messages app) to Dart over
 * the "penny/share" channel. The text is only passed along, never stored here.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // A share that started the app waits here until Dart asks for it.
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = takeSharedText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "penny/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
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
}
