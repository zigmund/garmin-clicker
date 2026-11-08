import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Storage may hold real values (simulator persists between runs): save, clear, restore.
// A module, not global functions: a global (:test) function must be a unit test.
(:test)
module TestStorage {
    const KEYS = ["watchId", "macId", "macName", "buttonMap", "language", "pairingPromptAnswered"];

    function stash() as Dictionary {
        var saved = {};
        for (var i = 0; i < KEYS.size(); i++) {
            var v = Application.Storage.getValue(KEYS[i]);
            if (v != null) {
                saved[KEYS[i]] = v;
            }
            Application.Storage.deleteValue(KEYS[i]);
        }
        return saved;
    }

    function restore(saved as Dictionary) as Void {
        for (var i = 0; i < KEYS.size(); i++) {
            Application.Storage.deleteValue(KEYS[i]);
            if (saved.hasKey(KEYS[i])) {
                Application.Storage.setValue(KEYS[i], saved[KEYS[i]]);
            }
        }
    }
}

(:test)
function storageFallbacksLanguage(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    Test.assertEqual(Settings.language(), "auto");
    Application.Storage.setValue("language", 42);
    Test.assertEqual(Settings.language(), "auto");
    Application.Storage.setValue("language", "xx");
    Test.assertEqual(Settings.language(), "auto");
    Settings.setLanguage("ru");
    Test.assertEqual(Settings.language(), "ru");
    TestStorage.restore(saved);
    return true;
}

(:test)
function storageFallbacksMac(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    Test.assert(Settings.pairedMac() == null);
    Application.Storage.setValue("macId", "x");
    Application.Storage.setValue("macName", "Mac");
    Test.assert(Settings.pairedMac() == null);
    var id = [1, 2, 3, 4, 5, 6, 7, 8]b;
    Application.Storage.setValue("macId", id);
    Application.Storage.setValue("macName", 5);
    Test.assert(Settings.pairedMac() == null);
    Settings.setPairedMac(id, "My Mac");
    var mac = Settings.pairedMac();
    Test.assert(mac != null);
    Test.assertEqual(mac[:name], "My Mac");
    var macId = (mac as Dictionary)[:id] as ByteArray;
    Test.assertEqual(macId.size(), 8);
    Test.assertEqual(macId[7], 8);
    Settings.forgetMac();
    Test.assert(Settings.pairedMac() == null);
    TestStorage.restore(saved);
    return true;
}

(:test)
function storageFallbacksButtons(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    Application.Storage.setValue("buttonMap", {0 => 77});
    var m = Settings.buttonMap();
    Test.assertEqual(m[ButtonMap.BUTTON_UP], ButtonMap.ACTION_PREVIOUS);
    Application.Storage.setValue("buttonMap", "junk");
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    TestStorage.restore(saved);
    return true;
}

(:test)
function setAndResetButtons(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    Settings.setButtonAction(ButtonMap.BUTTON_UP, ButtonMap.ACTION_NONE);
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_UP], ButtonMap.ACTION_NONE);
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    Settings.resetButtons();
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_UP], ButtonMap.ACTION_PREVIOUS);
    TestStorage.restore(saved);
    return true;
}

(:test)
function watchIdStable(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    var a = Settings.watchId();
    var b = Settings.watchId();
    Test.assertEqual(a.size(), 8);
    Test.assertEqual(b.size(), 8);
    for (var i = 0; i < 8; i++) {
        Test.assertEqual(a[i], b[i]);
    }
    Application.Storage.setValue("watchId", "bad");
    Test.assertEqual(Settings.watchId().size(), 8);
    TestStorage.restore(saved);
    return true;
}

(:test)
function pairingPromptFlag(logger as Logger) as Boolean {
    var saved = TestStorage.stash();
    Test.assertEqual(Settings.pairingPromptAnswered(), false);
    Application.Storage.setValue("pairingPromptAnswered", "yes");
    Test.assertEqual(Settings.pairingPromptAnswered(), false);
    Settings.setPairingPromptAnswered();
    Test.assertEqual(Settings.pairingPromptAnswered(), true);
    TestStorage.restore(saved);
    return true;
}
