import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
    private var _timer;
    private var _link;
    private var _ticker as Timer.Timer? = null;
    private var _lastState as Number = -1;

    function initialize(timer, link) {
        View.initialize();
        _timer = timer;
        _link = link;
    }

    function onShow() as Void {
        _ticker = new Timer.Timer();
        (_ticker as Timer.Timer).start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_ticker != null) {
            (_ticker as Timer.Timer).stop();
            _ticker = null;
        }
    }

    // Once a second while the timer runs, and whenever the link state changes.
    function onTick() as Void {
        if (_timer.isRunning() || _link.state() != _lastState) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var state = _link.state();
        _lastState = state;
        var statusColor = state == LinkState.LINK_CONNECTED ? Graphics.COLOR_GREEN
            : (state == LinkState.LINK_REJECTED ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW);
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 22 / 100, Graphics.FONT_SMALL, statusText(state),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var name = _link.macName();
        if (state == LinkState.LINK_CONNECTED && name != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 31 / 100, Graphics.FONT_XTINY, name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_NUMBER_HOT,
            PresentationTimer.format(_timer.elapsedSeconds()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_SMALL,
            L10n.t(_timer.isRunning() ? "timer_running" : "timer_paused"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function statusText(state as Number) as String {
        if (state == LinkState.LINK_SEARCHING) {
            return L10n.t("status_searching");
        } else if (state == LinkState.LINK_CONNECTING) {
            return L10n.t("status_connecting");
        } else if (state == LinkState.LINK_CONNECTED) {
            return L10n.t("status_connected");
        } else if (state == LinkState.LINK_CONFIRM) {
            return L10n.t("status_confirm_on_mac");
        } else if (state == LinkState.LINK_REJECTED) {
            return L10n.t("status_rejected");
        }
        return L10n.t("status_not_paired");
    }
}
