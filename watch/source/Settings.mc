import Toybox.Application;
import Toybox.Cryptography;
import Toybox.Lang;

// Persistent settings over Application.Storage. Every getter tolerates a missing key,
// a wrong type or stale content and falls back to a safe default.
module Settings {
    const KEY_WATCH_ID = "watchId";
    const KEY_MAC_ID = "macId";
    const KEY_MAC_NAME = "macName";
    const KEY_BUTTON_MAP = "buttonMap";
    const KEY_LANGUAGE = "language";
    const KEY_PROMPT_ANSWERED = "pairingPromptAnswered";
    const KEY_DIAGNOSTICS = "diagnostics";
    const LANGUAGE_AUTO = "auto";
    const ID_LENGTH = 8;

    function isId(value) as Boolean {
        return value instanceof ByteArray && value.size() == ID_LENGTH;
    }

    function watchId() as ByteArray {
        var stored = Application.Storage.getValue(KEY_WATCH_ID);
        if (isId(stored)) {
            return stored;
        }
        var id = Cryptography.randomBytes(ID_LENGTH);
        Application.Storage.setValue(KEY_WATCH_ID, id);
        return id;
    }

    function pairedMac() as Dictionary? {
        var id = Application.Storage.getValue(KEY_MAC_ID);
        var name = Application.Storage.getValue(KEY_MAC_NAME);
        if (!isId(id) || !(name instanceof String)) {
            return null;
        }
        return {:id => id, :name => name};
    }

    function setPairedMac(id as ByteArray, name as String) as Void {
        Application.Storage.setValue(KEY_MAC_ID, id);
        Application.Storage.setValue(KEY_MAC_NAME, name);
    }

    function forgetMac() as Void {
        Application.Storage.deleteValue(KEY_MAC_ID);
        Application.Storage.deleteValue(KEY_MAC_NAME);
    }

    function buttonMap() as Dictionary {
        return ButtonMap.sanitize(Application.Storage.getValue(KEY_BUTTON_MAP));
    }

    function setButtonAction(button as Number, action as Number) as Void {
        var map = buttonMap();
        map[button] = action;
        Application.Storage.setValue(KEY_BUTTON_MAP, map);
    }

    function resetButtons() as Void {
        Application.Storage.deleteValue(KEY_BUTTON_MAP);
    }

    function language() as String {
        var v = Application.Storage.getValue(KEY_LANGUAGE);
        if (v instanceof String && L10n.isSupported(v)) {
            return v;
        }
        return LANGUAGE_AUTO;
    }

    function setLanguage(code as String) as Void {
        Application.Storage.setValue(KEY_LANGUAGE, code);
    }

    function diagnostics() as Boolean {
        return Application.Storage.getValue(KEY_DIAGNOSTICS) == true;
    }

    function setDiagnostics(on as Boolean) as Void {
        Application.Storage.setValue(KEY_DIAGNOSTICS, on);
    }

    function pairingPromptAnswered() as Boolean {
        return Application.Storage.getValue(KEY_PROMPT_ANSWERED) == true;
    }

    function setPairingPromptAnswered() as Void {
        Application.Storage.setValue(KEY_PROMPT_ANSWERED, true);
    }
}
