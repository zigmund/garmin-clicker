import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Menu2-based menus: settings (buttons / pairing / language / exit) and the first-run prompt.
// Each delegate owns its menu and can refresh() the labels (used after a language change).
module Menus {
    const ACTION_KEYS = ["action_none", "action_next", "action_previous", "action_timer_toggle", "action_timer_reset"];
    const BUTTON_KEYS = ["button_up", "button_down", "button_start", "button_back"];
    const LANGUAGE_AUTO_KEY = "language_auto";

    // Language menu rows: "Automatic", then one per L10n.LANGUAGES entry.
    function languageIds() as Array<String> {
        var ids = [Settings.LANGUAGE_AUTO] as Array<String>;
        for (var i = 0; i < L10n.LANGUAGES.size(); i++) {
            ids.add(L10n.LANGUAGES[i][:code] as String);
        }
        return ids;
    }

    function languageLabelKeys() as Array<String> {
        var keys = [LANGUAGE_AUTO_KEY] as Array<String>;
        for (var i = 0; i < L10n.LANGUAGES.size(); i++) {
            keys.add(L10n.LANGUAGES[i][:label] as String);
        }
        return keys;
    }

    // Persist the choice, switch the in-memory dictionary and redraw.
    function applyLanguage(code as String) as Void {
        Settings.setLanguage(code);
        L10n.load(L10n.resolve(Settings.language(), System.getDeviceSettings().systemLanguage));
        WatchUi.requestUpdate();
    }

    // Long Up opens the settings menu directly; its last row is Exit.
    function openSettings(link) as Void {
        var d = new SettingsMenuDelegate(link);
        WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_UP);
    }

    // onYes runs when the user accepts; the caller opens the pairing screen once the
    // confirmation is gone (pushing a view from onResponse would race its pop).
    function promptPairing(onYes as Method() as Void) as Void {
        WatchUi.pushView(new WatchUi.Confirmation(L10n.t("prompt_pair_now")), new PairPromptDelegate(onYes), WatchUi.SLIDE_UP);
    }

    // popOnDone: views to pop after a successful pairing (the pairing screen and those under it).
    function openPairing(link, popOnDone as Number) as Void {
        var view = new PairingView(link, popOnDone);
        WatchUi.pushView(view, new PairingDelegate(view), WatchUi.SLIDE_LEFT);
    }
}

class PairPromptDelegate extends WatchUi.ConfirmationDelegate {
    private var _onYes as Method() as Void;

    function initialize(onYes as Method() as Void) {
        ConfirmationDelegate.initialize();
        _onYes = onYes;
    }

    function onResponse(response as Confirm) as Boolean {
        Settings.setPairingPromptAnswered();
        if (response == WatchUi.CONFIRM_YES) {
            _onYes.invoke();
        }
        return true;
    }
}

// "Exit app?": the only way out of the app, and never by a single press.
class ExitConfirmDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            System.exit();
        }
        return true;
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;
    private var _link;
    // Five quick taps on Version toggle the hidden diagnostics.
    private var _versionTaps as TapCounter;

    function initialize(link) {
        Menu2InputDelegate.initialize();
        _link = link;
        _versionTaps = new TapCounter(method(:clock), 5, 1500);
        _menu = new WatchUi.Menu2({:title => ""});
        _menu.addItem(new WatchUi.MenuItem("", null, :buttons, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :pairing, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :language, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :version, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :exit, {}));
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    function refresh() as Void {
        _menu.setTitle(L10n.t("menu_settings"));
        _menu.getItem(0).setLabel(L10n.t("settings_buttons"));
        _menu.getItem(1).setLabel(L10n.t("settings_pairing"));
        _menu.getItem(2).setLabel(L10n.t("settings_language"));
        var version = _menu.getItem(3);
        version.setLabel(L10n.t("settings_version"));
        version.setSubLabel(BuildInfo.VERSION + " (" + BuildInfo.COMMIT + ")" + (Diag.isOn() ? " · diag" : ""));
        _menu.getItem(4).setLabel(L10n.t("menu_exit"));
        WatchUi.requestUpdate();
    }

    function clock() as Number {
        return System.getTimer();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :buttons) {
            var d = new ButtonsMenuDelegate();
            WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_LEFT);
        } else if (id == :pairing) {
            var d = new PairingMenuDelegate(_link);
            WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_LEFT);
        } else if (id == :language) {
            var d = new LanguageMenuDelegate(self);
            WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_LEFT);
        } else if (id == :version) {
            if (_versionTaps.tap()) {
                Diag.setOn(!Diag.isOn());
                Haptics.success();
                refresh();
            }
        } else if (id == :exit) {
            WatchUi.pushView(new WatchUi.Confirmation(L10n.t("menu_exit_confirm")), new ExitConfirmDelegate(), WatchUi.SLIDE_UP);
        }
    }
}

class ButtonsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;

    function initialize() {
        Menu2InputDelegate.initialize();
        _menu = new WatchUi.Menu2({:title => ""});
        for (var i = 0; i < ButtonMap.BUTTONS.size(); i++) {
            _menu.addItem(new WatchUi.MenuItem("", null, ButtonMap.BUTTONS[i], {}));
        }
        _menu.addItem(new WatchUi.MenuItem("", null, :reset, {}));
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    function refresh() as Void {
        var map = Settings.buttonMap();
        _menu.setTitle(L10n.t("settings_buttons"));
        for (var i = 0; i < ButtonMap.BUTTONS.size(); i++) {
            var item = _menu.getItem(i);
            item.setLabel(L10n.t(Menus.BUTTON_KEYS[ButtonMap.BUTTONS[i]]));
            item.setSubLabel(L10n.t(Menus.ACTION_KEYS[map[ButtonMap.BUTTONS[i]] as Number]));
        }
        _menu.getItem(ButtonMap.BUTTONS.size()).setLabel(L10n.t("buttons_reset_defaults"));
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :reset) {
            Settings.resetButtons();
            refresh();
        } else {
            var d = new ActionMenuDelegate(id as Number, self);
            WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_LEFT);
        }
    }
}

class ActionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.CheckboxMenu;
    private var _button as Number;
    private var _parent as ButtonsMenuDelegate;

    function initialize(button as Number, parent as ButtonsMenuDelegate) {
        Menu2InputDelegate.initialize();
        _button = button;
        _parent = parent;
        var current = Settings.buttonMap()[button];
        _menu = new WatchUi.CheckboxMenu({:title => L10n.t(Menus.BUTTON_KEYS[button])});
        for (var a = 0; a < Menus.ACTION_KEYS.size(); a++) {
            _menu.addItem(new WatchUi.CheckboxMenuItem(L10n.t(Menus.ACTION_KEYS[a]), null, a, a == current, {}));
        }
    }

    function menu() as WatchUi.CheckboxMenu {
        return _menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Settings.setButtonAction(_button, item.getId() as Number);
        _parent.refresh();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class PairingMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;
    private var _link;

    function initialize(link) {
        Menu2InputDelegate.initialize();
        _link = link;
        _menu = new WatchUi.Menu2({:title => L10n.t("settings_pairing")});
        _menu.addItem(new WatchUi.MenuItem(L10n.t("pairing_current"), null, :current, {}));
        _menu.addItem(new WatchUi.MenuItem(L10n.t("pairing_start"), null, :start, {}));
        _menu.addItem(new WatchUi.MenuItem(L10n.t("pairing_forget"), null, :forget, {}));
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    function refresh() as Void {
        var name = _link.macName();
        // Menu2 has no "disabled" item; selecting this informational row does nothing.
        (_menu.getItem(0) as WatchUi.MenuItem).setSubLabel(name != null ? name : L10n.t("pairing_none"));
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :start) {
            // Once paired, pop the pairing screen plus the pairing and settings menus.
            Menus.openPairing(_link, 3);
        } else if (id == :forget) {
            WatchUi.pushView(new WatchUi.Confirmation(L10n.t("pairing_forget_confirm")), new ForgetDelegate(_link, self), WatchUi.SLIDE_UP);
        }
    }
}

class ForgetDelegate extends WatchUi.ConfirmationDelegate {
    private var _link;
    private var _parent as PairingMenuDelegate;

    function initialize(link, parent as PairingMenuDelegate) {
        ConfirmationDelegate.initialize();
        _link = link;
        _parent = parent;
    }

    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _link.forget();
            _parent.refresh();
        }
        return true;
    }
}

class LanguageMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.CheckboxMenu;
    private var _parent as SettingsMenuDelegate;

    function initialize(parent as SettingsMenuDelegate) {
        Menu2InputDelegate.initialize();
        _parent = parent;
        _menu = new WatchUi.CheckboxMenu({:title => ""});
        var ids = Menus.languageIds();
        for (var i = 0; i < ids.size(); i++) {
            _menu.addItem(new WatchUi.CheckboxMenuItem("", null, ids[i], false, {}));
        }
        refresh();
    }

    function menu() as WatchUi.CheckboxMenu {
        return _menu;
    }

    function refresh() as Void {
        var current = Settings.language();
        var ids = Menus.languageIds();
        var keys = Menus.languageLabelKeys();
        _menu.setTitle(L10n.t("settings_language"));
        for (var i = 0; i < ids.size(); i++) {
            var item = _menu.getItem(i) as WatchUi.CheckboxMenuItem;
            item.setLabel(L10n.t(keys[i]));
            item.setChecked(current.equals(ids[i]));
        }
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Menus.applyLanguage(item.getId() as String);
        refresh();
        _parent.refresh();
    }
}
