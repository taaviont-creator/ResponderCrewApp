package ee.respondcrew.alarm;

import android.content.Context;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

public final class SarAlarmPlugin implements FlutterPlugin {
    private MethodChannel channel;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "respondcrew/native_sar_alarm");
        channel.setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "show": {
                        Number id = call.argument("id");
                        String payload = call.argument("payload");
                        if (id == null || !SarAlarmEngine.validPayload(payload)) {
                            result.error("invalid_alarm", "Vigane SAR-häire", null); return;
                        }
                        result.success(SarAlarmEngine.deliver(context, id.intValue(), payload));
                        break;
                    }
                    case "scheduleTest": result.success(SarAlarmEngine.scheduleTest(context)); break;
                    case "cancelTest": SarAlarmEngine.cancelTest(context); result.success(null); break;
                    default: result.notImplemented();
                }
            } catch (SecurityException e) {
                result.error("exact_alarm_required".equals(e.getMessage()) ? "exact_alarm_required" : "alarm_permission",
                    "Kontrolli telefoni alarmi- ja teavituslube", null);
            } catch (RuntimeException e) {
                SarAlarmEngine.record(context, "error");
                result.error("alarm_failed", "Häire käivitamine ebaõnnestus", null);
            }
        });
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
