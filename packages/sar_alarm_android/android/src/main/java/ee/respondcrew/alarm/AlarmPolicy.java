package ee.respondcrew.alarm;

/** Timing decisions kept independent of UI lifecycle and wall-clock changes. */
public final class AlarmPolicy {
    public static boolean freshTest(long expected, long received, long now) {
        return expected > 0 && received == expected && now >= received - 1000 && now - received <= 60000;
    }
    public static boolean duplicate(long lastElapsed, long nowElapsed) {
        return lastElapsed > 0 && nowElapsed >= lastElapsed && nowElapsed - lastElapsed < 300000;
    }
    public static boolean mayPlay(boolean notifications, boolean channelSound, int volume,
                                  int interruptionFilter, boolean priorityAllowsAlarms) {
        // Ringer/silent mode is intentionally not an input. DND is separate.
        return notifications && channelSound && volume > 0 &&
            (interruptionFilter == 1 || interruptionFilter == 4 ||
             (interruptionFilter == 2 && priorityAllowsAlarms));
    }
}
