import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class GarminClickerApp extends Application.AppBase {
    private var _timer as PresentationTimer;
    private var _link as LinkStub;
    private var _promptTimer as Timer.Timer? = null;

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
        if (_link.state() == LinkState.LINK_NOT_PAIRED && !Settings.pairingPromptAnswered()) {
            // Pushing a view from inside getInitialView is not allowed; do it right after start.
            _promptTimer = new Timer.Timer();
            (_promptTimer as Timer.Timer).start(method(:showPairingPrompt), 300, false);
        }
        return [new MainView(_timer, _link), new MainDelegate(_timer, _link, method(:redraw))];
    }

    function showPairingPrompt() as Void {
        Menus.promptPairing(_link);
    }
}
