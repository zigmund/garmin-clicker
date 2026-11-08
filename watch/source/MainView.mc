import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
    private var _timer;
    private var _link;
    private var _ticker as Timer.Timer? = null;
    private var _promptPending as Boolean;
    private var _openPairing as Boolean = false;

    function initialize(timer, link) {
        View.initialize();
        _timer = timer;
        _link = link;
        _promptPending = _link.state() == LinkState.LINK_NOT_PAIRED && !Settings.pairingPromptAnswered();
    }

    function onShow() as Void {
        _link.setOnStateChange(method(:onLinkChange));
        // First-run question: once, and only now that the main view is actually on top.
        if (_promptPending) {
            _promptPending = false;
            Menus.promptPairing(method(:onPairNow));
        } else if (_openPairing) {
            _openPairing = false;
            Menus.openPairing(_link, 1);
        }
        updateTicker();
    }

    function onHide() as Void {
        stopTicker();
    }

    // "Pair now?" answered yes: open the pairing screen when the confirmation has closed.
    function onPairNow() as Void {
        _openPairing = true;
    }

    function onLinkChange() as Void {
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // The 1 Hz redraw runs only while the timer runs; link changes redraw via onLinkChange.
    private function updateTicker() as Void {
        if (_timer.isRunning()) {
            if (_ticker == null) {
                _ticker = new Timer.Timer();
                (_ticker as Timer.Timer).start(method(:onTick), 1000, true);
            }
        } else {
            stopTicker();
        }
    }

    private function stopTicker() as Void {
        if (_ticker != null) {
            (_ticker as Timer.Timer).stop();
            _ticker = null;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        updateTicker();
        var state = _link.state();
        var statusColor = state == LinkState.LINK_CONNECTED ? Graphics.COLOR_GREEN
            : (state == LinkState.LINK_REJECTED ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW);
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        var statusY = h * 22 / 100;
        var statusStr = statusText(state);
        dc.drawText(w / 2, statusY, fitFont(dc, statusStr, statusY, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]), statusStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var name = _link.macName();
        if (state == LinkState.LINK_CONNECTED && name != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            var nameY = h * 31 / 100;
            dc.drawText(w / 2, nameY, fitFont(dc, name, nameY, [Graphics.FONT_TINY, Graphics.FONT_XTINY]), name,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var timeStr = PresentationTimer.format(_timer.elapsedSeconds());
        dc.drawText(w / 2, h / 2, fitFont(dc, timeStr, h / 2, [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM]), timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_SMALL,
            L10n.t(_timer.isRunning() ? "timer_running" : "timer_paused"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Largest font (candidates ordered big to small) whose text fits the chord of the round screen
    // at row y, minus a margin; the smallest candidate if none fits.
    private function fitFont(dc as Dc, text as String, y as Number, fonts as Array) as Graphics.FontType {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = (w < h ? w : h) / 2.0;
        var dy = (y - h / 2.0).abs();
        var chord = dy >= r ? 0.0 : 2.0 * Math.sqrt(r * r - dy * dy);
        var avail = chord * 0.92 - w * 0.04;
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= avail) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
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
