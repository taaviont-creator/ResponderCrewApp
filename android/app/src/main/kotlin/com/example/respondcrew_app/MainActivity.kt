package com.example.respondcrew_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.content.Intent
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "respondcrew/notifications")
            .setMethodCallHandler { call, result ->
                try {
                    val intent = when (call.method) {
                        "openSarChannel" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                .putExtra(Settings.EXTRA_CHANNEL_ID, "sar_alarm_v2")
                        } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(android.net.Uri.parse("package:$packageName"))
                        "openDndSettings" -> Intent("android.settings.ZEN_MODE_SETTINGS")
                        else -> null
                    }
                    if (intent == null) result.notImplemented()
                    else { startActivity(intent); result.success(null) }
                } catch (_: android.content.ActivityNotFoundException) {
                    startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                    result.success(null)
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "respondcrew/wakelock"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "toggle" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    if (enable) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
