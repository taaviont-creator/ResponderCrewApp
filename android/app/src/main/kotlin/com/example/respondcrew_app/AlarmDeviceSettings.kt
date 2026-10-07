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
    const val SAR_CHANNEL = "sar_alarm_v3"

    fun buildInfo(context: Context): Map<String, Any?> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        return mapOf("version" to info.versionName, "build" to code.toString())
    }

    // Only called after an explicit button press and system-granted access.
    // Android can refuse changes to a channel previously edited by the user.
    fun enableSarDnd(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT < 26 || !manager.isNotificationPolicyAccessGranted) return false
        val channel = manager.getNotificationChannel(SAR_CHANNEL) ?: return false
        channel.setBypassDnd(true)
        manager.createNotificationChannel(channel)
        return manager.getNotificationChannel(SAR_CHANNEL)?.canBypassDnd() == true
    }

    fun read(context: Context): Map<String, Any?> {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(SAR_CHANNEL) else null
        // A muted channel may have null audio attributes. Still report the
        // alarm stream used by SAR v3, never the unrelated ringtone volume.
        val stream = AudioManager.STREAM_ALARM
        return mapOf(
            "notificationsEnabled" to (if (Build.VERSION.SDK_INT >= 24) manager.areNotificationsEnabled() else true),
            "channelExists" to (channel != null),
            "channelEnabled" to channel?.let { it.importance > NotificationManager.IMPORTANCE_NONE },
            "channelSound" to channel?.let { it.sound != null && it.importance >= NotificationManager.IMPORTANCE_DEFAULT },
            "bypassDnd" to channel?.canBypassDnd(),
            "notificationPolicyAccess" to (if (Build.VERSION.SDK_INT >= 23) manager.isNotificationPolicyAccessGranted else null),
            "alarmAudio" to (channel?.audioAttributes?.usage == AudioAttributes.USAGE_ALARM),
            "interruptionFilter" to manager.currentInterruptionFilter,
            "ringerMode" to audio.ringerMode,
            "audioMode" to audio.mode,
            "fullScreenAllowed" to (if (Build.VERSION.SDK_INT >= 34) manager.canUseFullScreenIntent() else true),
            "soundVolume" to audio.getStreamVolume(stream),
            "soundVolumeMax" to audio.getStreamMaxVolume(stream)
        )
    }

    // OEMs differ in which Settings activities they expose. Try the relevant
    // permission list before falling back to general app information.
    fun intents(context: Context, method: String): List<Pair<String, Intent>> {
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"))
        val notifications = if (Build.VERSION.SDK_INT >= 26)
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName) else details
        val channel = if (Build.VERSION.SDK_INT >= 26)
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, SAR_CHANNEL) else notifications
        return when (method) {
            "openAppNotifications" -> listOf("appNotifications" to notifications, "appDetails" to details)
            "openSarChannel" -> listOf("sarChannel" to channel, "appNotifications" to notifications, "appDetails" to details)
            "openDndSettings" -> if (Build.VERSION.SDK_INT >= 23) listOf(
                // AOSP detail action is not a public SDK constant. It is only
                // an optional shortcut; the documented public list is next.
                "dndApp" to Intent("android.settings.NOTIFICATION_POLICY_ACCESS_DETAIL_SETTINGS", Uri.parse("package:${context.packageName}")),
                "dndList" to Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS),
                "appNotifications" to notifications, "appDetails" to details
            ) else listOf("appDetails" to details)
            "openFullScreenSettings" -> if (Build.VERSION.SDK_INT >= 34) listOf(
                "fullScreenApp" to Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}")),
                "fullScreenList" to Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT),
                "appNotifications" to notifications, "appDetails" to details
            ) else listOf("appNotifications" to notifications, "appDetails" to details)
            "openSoundSettings" -> listOf("sound" to Intent(Settings.ACTION_SOUND_SETTINGS), "appNotifications" to notifications, "appDetails" to details)
            else -> emptyList()
        }
    }
}
