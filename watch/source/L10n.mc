import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runtime language choice. Only the active dictionary is kept in memory; the English
// fallback is loaded lazily, and only when a key is missing from the active language.
module L10n {
    // The one table of supported languages; everything else (resolve, resource, the stored
    // setting's validation, the Language menu) is driven by it. Per entry: :code (stored
    // setting), :rez (JSON strings), :label (string key of its Language menu item), :device
    // (the device language "Automatic" maps to it). The first entry is the fallback.
    // Adding a language: its JSON file (+ jsonData.xml) and one entry here.
    const LANGUAGES = [
        {:code => "en", :rez => Rez.JsonData.L10nEn, :label => "language_en", :device => System.LANGUAGE_ENG},
        {:code => "ru", :rez => Rez.JsonData.L10nRu, :label => "language_ru", :device => System.LANGUAGE_RUS}
    ];

    var _current as Dictionary? = null;
    var _fallback as Dictionary? = null;

    function find(code as String) as Dictionary? {
        for (var i = 0; i < LANGUAGES.size(); i++) {
            if ((LANGUAGES[i][:code] as String).equals(code)) {
                return LANGUAGES[i];
            }
        }
        return null;
    }

    function isSupported(code as String) as Boolean {
        return find(code) != null;
    }

    // setting: "auto" or a table code (anything else is treated as auto).
    function resolve(setting as String, deviceLanguage as Number) as String {
        if (isSupported(setting)) {
            return setting;
        }
        for (var i = 0; i < LANGUAGES.size(); i++) {
            if (LANGUAGES[i][:device] == deviceLanguage) {
                return LANGUAGES[i][:code] as String;
            }
        }
        return LANGUAGES[0][:code] as String;
    }

    function resource(code as String) as Dictionary {
        var entry = find(code);
        if (entry == null) {
            entry = LANGUAGES[0];
        }
        return WatchUi.loadResource(entry[:rez] as ResourceId) as Dictionary;
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
            _fallback = resource(LANGUAGES[0][:code] as String);
        }
        v = (_fallback as Dictionary)[key];
        return v instanceof String ? v : key;
    }
}
