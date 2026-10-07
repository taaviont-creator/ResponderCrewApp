package com.example.respondcrew_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.content.Intent
import android.os.Bundle
import android.app.KeyguardManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showLockedAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showLockedAlarm(intent)
    }

    private fun showLockedAlarm(intent: Intent) {
        if (intent.action != "SELECT_NOTIFICATION" || intent.getBooleanExtra("alarmUnlocked", false)) return
        val payload = intent.getStringExtra("payload")
        val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        if (keyguard.isKeyguardLocked && SarAlarmActivity.isAlarmPayload(payload)) {
            startActivity(Intent(this, SarAlarmActivity::class.java).putExtra("payload", payload))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "respondcrew/notifications")
            .setMethodCallHandler { call, result ->
                try {
                    if (call.method == "getBuildInfo") {
                        result.success(AlarmDeviceSettings.buildInfo(this))
                        return@setMethodCallHandler
                    }
                    if (call.method == "enableSarDnd") {
                        result.success(AlarmDeviceSettings.enableSarDnd(this))
                        return@setMethodCallHandler
                    }
                    if (call.method == "getSettings") {
                        result.success(AlarmDeviceSettings.read(this))
                        return@setMethodCallHandler
                    }
                    val candidates = AlarmDeviceSettings.intents(this, call.method)
                    if (candidates.isEmpty()) { result.notImplemented(); return@setMethodCallHandler }
                    for ((destination, settingsIntent) in candidates) {
                        try {
                            startActivity(settingsIntent)
                            result.success(destination)
                            return@setMethodCallHandler
                        } catch (_: android.content.ActivityNotFoundException) {
                            // Continue with a supported screen for the same task.
                        } catch (_: SecurityException) {
                            // Some OEMs expose a detail activity only to system apps.
                        }
                    }
                    result.error("unavailable", "Telefoni seadet ei saanud avada", null)
                } catch (_: SecurityException) {
                    result.error("unavailable", "Telefoni seadet ei saanud avada", null)
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
