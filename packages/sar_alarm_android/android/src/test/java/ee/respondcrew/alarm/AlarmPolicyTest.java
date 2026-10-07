package ee.respondcrew.alarm;
import org.junit.Test;
import static org.junit.Assert.*;

public class AlarmPolicyTest {
    @Test public void delayedTestMustMatchCurrentScheduleAndNotRingAfterLateUnlock() {
        assertTrue(AlarmPolicy.freshTest(10000,10000,10001));
        assertFalse(AlarmPolicy.freshTest(0,10000,10001)); // cancelled
        assertFalse(AlarmPolicy.freshTest(20000,10000,20001)); // rescheduled
        assertFalse(AlarmPolicy.freshTest(10000,10000,80000)); // stale after unlock
        assertFalse(AlarmPolicy.freshTest(10000,10000,5000)); // clock moved backwards
    }
    @Test public void redeliveryIsBoundedAndRebootDoesNotSuppressNewAlarm() {
        assertTrue(AlarmPolicy.duplicate(1000,2000));
        assertFalse(AlarmPolicy.duplicate(1000,301001));
        assertFalse(AlarmPolicy.duplicate(1000,100));
        assertFalse(AlarmPolicy.duplicate(0,100));
    }
    @Test public void silentRingerDoesNotBlockAlarmButExplicitRestrictionsDo() {
        assertTrue(AlarmPolicy.mayPlay(true,true,5,1,false));
        assertTrue(AlarmPolicy.mayPlay(true,true,5,4,false));
        assertTrue(AlarmPolicy.mayPlay(true,true,5,2,true));
        assertFalse(AlarmPolicy.mayPlay(true,true,5,2,false));
        assertFalse(AlarmPolicy.mayPlay(true,true,5,3,true));
        assertFalse(AlarmPolicy.mayPlay(true,true,0,1,true));
        assertFalse(AlarmPolicy.mayPlay(true,false,5,1,true));
        assertFalse(AlarmPolicy.mayPlay(false,true,5,1,true));
    }
}
