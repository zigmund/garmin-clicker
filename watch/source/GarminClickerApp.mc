import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class GarminClickerApp extends Application.AppBase {
    private var _timer as PresentationTimer;
    private var _link as LinkStub;

    function initialize() {
        AppBase.initialize();
        _timer = new PresentationTimer(method(:clock));
        _link = new LinkStub();
    }

    function clock() as Number {
        return System.getTimer();
    }

    function redraw() as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(_timer, _link), new MainDelegate(_timer, _link, method(:redraw))];
    }
}
