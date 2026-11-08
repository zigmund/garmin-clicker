import Toybox.Lang;
import Toybox.Test;

(:test)
function tapCounterFiresOnFifthQuickTap(logger as Logger) as Boolean {
    var c = new FakeClock();
    var t = new TapCounter(c.method(:read), 5, 1500);
    for (var i = 1; i <= 4; i++) {
        c.now = i * 1000;
        Test.assert(!t.tap());
    }
    c.now = 5000;
    Test.assert(t.tap());
    // Starts over: the sixth tap alone does nothing.
    c.now = 5500;
    Test.assert(!t.tap());
    return true;
}

(:test)
function tapCounterResetsAfterPause(logger as Logger) as Boolean {
    var c = new FakeClock();
    var t = new TapCounter(c.method(:read), 5, 1500);
    for (var i = 0; i < 4; i++) {
        c.now = i * 500;
        Test.assert(!t.tap());
    }
    // More than the window after the 4th tap (at 1500): counting restarts with this tap.
    c.now = 3001;
    Test.assert(!t.tap());
    for (var i = 1; i <= 3; i++) {
        c.now = 3001 + i * 500;
        Test.assert(!t.tap());
    }
    c.now = 3001 + 4 * 500;
    Test.assert(t.tap());
    return true;
}
