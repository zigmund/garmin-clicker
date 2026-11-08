import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

const TEST_KEYS = ["watchId", "macId", "macName", "buttonMap", "language", "pairingPromptAnswered"];

// Storage may hold real values (simulator persists between runs): save, clear, restore.
function stashStorage() as Dictionary {
    var saved = {};
    for (var i = 0; i < TEST_KEYS.size(); i++) {
        var v = Application.Storage.getValue(TEST_KEYS[i]);
        if (v != null) {
            saved[TEST_KEYS[i]] = v;
        }
        Application.Storage.deleteValue(TEST_KEYS[i]);
    }
    return saved;
}

function restoreStorage(saved as Dictionary) as Void {
    for (var i = 0; i < TEST_KEYS.size(); i++) {
        Application.Storage.deleteValue(TEST_KEYS[i]);
        if (saved.hasKey(TEST_KEYS[i])) {
            Application.Storage.setValue(TEST_KEYS[i], saved[TEST_KEYS[i]]);
        }
    }
}

(:test)
function storageFallbacksLanguage(logger as Logger) as Boolean {
    var saved = stashStorage();
    Test.assertEqual(Settings.language(), "auto");
    Application.Storage.setValue("language", 42);
    Test.assertEqual(Settings.language(), "auto");
    Application.Storage.setValue("language", "xx");
    Test.assertEqual(Settings.language(), "auto");
    Settings.setLanguage("ru");
    Test.assertEqual(Settings.language(), "ru");
    restoreStorage(saved);
    return true;
}

(:test)
function storageFallbacksMac(logger as Logger) as Boolean {
    var saved = stashStorage();
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
    Test.assertEqual(mac[:id].size(), 8);
    Test.assertEqual(mac[:id][7], 8);
    Settings.forgetMac();
    Test.assert(Settings.pairedMac() == null);
    restoreStorage(saved);
    return true;
}

(:test)
function storageFallbacksButtons(logger as Logger) as Boolean {
    var saved = stashStorage();
    Application.Storage.setValue("buttonMap", {0 => 77});
    var m = Settings.buttonMap();
    Test.assertEqual(m[ButtonMap.BUTTON_UP], ButtonMap.ACTION_PREVIOUS);
    Application.Storage.setValue("buttonMap", "junk");
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    restoreStorage(saved);
    return true;
}

(:test)
function setAndResetButtons(logger as Logger) as Boolean {
    var saved = stashStorage();
    Settings.setButtonAction(ButtonMap.BUTTON_UP, ButtonMap.ACTION_NONE);
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_UP], ButtonMap.ACTION_NONE);
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_DOWN], ButtonMap.ACTION_NEXT);
    Settings.resetButtons();
    Test.assertEqual(Settings.buttonMap()[ButtonMap.BUTTON_UP], ButtonMap.ACTION_PREVIOUS);
    restoreStorage(saved);
    return true;
}

(:test)
function watchIdStable(logger as Logger) as Boolean {
    var saved = stashStorage();
    var a = Settings.watchId();
    var b = Settings.watchId();
    Test.assertEqual(a.size(), 8);
    Test.assertEqual(b.size(), 8);
    for (var i = 0; i < 8; i++) {
        Test.assertEqual(a[i], b[i]);
    }
    Application.Storage.setValue("watchId", "bad");
    Test.assertEqual(Settings.watchId().size(), 8);
    restoreStorage(saved);
    return true;
}

(:test)
function pairingPromptFlag(logger as Logger) as Boolean {
    var saved = stashStorage();
    Test.assertEqual(Settings.pairingPromptAnswered(), false);
    Application.Storage.setValue("pairingPromptAnswered", "yes");
    Test.assertEqual(Settings.pairingPromptAnswered(), false);
    Settings.setPairingPromptAnswered();
    Test.assertEqual(Settings.pairingPromptAnswered(), true);
    restoreStorage(saved);
    return true;
}
