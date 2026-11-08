import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class GarminClickerApp extends Application.AppBase {
    private var _timer as PresentationTimer;
    // Created with the first view, not in initialize: the unit-test runner instantiates the app
    // for every test, and the BLE profile can be registered only a few times per process.
    private var _link as BleLink? = null;

    function initialize() {
        AppBase.initialize();
        _timer = new PresentationTimer(method(:clock));
    }

    function onStop(state as Dictionary?) as Void {
        if (_link != null) {
            (_link as BleLink).shutdown();
        }
    }

    function clock() as Number {
        return System.getTimer();
    }

    function redraw() as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var link = new BleLink();
        _link = link;
        return [new MainView(_timer, link), new MainDelegate(_timer, link, method(:redraw))];
    }
}
