import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
function defaultsMatchSpec(logger as Logger) as Boolean {
    var d = ButtonMap.defaults();
    Test.assertEqual(d[ButtonMap.BUTTON_UP], ButtonMap.ACTION_PREVIOUS);
    Test.assertEqual(d[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    Test.assertEqual(d[ButtonMap.BUTTON_START], ButtonMap.ACTION_TIMER_TOGGLE);
    Test.assertEqual(d[ButtonMap.BUTTON_BACK], ButtonMap.ACTION_TIMER_RESET);
    return true;
}

(:test)
function sanitizeFixesGarbage(logger as Logger) as Boolean {
    var d = ButtonMap.defaults();
    var inputs = [null, "x", {ButtonMap.BUTTON_UP => 99}];
    for (var i = 0; i < inputs.size(); i++) {
        var m = ButtonMap.sanitize(inputs[i]);
        for (var b = ButtonMap.BUTTON_UP; b <= ButtonMap.BUTTON_BACK; b++) {
            Test.assertEqual(m[b], d[b]);
        }
    }
    return true;
}

(:test)
function sanitizeKeepsValidAndFixesRest(logger as Logger) as Boolean {
    var m = ButtonMap.sanitize({
        ButtonMap.BUTTON_UP => ButtonMap.ACTION_NONE,
        ButtonMap.BUTTON_DOWN => "bad",
        ButtonMap.BUTTON_START => ButtonMap.ACTION_NEXT
    });
    Test.assertEqual(m[ButtonMap.BUTTON_UP], ButtonMap.ACTION_NONE);
    Test.assertEqual(m[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    Test.assertEqual(m[ButtonMap.BUTTON_START], ButtonMap.ACTION_NEXT);
    Test.assertEqual(m[ButtonMap.BUTTON_BACK], ButtonMap.ACTION_TIMER_RESET);
    return true;
}

(:test)
function buttonForKeyMapping(logger as Logger) as Boolean {
    Test.assertEqual(ButtonMap.buttonForKey(WatchUi.KEY_UP), ButtonMap.BUTTON_UP);
    Test.assertEqual(ButtonMap.buttonForKey(WatchUi.KEY_DOWN), ButtonMap.BUTTON_DOWN);
    Test.assertEqual(ButtonMap.buttonForKey(WatchUi.KEY_ENTER), ButtonMap.BUTTON_START);
    Test.assertEqual(ButtonMap.buttonForKey(WatchUi.KEY_ESC), ButtonMap.BUTTON_BACK);
    Test.assert(ButtonMap.buttonForKey(WatchUi.KEY_MENU) == null);
    return true;
}
