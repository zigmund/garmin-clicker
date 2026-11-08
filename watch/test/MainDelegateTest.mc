import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

class FakeLink {
    var lastAction = null;
    function state() as Number {
        return LinkState.LINK_NOT_PAIRED;
    }
    function macName() {
        return null;
    }
    function send(action, callback) as Void {
        lastAction = action;
    }
    function startPairing() as Void {}
    function forget() as Void {}
}

// Owns the fake clock and the update counter the delegate reports into.
class DelegateFixture {
    var now as Number = 0;
    var updates as Number = 0;
    var link as FakeLink = new FakeLink();
    var timer as PresentationTimer;
    var delegate as MainDelegate;
    private var _saved as Dictionary;

    function initialize() {
        _saved = stashStorage();
        timer = new PresentationTimer(method(:clock));
        delegate = new MainDelegate(timer, link, method(:updated));
    }

    function clock() as Number {
        return now;
    }

    function updated() as Void {
        updates++;
    }

    function press(key as Number) as Boolean {
        return delegate.handleKey(key);
    }

    function done() as Void {
        restoreStorage(_saved);
    }
}

(:test)
function downSendsNextByDefault(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    var handled = f.press(WatchUi.KEY_DOWN);
    f.done();
    Test.assert(handled);
    Test.assertEqual(f.link.lastAction, ButtonMap.ACTION_NEXT);
    return true;
}

(:test)
function upSendsPreviousByDefault(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.press(WatchUi.KEY_UP);
    f.done();
    Test.assertEqual(f.link.lastAction, ButtonMap.ACTION_PREVIOUS);
    return true;
}

(:test)
function remappedUpTogglesTimer(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    Settings.setButtonAction(ButtonMap.BUTTON_UP, ButtonMap.ACTION_TIMER_TOGGLE);
    f.press(WatchUi.KEY_UP);
    var running = f.timer.isRunning();
    f.done();
    Test.assert(running);
    Test.assert(f.link.lastAction == null);
    return true;
}

(:test)
function enterTogglesTimerByDefault(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.press(WatchUi.KEY_ENTER);
    f.now = 5000;
    var elapsed = f.timer.elapsedSeconds();
    f.done();
    Test.assertEqual(elapsed, 5);
    Test.assert(f.updates > 0);
    return true;
}

(:test)
function backNeverExitsWhileRunning(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.timer.toggle();
    f.now = 7000;
    var handled = f.press(WatchUi.KEY_ESC);
    var elapsed = f.timer.elapsedSeconds();
    var running = f.timer.isRunning();
    f.done();
    Test.assert(handled);
    Test.assert(running);
    Test.assertEqual(elapsed, 7);
    return true;
}

(:test)
function backResetsPausedTimer(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.timer.toggle();
    f.now = 3000;
    f.timer.toggle();
    var handled = f.press(WatchUi.KEY_ESC);
    var elapsed = f.timer.elapsedSeconds();
    f.done();
    Test.assert(handled);
    Test.assertEqual(elapsed, 0);
    return true;
}

(:test)
function backNeverExitsWhenNone(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    Settings.setButtonAction(ButtonMap.BUTTON_BACK, ButtonMap.ACTION_NONE);
    var handled = f.press(WatchUi.KEY_ESC);
    f.done();
    Test.assert(handled);
    return true;
}

(:test)
function menuAlwaysOpens(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    Settings.setButtonAction(ButtonMap.BUTTON_UP, ButtonMap.ACTION_NEXT);
    var opened = f.delegate.onMenu();
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    L10n._current = null;
    L10n._fallback = null;
    f.done();
    Test.assert(opened);
    return true;
}

(:test)
function backResetsPausedTimerViaOnBack(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.timer.toggle();
    f.now = 3000;
    f.timer.toggle();
    var before = f.timer.elapsedSeconds();
    var handled = f.delegate.onBack();
    var after = f.timer.elapsedSeconds();
    f.done();
    Test.assertEqual(before, 3);
    Test.assert(handled);
    Test.assertEqual(after, 0);
    return true;
}

(:test)
function backNeverExitsWhileRunningViaOnBack(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.timer.toggle();
    f.now = 7000;
    var handled = f.delegate.onBack();
    var running = f.timer.isRunning();
    var elapsed = f.timer.elapsedSeconds();
    f.done();
    Test.assert(handled);
    Test.assert(running);
    Test.assertEqual(elapsed, 7);
    return true;
}

(:test)
function backNoneViaOnBack(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    Settings.setButtonAction(ButtonMap.BUTTON_BACK, ButtonMap.ACTION_NONE);
    var handled = f.delegate.onBack();
    f.done();
    Test.assert(handled);
    return true;
}

(:test)
function behaviourCallbacksRouteThroughButtonMap(logger as Logger) as Boolean {
    var f = new DelegateFixture();
    f.delegate.onNextPage();
    var next = f.link.lastAction;
    f.delegate.onPreviousPage();
    var prev = f.link.lastAction;
    f.delegate.onSelect();
    var running = f.timer.isRunning();
    f.done();
    Test.assertEqual(next, ButtonMap.ACTION_NEXT);
    Test.assertEqual(prev, ButtonMap.ACTION_PREVIOUS);
    Test.assert(running);
    return true;
}
