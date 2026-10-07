package ee.respondcrew.alarm;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.media.*;
import android.net.Uri;
import android.os.*;

/** Bounded, user-visible alarm playback; never changes system volume or DND. */
public final class SarAlarmService extends Service {
    private static SarAlarmService active;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private MediaPlayer player;
    private AudioFocusRequest focus;
    private AudioManager audio;
    private PowerManager.WakeLock wake;
    private Vibrator vibrator;
    private int alarmId=-1;
    private final AudioManager.OnAudioFocusChangeListener focusListener=change->{if(change<0)finishAlarm("audio_interrupted");};
    public static void stop(Context context,int id) {
        // All callers run in the app process on the main looper, including the receiver.
        SarAlarmService service=active;
        if(service!=null && service.alarmId==id)service.finishAlarm("stopped");
    }
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public int onStartCommand(Intent intent,int flags,int startId) {
        if(intent==null){stopSelf();return START_NOT_STICKY;}
        if(SarAlarmEngine.TEST.equals(intent.getStringExtra("payload")) &&
           intent.getLongExtra("testToken",-1)!=SarAlarmEngine.prefs(this).getLong("testToken",0)) {
            // A cancelled/rescheduled test must not replace a real active alarm.
            if(active!=this)stopSelf();
            return START_NOT_STICKY;
        }
        releasePlayback();
        active=this;
        alarmId=intent.getIntExtra("id",-1);
        String payload=intent.getStringExtra("payload");
        if(!SarAlarmEngine.validPayload(payload)){stopSelf();return START_NOT_STICKY;}
        try {
            Notification notification=SarAlarmEngine.notification(this,alarmId,payload,true);
            if(Build.VERSION.SDK_INT>=29)startForeground(alarmId,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
            else startForeground(alarmId,notification);
            if(!SarAlarmEngine.mayPlay(this)){finishAlarm("sound_blocked");return START_NOT_STICKY;}
            wake=((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"RespondCrew:SarAlarm");
            wake.acquire(35000);
            audio=(AudioManager)getSystemService(AUDIO_SERVICE);
            AudioAttributes attrs=new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build();
            int granted;
            if(Build.VERSION.SDK_INT>=26){
                focus=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(attrs)
                    .setOnAudioFocusChangeListener(focusListener,handler).setAcceptsDelayedFocusGain(false).build();
                granted=audio.requestAudioFocus(focus);
            } else granted=audio.requestAudioFocus(focusListener,AudioManager.STREAM_ALARM,AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
            if(granted!=AudioManager.AUDIOFOCUS_REQUEST_GRANTED){finishAlarm("audio_focus_denied");return START_NOT_STICKY;}
            player=new MediaPlayer();
            player.setAudioAttributes(attrs);
            NotificationChannel channel=SarAlarmEngine.channel(this);
            Uri sound=channel==null ? Uri.parse("android.resource://"+getPackageName()+"/raw/sar_alarm") : channel.getSound();
            player.setDataSource(this,sound);
            player.setLooping(true);
            player.setOnPreparedListener(p->{
                if(player!=p || active!=this)return;
                try {p.start();SarAlarmEngine.record(this,"playing");}
                catch(IllegalStateException e){finishAlarm("playback_failed");}
            });
            player.setOnErrorListener((p,what,extra)->{finishAlarm("playback_failed");return true;});
            player.prepareAsync();
            if(channel==null || channel.shouldVibrate()){
                vibrator=(Vibrator)getSystemService(VIBRATOR_SERVICE);
                long[] pattern=channel==null?null:channel.getVibrationPattern();
                if(pattern==null || pattern.length==0)pattern=new long[]{0,500,300,500};
                if(Build.VERSION.SDK_INT>=26)vibrator.vibrate(VibrationEffect.createWaveform(pattern,0),attrs);
                else vibrator.vibrate(pattern,0,attrs);
            }
            handler.postDelayed(()->finishAlarm("finished"),SarAlarmEngine.TEST.equals(payload)?15000:30000);
        } catch(Exception e){finishAlarm("playback_failed");}
        return START_NOT_STICKY;
    }
    private void releasePlayback(){
        handler.removeCallbacksAndMessages(null);
        if(player!=null){player.release();player=null;}
        if(vibrator!=null){vibrator.cancel();vibrator=null;}
        if(audio!=null){if(Build.VERSION.SDK_INT>=26 && focus!=null)audio.abandonAudioFocusRequest(focus);else audio.abandonAudioFocus(focusListener);}
        focus=null;
        if(wake!=null && wake.isHeld())wake.release();
        wake=null;
    }
    private void finishAlarm(String reason){
        releasePlayback();
        SarAlarmEngine.record(this,reason);
        stopForeground(STOP_FOREGROUND_DETACH); // The callout remains available after its sound ends.
        stopSelf();
    }
    @Override public void onDestroy(){releasePlayback();if(active==this)active=null;super.onDestroy();}
}
