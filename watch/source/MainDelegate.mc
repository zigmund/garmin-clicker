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

    // UP/DOWN/ENTER/ESC go through ButtonMap. ESC is always consumed so the app never exits;
    // everything else (notably KEY_MENU, the long Up) falls through to BehaviorDelegate -> onMenu.
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
        return true;
    }

    function onMenu() as Boolean {
        Menus.openMain(_timer, _link, _onUpdate);
        return true;
    }

    function onSendResult(ok as Boolean) as Void {
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
