import Toybox.Lang;

// Last slide command for the main screen's feedback: its hint icon lights up on the press and
// turns green or red with the result, for FLASH_MS after the latest event.
module Flash {
    const FLASH_MS = 500;
    const PENDING = 0;
    const OK = 1;
    const FAILED = 2;

    var action as Number? = null;
    var result as Number = PENDING;
    var at as Number = 0;

    function pressed(a as Number, now as Number) as Void {
        action = a;
        result = PENDING;
        at = now;
    }

    function done(ok as Boolean, now as Number) as Void {
        result = ok ? OK : FAILED;
        at = now;
    }

    // Result shown for action a now, or null when its icon is not lit.
    function stateFor(a as Number, now as Number) as Number? {
        if (action == null || action != a || now - at > FLASH_MS) {
            return null;
        }
        return result;
    }

    function active(now as Number) as Boolean {
        return action != null && now - at <= FLASH_MS;
    }
}
