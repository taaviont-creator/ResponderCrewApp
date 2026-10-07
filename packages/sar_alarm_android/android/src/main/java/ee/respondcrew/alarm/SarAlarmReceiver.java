package ee.respondcrew.alarm;
import android.content.*;
public final class SarAlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if("STOP".equals(intent.getAction())) {
            SarAlarmService.stop(context,intent.getIntExtra("id",-1)); return;
        }
        if(!"TEST".equals(intent.getAction()))return;
        long expected=SarAlarmEngine.prefs(context).getLong("scheduledAt",0);
        long received=intent.getLongExtra("scheduledAt",0);
        if(!AlarmPolicy.freshTest(expected,received,System.currentTimeMillis())) {
            SarAlarmEngine.record(context,"test_expired"); return;
        }
        SarAlarmEngine.prefs(context).edit().remove("scheduledAt").commit();
        SarAlarmEngine.deliver(context,SarAlarmEngine.TEST_ID,SarAlarmEngine.TEST);
    }
}
