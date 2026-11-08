import Toybox.Lang;

// When the reconnect scan should run (normal mode only; the pairing list always scans).
// The first minute of searching scans continuously, then the scan is duty-cycled
// (10 s on / 5 s off) to save battery while no Mac is around. A start may be held back
// briefly (after the system refused to connect). Pure: the caller passes the clock.
class ScanSchedule {
    const CONTINUOUS_MS = 60000;
    const ON_MS = 10000;
    const OFF_MS = 5000;

    private var _since as Number? = null;
    private var _holdUntil as Number? = null;

    function initialize() {}

    // Searching starts (again) now; holdMs > 0 delays the first scan.
    function start(now as Number, holdMs as Number) as Void {
        _since = now;
        _holdUntil = holdMs > 0 ? now + holdMs : null;
    }

    function stop() as Void {
        _since = null;
        _holdUntil = null;
    }

    function isActive() as Boolean {
        return _since != null;
    }

    function shouldScan(now as Number) as Boolean {
        if (_since == null) {
            return false;
        }
        if (_holdUntil != null && now < (_holdUntil as Number)) {
            return false;
        }
        var t = now - (_since as Number);
        if (t < CONTINUOUS_MS) {
            return true;
        }
        return (t - CONTINUOUS_MS) % (ON_MS + OFF_MS) < ON_MS;
    }
}
