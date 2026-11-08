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
    var expected = ["status_not_paired", "status_searching", "status_connecting", "status_connected", "status_confirm_on_mac", "status_rejected", "timer_running", "timer_paused", "menu_reset_timer", "menu_settings", "menu_exit", "settings_buttons", "settings_pairing", "settings_language", "button_up", "button_down", "button_start", "button_back", "action_next", "action_previous", "action_timer_toggle", "action_timer_reset", "action_none", "buttons_reset_defaults", "pairing_current", "pairing_none", "pairing_start", "pairing_forget", "pairing_forget_confirm", "pairing_select_mac", "pairing_no_macs", "pairing_paired", "prompt_pair_now", "language_auto", "language_en", "language_ru"];
    var en = L10n.resource("en");
    var ru = L10n.resource("ru");
    Test.assertEqual(en.size(), expected.size());
    Test.assertEqual(ru.size(), expected.size());
    for (var i = 0; i < expected.size(); i++) {
        Test.assert(en[expected[i]] instanceof String);
        Test.assert(ru[expected[i]] instanceof String);
    }
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
