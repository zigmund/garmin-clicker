import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:test)
function resolveExplicit(logger as Logger) as Boolean {
    Test.assertEqual(L10n.resolve("ru", System.LANGUAGE_ENG), "ru");
    Test.assertEqual(L10n.resolve("en", System.LANGUAGE_RUS), "en");
    return true;
}

(:test)
function resolveAutoRussian(logger as Logger) as Boolean {
    Test.assertEqual(L10n.resolve("auto", System.LANGUAGE_RUS), "ru");
    return true;
}

(:test)
function resolveAutoFallback(logger as Logger) as Boolean {
    Test.assertEqual(L10n.resolve("auto", System.LANGUAGE_DEU), "en");
    Test.assertEqual(L10n.resolve("garbage", System.LANGUAGE_RUS), "ru");
    Test.assertEqual(L10n.resolve("garbage", System.LANGUAGE_DEU), "en");
    return true;
}

(:test)
function jsonKeySetsMatch(logger as Logger) as Boolean {
    var expected = ["status_not_paired", "status_searching", "status_connecting", "status_connected", "status_confirm_on_mac", "status_rejected", "timer_running", "timer_paused", "menu_reset_timer", "menu_settings", "menu_exit", "menu_exit_confirm", "settings_buttons", "settings_pairing", "settings_language", "button_up", "button_down", "button_start", "button_back", "action_next", "action_previous", "action_timer_toggle", "action_timer_reset", "action_none", "buttons_reset_defaults", "pairing_current", "pairing_none", "pairing_start", "pairing_forget", "pairing_forget_confirm", "pairing_select_mac", "pairing_no_macs", "pairing_paired", "prompt_pair_now", "language_auto", "language_en", "language_ru"];
    // Every language in the table, so a new language is checked as soon as it is added.
    for (var l = 0; l < L10n.LANGUAGES.size(); l++) {
        var code = L10n.LANGUAGES[l][:code] as String;
        var strings = L10n.resource(code);
        Test.assertEqualMessage(strings.size(), expected.size(), code);
        for (var i = 0; i < expected.size(); i++) {
            Test.assertMessage(strings[expected[i]] instanceof String, code + ": " + expected[i]);
        }
    }
    return true;
}

(:test)
function languageTableDrivesEverything(logger as Logger) as Boolean {
    Test.assertEqual(L10n.LANGUAGES[0][:code], "en");
    var saved = TestStorage.stash();
    for (var l = 0; l < L10n.LANGUAGES.size(); l++) {
        var entry = L10n.LANGUAGES[l];
        var code = entry[:code] as String;
        // A table code is a valid explicit setting and survives storage validation.
        Test.assert(L10n.isSupported(code));
        Test.assertEqual(L10n.resolve(code, System.LANGUAGE_DEU), code);
        Settings.setLanguage(code);
        Test.assertEqual(Settings.language(), code);
        // "auto" picks it for its device language; the menu label key exists in English.
        Test.assertEqual(L10n.resolve("auto", entry[:device] as Number), code);
        Test.assert(L10n.resource("en")[entry[:label] as String] instanceof String);
    }
    TestStorage.restore(saved);
    Test.assert(!L10n.isSupported("auto"));
    Test.assert(!L10n.isSupported("xx"));
    return true;
}

(:test)
function menuExitConfirmTranslated(logger as Logger) as Boolean {
    L10n.load("en");
    Test.assertEqual(L10n.t("menu_exit_confirm"), "Exit Garmin Clicker?");
    L10n.load("ru");
    Test.assertEqual(L10n.t("menu_exit_confirm"), "Выйти из Garmin Clicker?");
    L10n._current = null;
    return true;
}

(:test)
function tFallsBackToKey(logger as Logger) as Boolean {
    L10n.load("ru");
    Test.assertEqual(L10n.t("no_such_key"), "no_such_key");
    return true;
}

(:test)
function tUsesLoadedLanguage(logger as Logger) as Boolean {
    L10n.load("ru");
    Test.assertEqual(L10n.t("menu_exit"), "Выйти");
    L10n.load("en");
    Test.assertEqual(L10n.t("menu_exit"), "Exit");
    Test.assertEqual(L10n.t("status_searching"), "Searching for Mac…");
    return true;
}
