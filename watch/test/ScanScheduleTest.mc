import Toybox.Lang;
import Toybox.Test;

(:test)
function scheduleIdleNeverScans(logger as Logger) as Boolean {
    var s = new ScanSchedule();
    Test.assert(!s.isActive());
    Test.assert(!s.shouldScan(0));
    s.start(0, 0);
    Test.assert(s.isActive());
    s.stop();
    Test.assert(!s.isActive());
    Test.assert(!s.shouldScan(1000));
    return true;
}

(:test)
function scheduleContinuousFirstMinute(logger as Logger) as Boolean {
    var s = new ScanSchedule();
    s.start(1000, 0);
    Test.assert(s.shouldScan(1000));
    Test.assert(s.shouldScan(30000));
    Test.assert(s.shouldScan(60999));
    return true;
}

(:test)
function scheduleDutyCycleAfterMinute(logger as Logger) as Boolean {
    var s = new ScanSchedule();
    s.start(0, 0);
    // 10 s on / 5 s off from the 60th second on.
    Test.assert(s.shouldScan(60000));
    Test.assert(s.shouldScan(69999));
    Test.assert(!s.shouldScan(70000));
    Test.assert(!s.shouldScan(74999));
    Test.assert(s.shouldScan(75000));
    Test.assert(s.shouldScan(84999));
    Test.assert(!s.shouldScan(85000));
    // Still cycling an hour later (240 full cycles of 15 s).
    Test.assert(s.shouldScan(60000 + 240 * 15000));
    Test.assert(!s.shouldScan(60000 + 240 * 15000 + 10000));
    return true;
}

(:test)
function scheduleHoldDelaysScan(logger as Logger) as Boolean {
    var s = new ScanSchedule();
    s.start(5000, 1000);
    Test.assert(s.isActive());
    Test.assert(!s.shouldScan(5000));
    Test.assert(!s.shouldScan(5999));
    Test.assert(s.shouldScan(6000));
    // A fresh start without a hold scans at once.
    s.start(7000, 0);
    Test.assert(s.shouldScan(7000));
    return true;
}
