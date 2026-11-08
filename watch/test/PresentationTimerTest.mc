import Toybox.Lang;
import Toybox.Test;

(:test)
class FakeClock {
    var now as Number = 0;
    function initialize() {}
    function read() as Number { return now; }
}

(:test)
function timerToggleAndElapsed(logger as Logger) as Boolean {
    var c = new FakeClock();
    var t = new PresentationTimer(c.method(:read));
    Test.assertEqual(t.elapsedSeconds(), 0);
    Test.assert(!t.isRunning());
    t.toggle();
    c.now = 65000;
    Test.assertEqual(t.elapsedSeconds(), 65);
    Test.assert(t.isRunning());
    t.toggle();
    c.now = 100000;
    Test.assertEqual(t.elapsedSeconds(), 65);
    Test.assert(!t.isRunning());
    t.toggle();
    c.now = 110000;
    Test.assertEqual(t.elapsedSeconds(), 75);
    return true;
}

(:test)
function timerResetOnlyWhenPaused(logger as Logger) as Boolean {
    var c = new FakeClock();
    var t = new PresentationTimer(c.method(:read));
    t.toggle();
    c.now = 5000;
    Test.assert(!t.reset());
    Test.assertEqual(t.elapsedSeconds(), 5);
    t.toggle();
    Test.assert(t.reset());
    Test.assertEqual(t.elapsedSeconds(), 0);
    Test.assert(!t.isRunning());
    return true;
}

(:test)
function formatCases(logger as Logger) as Boolean {
    Test.assertEqual(PresentationTimer.format(0), "0:00");
    Test.assertEqual(PresentationTimer.format(599), "9:59");
    Test.assertEqual(PresentationTimer.format(3599), "59:59");
    Test.assertEqual(PresentationTimer.format(3600), "1:00:00");
    Test.assertEqual(PresentationTimer.format(3725), "1:02:05");
    return true;
}
