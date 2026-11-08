import Toybox.Lang;

// Connection states shown on the main screen. Shared by LinkStub and (W5) BleLink.
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
