import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runtime language choice. Only the active dictionary is kept in memory; the English
// fallback is loaded lazily, and only when a key is missing from the active language.
module L10n {
    const LANGUAGES = ["en", "ru"];

    var _current as Dictionary? = null;
    var _fallback as Dictionary? = null;

    // setting: "auto" | "en" | "ru" (anything else is treated as auto).
    function resolve(setting as String, deviceLanguage as Number) as String {
        if (setting.equals("en") || setting.equals("ru")) {
            return setting;
        }
        return deviceLanguage == System.LANGUAGE_RUS ? "ru" : "en";
    }

    function resource(code as String) as Dictionary {
        var rez = code.equals("ru") ? Rez.JsonData.L10nRu : Rez.JsonData.L10nEn;
        return WatchUi.loadResource(rez) as Dictionary;
    }

    function load(code as String) as Void {
        _current = resource(code);
        _fallback = null;
    }

    function t(key as String) as String {
        if (_current == null) {
            load(resolve(Settings.language(), System.getDeviceSettings().systemLanguage));
        }
        var v = (_current as Dictionary)[key];
        if (v instanceof String) {
            return v;
        }
        if (_fallback == null) {
            _fallback = resource("en");
        }
        v = (_fallback as Dictionary)[key];
        return v instanceof String ? v : key;
    }
}
