import Toybox.Lang;
import Toybox.WatchUi;

module ButtonMap {
    enum Action {
        ACTION_NONE = 0,
        ACTION_NEXT = 1,
        ACTION_PREVIOUS = 2,
        ACTION_TIMER_TOGGLE = 3,
        ACTION_TIMER_RESET = 4
    }

    enum Button {
        BUTTON_UP = 0,
        BUTTON_DOWN = 1,
        BUTTON_START = 2,
        BUTTON_BACK = 3
    }

    const BUTTONS = [BUTTON_UP, BUTTON_DOWN, BUTTON_START, BUTTON_BACK];

    function defaults() as Dictionary {
        return {
            BUTTON_UP => ACTION_PREVIOUS,
            BUTTON_DOWN => ACTION_NEXT,
            BUTTON_START => ACTION_TIMER_TOGGLE,
            BUTTON_BACK => ACTION_TIMER_RESET
        };
    }

    function isValidAction(value) as Boolean {
        return value instanceof Number && value >= ACTION_NONE && value <= ACTION_TIMER_RESET;
    }

    // Any garbage (wrong type, unknown action, missing key) falls back to the default for that button.
    function sanitize(map) as Dictionary {
        var out = defaults();
        if (!(map instanceof Dictionary)) {
            return out;
        }
        for (var i = 0; i < BUTTONS.size(); i++) {
            var b = BUTTONS[i];
            var v = map[b];
            if (isValidAction(v)) {
                out[b] = v;
            }
        }
        return out;
    }

    function buttonForKey(key) as Button? {
        if (key == WatchUi.KEY_UP) {
            return BUTTON_UP;
        } else if (key == WatchUi.KEY_DOWN) {
            return BUTTON_DOWN;
        } else if (key == WatchUi.KEY_ENTER) {
            return BUTTON_START;
        } else if (key == WatchUi.KEY_ESC) {
            return BUTTON_BACK;
        }
        return null;
    }
}
