package com.example.respondcrew_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.provider.Settings

object AlarmDeviceSettings {
    const val SAR_CHANNEL = "sar_alarm_v2"

    fun read(context: Context): Map<String, Any?> {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(SAR_CHANNEL) else null
        // Existing channels retain their user-selected sound and audio stream.
        val stream = if (channel?.audioAttributes?.usage == AudioAttributes.USAGE_ALARM)
            AudioManager.STREAM_ALARM else AudioManager.STREAM_NOTIFICATION
        return mapOf(
            "notificationsEnabled" to (if (Build.VERSION.SDK_INT >= 24) manager.areNotificationsEnabled() else true),
            "channelExists" to (channel != null),
            "channelEnabled" to channel?.let { it.importance > NotificationManager.IMPORTANCE_NONE },
            "channelSound" to channel?.let { it.sound != null && it.importance >= NotificationManager.IMPORTANCE_DEFAULT },
            "bypassDnd" to channel?.canBypassDnd(),
            "fullScreenAllowed" to (if (Build.VERSION.SDK_INT >= 34) manager.canUseFullScreenIntent() else true),
            "soundVolume" to audio.getStreamVolume(stream),
            "soundVolumeMax" to audio.getStreamMaxVolume(stream)
        )
    }

    fun intent(context: Context, method: String): Intent? {
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"))
        return when (method) {
            "openAppNotifications" -> if (Build.VERSION.SDK_INT >= 26)
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName) else details
            // The channel screen contains the actual exception switch. General
            // policy access alone is NOT evidence that SAR can bypass DND.
            "openSarChannel", "openDndSettings" -> if (Build.VERSION.SDK_INT >= 26)
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, SAR_CHANNEL) else details
            "openFullScreenSettings" -> if (Build.VERSION.SDK_INT >= 34)
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}")) else
                intent(context, "openAppNotifications")
            "openSoundSettings" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            else -> null
        }
    }
}
