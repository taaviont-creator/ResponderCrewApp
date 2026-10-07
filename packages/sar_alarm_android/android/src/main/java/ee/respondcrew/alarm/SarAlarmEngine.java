package ee.respondcrew.alarm;

import android.app.*;
import android.content.*;
import android.media.AudioManager;
import android.net.Uri;
import android.os.*;
import androidx.core.app.NotificationCompat;
import org.json.JSONObject;

public final class SarAlarmEngine {
    public static final String CHANNEL = "sar_alarm_v3";
    public static final String TEST = "local_callout_alarm_test";
    public static final int TEST_ID = 903100;
    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("sar_alarm_runtime", 0); }
    public static void record(Context c, String state) {
        prefs(c).edit().putString("lastState", state).putLong("lastAt", System.currentTimeMillis()).apply();
    }
    public static boolean validPayload(String payload) {
        if (TEST.equals(payload)) return true;
        try {
            JSONObject obj = new JSONObject(payload);
            return obj.optBoolean("sarAlarm") && !obj.optString("organizationId").isEmpty() && !obj.optString("calloutId").isEmpty();
        } catch (Exception e) { return false; }
    }
    static NotificationManager manager(Context c) { return (NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE); }
    static NotificationChannel channel(Context c) { return Build.VERSION.SDK_INT >= 26 ? manager(c).getNotificationChannel(CHANNEL) : null; }
    static boolean enabled(Context c) {
        NotificationChannel ch = channel(c);
        return manager(c).areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || (ch != null && ch.getImportance() > 0));
    }
    public static boolean alarmsAllowed(Context c) {
        NotificationManager nm = manager(c);
        int filter = nm.getCurrentInterruptionFilter();
        if (filter == NotificationManager.INTERRUPTION_FILTER_ALL || filter == NotificationManager.INTERRUPTION_FILTER_ALARMS) return true;
        if (filter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) return false;
        try {
            NotificationManager.Policy policy = Build.VERSION.SDK_INT >= 30 ? nm.getConsolidatedNotificationPolicy() : nm.getNotificationPolicy();
            return (policy.priorityCategories & NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS) != 0;
        } catch (SecurityException e) { return false; }
    }
    static boolean mayPlay(Context c) {
        NotificationChannel ch = channel(c);
        AudioManager audio = (AudioManager)c.getSystemService(Context.AUDIO_SERVICE);
        return AlarmPolicy.mayPlay(enabled(c), ch == null || (ch.getSound() != null && ch.getImportance() >= 3),
            audio.getStreamVolume(AudioManager.STREAM_ALARM), manager(c).getCurrentInterruptionFilter(), alarmsAllowed(c));
    }
    public static boolean deliver(Context c, int id, String payload) {
        if (!validPayload(payload) || !enabled(c)) { record(c,"notifications_blocked"); return false; }
        long now = SystemClock.elapsedRealtime();
        String key = "delivered_" + id;
        if (!TEST.equals(payload) && AlarmPolicy.duplicate(prefs(c).getLong(key,0), now)) return true;
        if (!TEST.equals(payload)) {
            SharedPreferences.Editor edit = prefs(c).edit();
            for (String old : prefs(c).getAll().keySet()) {
                if (old.startsWith("delivered_") && !AlarmPolicy.duplicate(prefs(c).getLong(old,0), now)) edit.remove(old);
            }
            edit.putLong(key,now).apply();
        }
        if (!mayPlay(c)) {
            manager(c).notify(id, notification(c,id,payload,false));
            record(c,"sound_blocked"); return true;
        }
        Intent service = new Intent(c,SarAlarmService.class).putExtra("id",id).putExtra("payload",payload);
        if (TEST.equals(payload)) {
            long token = SystemClock.elapsedRealtimeNanos();
            prefs(c).edit().putLong("testToken", token).commit();
            service.putExtra("testToken", token);
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(service); else c.startService(service);
            record(c,"starting");
        } catch (RuntimeException e) {
            // A downgraded FCM may not start an FGS. Keep the visible alert.
            manager(c).notify(id, notification(c,id,payload,false));
            record(c,"background_restricted");
        }
        return true;
    }
    static Intent open(Context c, int id, String payload, boolean lockScreen) {
        return new Intent().setClassName(c.getPackageName(),c.getPackageName() + (lockScreen ? ".SarAlarmActivity" : ".MainActivity"))
            .setAction("SELECT_NOTIFICATION").setData(Uri.parse("respondcrew://sar/"+id))
            .putExtra("id",id).putExtra("notificationId",id).putExtra("payload",payload)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    }
    static PendingIntent openPending(Context c,int id,String payload,boolean lockScreen) {
        return PendingIntent.getActivity(c,id,open(c,id,payload,lockScreen),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
    }
    static Notification notification(Context c,int id,String payload,boolean playing) {
        int icon=c.getResources().getIdentifier("ic_stat_respondcrew","drawable",c.getPackageName());
        boolean test=TEST.equals(payload);
        boolean drill=test;
        try { drill |= new JSONObject(payload).optBoolean("isTest"); } catch(Exception ignored) {}
        Intent stop=new Intent(c,SarAlarmReceiver.class).setAction("STOP").setData(Uri.parse("respondcrew://stop/"+id)).putExtra("id",id);
        PendingIntent stopPending=PendingIntent.getBroadcast(c,id,stop,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        NotificationCompat.Builder b=new NotificationCompat.Builder(c,CHANNEL)
            .setSmallIcon(icon == 0 ? c.getApplicationInfo().icon : icon)
            .setContentTitle(drill ? "SAR-proovihäire" : "SAR-väljakutse")
            .setContentText(test ? "See on ainult selle telefoni proovihäire." : "Uus väljakutse vajab reageerimist.")
            .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setAutoCancel(true)
            .setContentIntent(openPending(c,id,payload,false)).setDeleteIntent(stopPending)
            .setOnlyAlertOnce(true);
        if (playing) b.setSilent(true).addAction(0,"Vaigista",stopPending);
        else b.setSound(Uri.parse("android.resource://"+c.getPackageName()+"/raw/sar_alarm"));
        if(Build.VERSION.SDK_INT < 34 || manager(c).canUseFullScreenIntent()) b.setFullScreenIntent(openPending(c,id,payload,true),true);
        return b.build();
    }
    static PendingIntent testPending(Context c,long at,int flags) {
        Intent intent=new Intent(c,SarAlarmReceiver.class).setAction("TEST").putExtra("scheduledAt",at);
        return PendingIntent.getBroadcast(c,TEST_ID,intent,flags|PendingIntent.FLAG_IMMUTABLE);
    }
    public static boolean scheduleTest(Context c) {
        AlarmManager alarm=(AlarmManager)c.getSystemService(Context.ALARM_SERVICE);
        if(Build.VERSION.SDK_INT >= 31 && !alarm.canScheduleExactAlarms()) throw new SecurityException("exact_alarm_required");
        if(!enabled(c)) return false;
        long at=System.currentTimeMillis()+10000;
        prefs(c).edit().putLong("scheduledAt",at).commit();
        alarm.setAlarmClock(new AlarmManager.AlarmClockInfo(at,openPending(c,TEST_ID,TEST,false)),testPending(c,at,PendingIntent.FLAG_UPDATE_CURRENT));
        record(c,"scheduled"); return true;
    }
    public static void cancelTest(Context c) {
        prefs(c).edit().remove("scheduledAt").remove("testToken").commit();
        PendingIntent pending=testPending(c,0,PendingIntent.FLAG_NO_CREATE);
        if(pending!=null){((AlarmManager)c.getSystemService(Context.ALARM_SERVICE)).cancel(pending);pending.cancel();}
        SarAlarmService.stop(c,TEST_ID);
        manager(c).cancel(TEST_ID);
    }
}
