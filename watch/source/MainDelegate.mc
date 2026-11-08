import Toybox.Lang;
import Toybox.WatchUi;

class MainDelegate extends WatchUi.BehaviorDelegate {
    private var _timer;
    private var _link;
    private var _onUpdate as Method() as Void;

    function initialize(timer, link, onUpdate as Method() as Void) {
        BehaviorDelegate.initialize();
        _timer = timer;
        _link = link;
        _onUpdate = onUpdate;
    }

    // On device the behaviour callbacks (onBack, onNextPage, ...) may fire before onKey, and a
    // callback returning true suppresses onKey. Every behaviour we rely on therefore routes through
    // handleKey with its key, so each press is handled exactly once whichever path arrives first.
    // KEY_MENU (long Up) is not remappable: it reaches onMenu through BehaviorDelegate.
    function onKey(evt as KeyEvent) as Boolean {
        if (handleKey(evt.getKey())) {
            return true;
        }
        return BehaviorDelegate.onKey(evt);
    }

    // Returns false for keys that are not remappable buttons.
    function handleKey(key as Number) as Boolean {
        var button = ButtonMap.buttonForKey(key);
        if (button == null) {
            return false;
        }
        perform(Settings.buttonMap()[button] as Number);
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

    function onMenu() as Boolean {
        Menus.openSettings(_link);
        return true;
    }

    function onSendResult(ok as Boolean) as Void {
        Diag.sent(ok);
        if (ok) {
            Haptics.success();
        } else {
            Haptics.error();
        }
        _onUpdate.invoke();
    }

    private function perform(action as Number) as Void {
        if (action == ButtonMap.ACTION_NEXT || action == ButtonMap.ACTION_PREVIOUS) {
            _link.send(action, method(:onSendResult));
        } else if (action == ButtonMap.ACTION_TIMER_TOGGLE) {
            _timer.toggle();
        } else if (action == ButtonMap.ACTION_TIMER_RESET) {
            _timer.reset();
        }
        _onUpdate.invoke();
    }
}
