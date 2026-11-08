import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Pairing screen: list of Macs in pairing mode (Up/Down select, Start connect, Back cancel),
// then "Connecting…" / "Confirm on Mac…", then "Paired" (2 s, close) or "Rejected by Mac"
// (3 s, back to the list). The link drives the flow; this view only shows it.
class PairingView extends WatchUi.View {
    const NO_MACS_AFTER_MS = 10000;
    const PAIRED_SHOW_MS = 2000;
    const REJECTED_SHOW_MS = 3000;

    private var _link;
    private var _popOnDone as Number;
    private var _index as Number = 0;
    // :list (the link's state is shown) | :paired | :rejected (result shown for a while)
    private var _phase as Symbol = :list;
    private var _noMacs as Boolean = false;
    private var _lastState as Number;
    private var _visible as Boolean = false;
    private var _started as Boolean = false;
    private var _timer as Timer.Timer = new Timer.Timer();

    // popOnDone: views to pop once paired (this one plus the menus under it).
    function initialize(link, popOnDone as Number) {
        View.initialize();
        _link = link;
        _popOnDone = popOnDone;
        _lastState = link.state();
    }

    // Pairing starts on the first show only. A later re-show (something was drawn over this view)
    // catches up with what the link did meanwhile and restarts the phase timer.
    function onShow() as Void {
        _visible = true;
        _link.setOnStateChange(method(:onLinkChange));
        if (!_started) {
            _started = true;
            startList();
        } else if (_phase == :list && !_link.isPairing()) {
            // Only a successful pairing leaves pairing mode while this view exists.
            enterPaired();
        } else if (_phase == :list && _link.state() == LinkState.LINK_REJECTED) {
            enterRejected();
        } else if (_phase == :paired) {
            _timer.start(method(:finish), PAIRED_SHOW_MS, false);
        } else if (_phase == :rejected) {
            _timer.start(method(:onRejectedShown), REJECTED_SHOW_MS, false);
        } else if (!_noMacs) {
            _timer.start(method(:onNoMacsTimeout), NO_MACS_AFTER_MS, false);
        }
        _lastState = _link.state();
        WatchUi.requestUpdate();
    }

    // The listener is not cleared here (the view shown next registers its own, and the order of
    // onHide/onShow is not guaranteed); onLinkChange ignores events while hidden instead.
    function onHide() as Void {
        _visible = false;
        _timer.stop();
    }

    // ---- Input (from PairingDelegate) ----

    function move(delta as Number) as Void {
        var n = _link.candidateNames().size();
        if (_phase != :list || _link.state() != LinkState.LINK_SEARCHING || n == 0) {
            return;
        }
        _index = (_index + delta + n) % n;
        WatchUi.requestUpdate();
    }

    function select() as Void {
        if (_phase == :list && _link.state() == LinkState.LINK_SEARCHING && _index < _link.candidateNames().size()) {
            _link.selectCandidate(_index);
        }
    }

    function back() as Void {
        _timer.stop();
        if (_phase == :paired) {
            finish();
            return;
        }
        _link.cancelPairing();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // ---- Link and timer events ----

    function onLinkChange() as Void {
        if (!_visible) {
            return; // popped (e.g. Back) while still registered with the link
        }
        var state = _link.state();
        if (_phase == :list) {
            if (state == LinkState.LINK_CONNECTED && !_link.isPairing()) {
                enterPaired();
            } else if (state == LinkState.LINK_REJECTED) {
                enterRejected();
            } else if (state == LinkState.LINK_SEARCHING
                    && (_lastState == LinkState.LINK_CONNECTING || _lastState == LinkState.LINK_CONFIRM)) {
                // Connection failed or approval timed out: back to the list.
                Haptics.error();
            }
            if (_index >= _link.candidateNames().size()) {
                _index = 0;
            }
        }
        _lastState = state;
        WatchUi.requestUpdate();
    }

    function onRejectedShown() as Void {
        _phase = :list;
        startList();
    }

    function onNoMacsTimeout() as Void {
        _noMacs = true;
        WatchUi.requestUpdate();
    }

    function finish() as Void {
        _timer.stop();
        for (var i = 0; i < _popOnDone; i++) {
            WatchUi.popView(i == _popOnDone - 1 ? WatchUi.SLIDE_DOWN : WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // (Re)starts the pairing scan with an empty list: first show and after "Rejected".
    private function startList() as Void {
        // startPairing() reports SEARCHING synchronously; with _lastState already SEARCHING that
        // is not mistaken for a failed connection (no error vibration).
        _lastState = LinkState.LINK_SEARCHING;
        _index = 0;
        _noMacs = false;
        _link.startPairing();
        _timer.stop();
        _timer.start(method(:onNoMacsTimeout), NO_MACS_AFTER_MS, false);
        WatchUi.requestUpdate();
    }

    private function enterPaired() as Void {
        _phase = :paired;
        Haptics.success();
        _timer.stop();
        _timer.start(method(:finish), PAIRED_SHOW_MS, false);
    }

    private function enterRejected() as Void {
        _phase = :rejected;
        Haptics.error();
        _timer.stop();
        _timer.start(method(:onRejectedShown), REJECTED_SHOW_MS, false);
    }

    // ---- Drawing ----

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var state = _link.state();
        if (_phase == :paired) {
            drawMessage(dc, L10n.t("pairing_paired"), Graphics.COLOR_GREEN);
        } else if (_phase == :rejected) {
            drawMessage(dc, L10n.t("status_rejected"), Graphics.COLOR_RED);
        } else if (state == LinkState.LINK_CONNECTING) {
            drawMessage(dc, L10n.t("status_connecting"), Graphics.COLOR_YELLOW);
        } else if (state == LinkState.LINK_CONFIRM) {
            drawMessage(dc, L10n.t("status_confirm_on_mac"), Graphics.COLOR_YELLOW);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 18 / 100, Graphics.FONT_SMALL, L10n.t("pairing_select_mac"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            var names = _link.candidateNames();
            if (names.size() == 0) {
                drawMessage(dc, L10n.t(_noMacs ? "pairing_no_macs" : "status_searching"), Graphics.COLOR_WHITE);
            } else {
                drawList(dc, names);
            }
        }
    }

    // Selected name in the middle, neighbours above and below.
    private function drawList(dc as Dc, names as Array<String>) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = names.size();
        var rowH = h * 18 / 100;
        for (var off = -1; off <= 1; off++) {
            var i = _index + off;
            if (i < 0 || i >= n) {
                continue;
            }
            var selected = off == 0;
            dc.setColor(selected ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            var font = selected ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
            var text = Graphics.fitTextToArea(names[i], font, w * 70 / 100, rowH, true);
            dc.drawText(w / 2, h / 2 + off * rowH, font, text != null ? text : "",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Centered text, wrapped into the middle of the round screen.
    private function drawMessage(dc as Dc, message as String, color as Graphics.ColorType) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var text = Graphics.fitTextToArea(message, Graphics.FONT_SMALL, w * 72 / 100, h * 45 / 100, true);
        dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, text != null ? text : message,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Same exactly-once routing as MainDelegate: behaviour callbacks and onKey both go through
// handleKey, whichever arrives first wins.
class PairingDelegate extends WatchUi.BehaviorDelegate {
    private var _view as PairingView;

    function initialize(view as PairingView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(evt as KeyEvent) as Boolean {
        if (handleKey(evt.getKey())) {
            return true;
        }
        return BehaviorDelegate.onKey(evt);
    }

    function handleKey(key as Number) as Boolean {
        if (key == WatchUi.KEY_UP) {
            _view.move(-1);
        } else if (key == WatchUi.KEY_DOWN) {
            _view.move(1);
        } else if (key == WatchUi.KEY_ENTER) {
            _view.select();
        } else if (key == WatchUi.KEY_ESC) {
            _view.back();
        } else {
            return false;
        }
        return true;
    }

    function onBack() as Boolean {
        return handleKey(WatchUi.KEY_ESC);
    }

    function onNextPage() as Boolean {
        return handleKey(WatchUi.KEY_DOWN);
    }

    function onPreviousPage() as Boolean {
        return handleKey(WatchUi.KEY_UP);
    }

    function onSelect() as Boolean {
        return handleKey(WatchUi.KEY_ENTER);
    }

    // Long Up does nothing here; the menu belongs to the main screen.
    function onMenu() as Boolean {
        return true;
    }
}
