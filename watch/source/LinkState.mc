import Toybox.Lang;

// Connection states reported by BleLink and shown on the main and pairing screens.
module LinkState {
    enum {
        LINK_NOT_PAIRED = 0,
        LINK_SEARCHING = 1,
        LINK_CONNECTING = 2,
        LINK_CONNECTED = 3,
        LINK_CONFIRM = 4,
        LINK_REJECTED = 5
    }
}
