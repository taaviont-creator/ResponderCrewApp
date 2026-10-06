package com.example.respondcrew_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

/** Only this generic alert may cover the keyguard; operational data stays locked. */
class SarAlarmActivity : Activity() {
    companion object {
        fun isAlarmPayload(payload: String?): Boolean {
            if (payload == "local_callout_alarm_test") return true
            return try {
                val data = JSONObject(payload ?: "")
                data.optBoolean("sarAlarm", false) && data.optString("organizationId").isNotBlank() && data.optString("calloutId").isNotBlank()
            } catch (_: Exception) { false }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val payload = intent.getStringExtra("payload")
        if (!isAlarmPayload(payload)) { finish(); return }
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        val test = payload == "local_callout_alarm_test"
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val padding = (24 * resources.displayMetrics.density).toInt()
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(android.graphics.Color.WHITE)
        }
        layout.addView(TextView(this).apply {
            text = if (test) "SAR-proovihäire" else "SAR-väljakutse"
            textSize = 30f
            setTextColor(android.graphics.Color.rgb(8, 36, 56))
            gravity = Gravity.CENTER
        })
        layout.addView(TextView(this).apply {
            text = if (test) "See on ainult selle telefoni proovihäire." else "Uus väljakutse vajab reageerimist."
            textSize = 18f
            setTextColor(android.graphics.Color.DKGRAY)
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 32)
        })
        layout.addView(Button(this).apply {
            text = if (test) "Ava RespondCrew" else "Ava väljakutse"
            setOnClickListener {
                val open = {
                    startActivity(Intent(this@SarAlarmActivity, MainActivity::class.java)
                        .setAction("SELECT_NOTIFICATION")
                        .putExtra("payload", payload)
                        .putExtra("alarmUnlocked", true)
                        .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    finish()
                }
                val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
                if (Build.VERSION.SDK_INT >= 26 && keyguard.isKeyguardLocked) {
                    keyguard.requestDismissKeyguard(this@SarAlarmActivity, object : KeyguardManager.KeyguardDismissCallback() {
                        override fun onDismissSucceeded() { open() }
                    })
                } else if (!keyguard.isKeyguardLocked) { open() }
                else {
                    // Older systems show their normal lock screen before the app.
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
                    open()
                }
            }
        }, LinearLayout.LayoutParams(-1, -2))
        layout.addView(Button(this).apply {
            text = "Sulge häirevaade"
            setOnClickListener { moveTaskToBack(true); finish() }
        }, LinearLayout.LayoutParams(-1, -2))
        setContentView(layout)
    }
}
