import Toybox.Lang;

// Counts quick consecutive taps: tap() returns true on the `needed`-th tap when every tap came
// within windowMs of the previous one, then starts over. Used for the hidden diagnostics toggle.
class TapCounter {
    private var _clock as Method() as Number;
    private var _needed as Number;
    private var _windowMs as Number;
    private var _count as Number = 0;
    private var _last as Number? = null;

    function initialize(clock as Method() as Number, needed as Number, windowMs as Number) {
        _clock = clock;
        _needed = needed;
        _windowMs = windowMs;
    }

    function tap() as Boolean {
        var now = _clock.invoke();
        if (_last == null || now - (_last as Number) > _windowMs) {
            _count = 0;
        }
        _last = now;
        _count++;
        if (_count >= _needed) {
            _count = 0;
            _last = null;
            return true;
        }
        return false;
    }
}
