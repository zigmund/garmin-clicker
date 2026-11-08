import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Menu2-based menus: main menu, settings (buttons / pairing / language) and the first-run prompt.
// Each delegate owns its menu and can refresh() the labels (used after a language change).
module Menus {
    const ACTION_KEYS = ["action_none", "action_next", "action_previous", "action_timer_toggle", "action_timer_reset"];
    const BUTTON_KEYS = ["button_up", "button_down", "button_start", "button_back"];
    const LANGUAGE_IDS = ["auto", "en", "ru"];
    const LANGUAGE_KEYS = ["language_auto", "language_en", "language_ru"];

    // Persist the choice, switch the in-memory dictionary and redraw.
    function applyLanguage(code as String) as Void {
        Settings.setLanguage(code);
        L10n.load(L10n.resolve(Settings.language(), System.getDeviceSettings().systemLanguage));
        WatchUi.requestUpdate();
    }

    function openMain(timer, link, onUpdate as Method() as Void) as Void {
        var d = new MainMenuDelegate(timer, link, onUpdate);
        WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_UP);
    }

    function promptPairing(link) as Void {
        WatchUi.pushView(new WatchUi.Confirmation(L10n.t("prompt_pair_now")), new PairPromptDelegate(link), WatchUi.SLIDE_UP);
    }
}

class PairPromptDelegate extends WatchUi.ConfirmationDelegate {
    private var _link;

    function initialize(link) {
        ConfirmationDelegate.initialize();
        _link = link;
    }

    function onResponse(response as Confirm) as Boolean {
        Settings.setPairingPromptAnswered();
        if (response == WatchUi.CONFIRM_YES) {
            _link.startPairing();
        }
        return true;
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;
    private var _timer;
    private var _link;
    private var _onUpdate as Method() as Void;

    function initialize(timer, link, onUpdate as Method() as Void) {
        Menu2InputDelegate.initialize();
        _timer = timer;
        _link = link;
        _onUpdate = onUpdate;
        _menu = new WatchUi.Menu2({:title => ""});
        _menu.addItem(new WatchUi.MenuItem("", null, :reset, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :settings, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :exit, {}));
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    function refresh() as Void {
        _menu.setTitle(WatchUi.loadResource(Rez.Strings.AppName) as String);
        _menu.getItem(0).setLabel(L10n.t("menu_reset_timer"));
        _menu.getItem(1).setLabel(L10n.t("menu_settings"));
        _menu.getItem(2).setLabel(L10n.t("menu_exit"));
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :reset) {
            _timer.reset();
            _onUpdate.invoke();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :settings) {
            var d = new SettingsMenuDelegate(_link, self);
            WatchUi.pushView(d.menu(), d, WatchUi.SLIDE_LEFT);
        } else if (id == :exit) {
            System.exit();
        }
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;
    private var _link;
    private var _parent as MainMenuDelegate;

    function initialize(link, parent as MainMenuDelegate) {
        Menu2InputDelegate.initialize();
        _link = link;
        _parent = parent;
        _menu = new WatchUi.Menu2({:title => ""});
        _menu.addItem(new WatchUi.MenuItem("", null, :buttons, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :pairing, {}));
        _menu.addItem(new WatchUi.MenuItem("", null, :language, {}));
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    // Re-label this menu and everything behind it.
    function refresh() as Void {
        _menu.setTitle(L10n.t("menu_settings"));
        _menu.getItem(0).setLabel(L10n.t("settings_buttons"));
        _menu.getItem(1).setLabel(L10n.t("settings_pairing"));
        _menu.getItem(2).setLabel(L10n.t("settings_language"));
        _parent.refresh();
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
    private var _menu as WatchUi.Menu2;
    private var _button as Number;
    private var _parent as ButtonsMenuDelegate;

    function initialize(button as Number, parent as ButtonsMenuDelegate) {
        Menu2InputDelegate.initialize();
        _button = button;
        _parent = parent;
        var current = Settings.buttonMap()[button];
        _menu = new WatchUi.Menu2({:title => L10n.t(Menus.BUTTON_KEYS[button])});
        for (var a = 0; a < Menus.ACTION_KEYS.size(); a++) {
            _menu.addItem(new WatchUi.CheckboxMenuItem(L10n.t(Menus.ACTION_KEYS[a]), null, a, a == current, {}));
        }
    }

    function menu() as WatchUi.Menu2 {
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
            _link.startPairing();
            // Leave pairing, settings and main menus; the link takes over the screen.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
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
    private var _menu as WatchUi.Menu2;
    private var _parent as SettingsMenuDelegate;

    function initialize(parent as SettingsMenuDelegate) {
        Menu2InputDelegate.initialize();
        _parent = parent;
        _menu = new WatchUi.Menu2({:title => ""});
        for (var i = 0; i < Menus.LANGUAGE_IDS.size(); i++) {
            _menu.addItem(new WatchUi.CheckboxMenuItem("", null, Menus.LANGUAGE_IDS[i], false, {}));
        }
        refresh();
    }

    function menu() as WatchUi.Menu2 {
        return _menu;
    }

    function refresh() as Void {
        var current = Settings.language();
        _menu.setTitle(L10n.t("settings_language"));
        for (var i = 0; i < Menus.LANGUAGE_IDS.size(); i++) {
            var item = _menu.getItem(i) as WatchUi.CheckboxMenuItem;
            item.setLabel(L10n.t(Menus.LANGUAGE_KEYS[i]));
            item.setChecked(current.equals(Menus.LANGUAGE_IDS[i]));
        }
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Menus.applyLanguage(item.getId() as String);
        refresh();
        _parent.refresh();
    }
}
