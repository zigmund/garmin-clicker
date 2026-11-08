import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Main screen: clock and battery on top, a connection indicator (colour + animation while
// searching; words only for states that need the user), the presentation timer in the middle
// and icon hints next to the buttons (from the current button map).
class MainView extends WatchUi.View {
    const TICK_MS = 1000;
    const ANIM_TICK_MS = 250;

    private var _timer;
    private var _link;
    private var _ticker as Timer.Timer? = null;
    private var _tickMs as Number = 0;
    private var _phase as Number = 0;
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

    // "Pair a Mac now?" answered yes: open the pairing screen when the confirmation has closed.
    function onPairNow() as Void {
        _openPairing = true;
    }

    function onLinkChange() as Void {
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        _phase++;
        WatchUi.requestUpdate();
    }

    // Always ticking while shown (clock, timer); faster while the indicator animates or a
    // command's feedback is lit.
    private function updateTicker() as Void {
        var ms = animating() || Flash.active(System.getTimer()) ? ANIM_TICK_MS : TICK_MS;
        if (_ticker != null && ms == _tickMs) {
            return;
        }
        stopTicker();
        _tickMs = ms;
        _ticker = new Timer.Timer();
        (_ticker as Timer.Timer).start(method(:onTick), ms, true);
    }

    private function stopTicker() as Void {
        if (_ticker != null) {
            (_ticker as Timer.Timer).stop();
            _ticker = null;
        }
    }

    private function animating() as Boolean {
        var s = _link.state();
        return s == LinkState.LINK_SEARCHING || s == LinkState.LINK_CONNECTING || s == LinkState.LINK_CONFIRM;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        updateTicker();

        var state = _link.state();
        var running = _timer.isRunning();
        drawClockAndBattery(dc, w, h);
        drawIndicator(dc, w, h, state);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var timeStr = PresentationTimer.format(_timer.elapsedSeconds());
        dc.drawText(w / 2, h / 2, fitFont(dc, timeStr, h / 2, [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM], w * 0.62),
            timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!running) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 67 / 100, Graphics.FONT_TINY, L10n.t("timer_paused"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        drawHints(dc, w, h, running);
        if (Diag.isOn()) {
            drawDiag(dc, w, h);
        }
    }

    // ---- Top: clock and battery ----

    private function drawClockAndBattery(dc as Dc, w as Number, h as Number) as Void {
        var t = System.getClockTime();
        var hour = t.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12 == 0 ? 12 : hour % 12;
        }
        var battery = System.getSystemStats().battery;
        var text = hour + ":" + t.min.format("%02d") + "  " + battery.toNumber() + "%";
        dc.setColor(battery < 15 ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var y = h * 14 / 100;
        dc.drawText(w / 2, y, fitFont(dc, text, y, [Graphics.FONT_TINY, Graphics.FONT_XTINY], w.toFloat()), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- Connection indicator ----

    private function drawIndicator(dc as Dc, w as Number, h as Number, state as Number) as Void {
        var cx = w / 2;
        var cy = h * 26 / 100;
        var r = max(4, w / 45);
        var pen = max(2, w / 110);
        dc.setPenWidth(pen);
        var message = null;
        if (state == LinkState.LINK_CONNECTED) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
        } else if (state == LinkState.LINK_SEARCHING || state == LinkState.LINK_CONNECTING) {
            // Dot with an arc circling it: the watch is looking for / connecting to the Mac.
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r * 2 / 3);
            var from = (360 - (_phase * 45) % 360) % 360;
            dc.drawArc(cx, cy, r * 2, Graphics.ARC_CLOCKWISE, from, (from + 250) % 360);
        } else if (state == LinkState.LINK_CONFIRM) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            if (_phase % 4 < 2) {
                dc.fillCircle(cx, cy, r);
            } else {
                dc.drawCircle(cx, cy, r);
            }
            message = L10n.t("status_confirm_on_mac");
        } else if (state == LinkState.LINK_REJECTED) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            message = L10n.t("status_rejected");
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
            message = L10n.t("status_not_paired");
        }
        dc.setPenWidth(1);
        if (message != null) {
            var y = h * 34 / 100;
            dc.drawText(cx, y, fitFont(dc, message, y, [Graphics.FONT_XTINY], w * 0.6), message,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- Button hints ----

    private function drawHints(dc as Dc, w as Number, h as Number, running as Boolean) as Void {
        var map = Settings.buttonMap();
        var radius = (w < h ? w : h) / 2.0;
        var now = System.getTimer();
        var s = radius * 0.09;
        var edgePen = max(3, w / 70);
        for (var i = 0; i < ButtonMap.BUTTONS.size(); i++) {
            var button = ButtonMap.BUTTONS[i];
            var action = map[button] as Number;
            var kind = Hints.icon(action, running);
            if (kind == Hints.ICON_NONE) {
                continue;
            }
            var color = Graphics.COLOR_LT_GRAY;
            var flash = Flash.stateFor(action, now);
            if (flash == Flash.PENDING) {
                color = Graphics.COLOR_WHITE;
            } else if (flash == Flash.OK) {
                color = Graphics.COLOR_GREEN;
            } else if (flash == Flash.FAILED) {
                color = Graphics.COLOR_RED;
            }
            var a = Hints.angle(button);
            // Short arc on the bezel edge next to the button, the icon just inside it.
            dc.setColor(flash == null ? Graphics.COLOR_DK_GRAY : color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(edgePen);
            dc.drawArc(w / 2, h / 2, (radius - edgePen / 2 - 1).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, a - 9, a + 9);
            dc.setPenWidth(1);
            var p = Hints.point(w, h, a, radius * 0.80);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            drawIcon(dc, kind, p[0], p[1], s);
        }
    }

    private function drawIcon(dc as Dc, kind as Number, x as Float, y as Float, s as Float) as Void {
        if (kind == Hints.ICON_NEXT) {
            dc.fillPolygon([pt(x - s * 0.8, y - s * 0.8), pt(x + s * 0.3, y), pt(x - s * 0.8, y + s * 0.8)]);
            dc.fillRectangle((x + s * 0.4).toNumber(), (y - s * 0.8).toNumber(), max(2, (s * 0.3).toNumber()), (s * 1.6).toNumber());
        } else if (kind == Hints.ICON_PREVIOUS) {
            dc.fillPolygon([pt(x + s * 0.8, y - s * 0.8), pt(x - s * 0.3, y), pt(x + s * 0.8, y + s * 0.8)]);
            var bw = max(2, (s * 0.3).toNumber());
            dc.fillRectangle((x - s * 0.4).toNumber() - bw, (y - s * 0.8).toNumber(), bw, (s * 1.6).toNumber());
        } else if (kind == Hints.ICON_PLAY) {
            dc.fillPolygon([pt(x - s * 0.6, y - s * 0.8), pt(x + s * 0.8, y), pt(x - s * 0.6, y + s * 0.8)]);
        } else if (kind == Hints.ICON_PAUSE) {
            var bw2 = max(2, (s * 0.45).toNumber());
            dc.fillRectangle((x - s * 0.7).toNumber(), (y - s * 0.8).toNumber(), bw2, (s * 1.6).toNumber());
            dc.fillRectangle((x + s * 0.7).toNumber() - bw2, (y - s * 0.8).toNumber(), bw2, (s * 1.6).toNumber());
        } else if (kind == Hints.ICON_RESET) {
            // ↺: a ring open at the top (drawn counter-clockwise from 120° round to 60°) with an
            // arrowhead at the 60° end pointing on along the ring, into the gap.
            var rr = s * 0.75;
            dc.setPenWidth(max(2, (s * 0.25).toNumber()));
            dc.drawArc(x.toNumber(), y.toNumber(), rr.toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 120, 60);
            dc.setPenWidth(1);
            var t = Math.toRadians(60);
            var ex = x + rr * Math.cos(t);
            var ey = y - rr * Math.sin(t);
            var tx = -Math.sin(t); // counter-clockwise tangent, screen coordinates
            var ty = -Math.cos(t);
            var nx = Math.cos(t); // outward normal, screen coordinates
            var ny = -Math.sin(t);
            dc.fillPolygon([
                pt(ex + tx * s * 0.55, ey + ty * s * 0.55),
                pt(ex + nx * s * 0.4, ey + ny * s * 0.4),
                pt(ex - nx * s * 0.4, ey - ny * s * 0.4)
            ]);
        }
    }

    private function pt(x as Float, y as Float) as [Number, Number] {
        return [x.toNumber(), y.toNumber()];
    }

    // ---- Diagnostics (hidden, Settings → Version × 5) ----

    private function drawDiag(dc as Dc, w as Number, h as Number) as Void {
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        // While looking for the Mac: the scan counters too (shortest line lowest, where the
        // round screen is narrowest).
        var lines = animating() ? Diag.pairingLines() : [Diag.mainLine()];
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(w / 2, h * (78 + i * 7) / 100, Graphics.FONT_XTINY, lines[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- Helpers ----

    // Largest font (candidates ordered big to small) whose text fits both maxWidth and the chord
    // of the round screen at the text's outer edge (row y ± half the font height), minus a
    // margin; the smallest candidate if none fits.
    private function fitFont(dc as Dc, text as String, y as Number, fonts as Array, maxWidth as Float) as Graphics.FontType {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = (w < h ? w : h) / 2.0;
        for (var i = 0; i < fonts.size(); i++) {
            var dy = (y - h / 2.0).abs() + dc.getFontHeight(fonts[i]) / 2.0;
            var chord = dy >= r ? 0.0 : 2.0 * Math.sqrt(r * r - dy * dy);
            var avail = chord * 0.92 - w * 0.04;
            if (avail > maxWidth) {
                avail = maxWidth;
            }
            if (dc.getTextWidthInPixels(text, fonts[i]) <= avail) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    private function max(a as Number, b as Number) as Number {
        return a > b ? a : b;
    }
}
