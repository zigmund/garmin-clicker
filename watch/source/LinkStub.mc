import Toybox.Lang;

// Placeholder link until BleLink (W5): same method names, never connects.
class LinkStub {
    function initialize() {}

    function state() as Number {
        return Settings.pairedMac() == null ? LinkState.LINK_NOT_PAIRED : LinkState.LINK_SEARCHING;
    }

    function macName() as String? {
        var mac = Settings.pairedMac();
        return mac == null ? null : mac[:name] as String;
    }

    function send(action as Number, callback as Method(ok as Boolean) as Void) as Void {
        callback.invoke(false);
    }

    function startPairing() as Void {}

    function forget() as Void {
        Settings.forgetMac();
    }
}
