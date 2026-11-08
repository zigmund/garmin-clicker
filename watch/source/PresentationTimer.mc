import Toybox.Lang;

class PresentationTimer {
    private var _clock as Method() as Number;
    private var _running as Boolean = false;
    private var _accumulatedMs as Number = 0;
    private var _startedAt as Number = 0;

    function initialize(clock as Method() as Number) {
        _clock = clock;
    }

    function toggle() as Void {
        var now = _clock.invoke();
        if (_running) {
            _accumulatedMs += now - _startedAt;
            _running = false;
        } else {
            _startedAt = now;
            _running = true;
        }
    }

    // Only allowed while paused; returns whether the timer was reset.
    function reset() as Boolean {
        if (_running) {
            return false;
        }
        _accumulatedMs = 0;
        return true;
    }

    function isRunning() as Boolean {
        return _running;
    }

    function elapsedSeconds() as Number {
        var ms = _accumulatedMs;
        if (_running) {
            ms += _clock.invoke() - _startedAt;
        }
        return ms / 1000;
    }

    static function format(seconds as Number) as String {
        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        var s = seconds % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }
}
