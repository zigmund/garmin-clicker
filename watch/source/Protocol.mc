import Toybox.Lang;
import Toybox.StringUtil;

// Wire protocol shared with the Mac app. Change only together with the Mac side.
module Protocol {
    const SERVICE_UUID = "8B1F0001-2C4D-4E5A-9F61-7A3B2C1D0E01";
    const COMMAND_UUID = "8B1F0002-2C4D-4E5A-9F61-7A3B2C1D0E01";
    const STATUS_UUID = "8B1F0003-2C4D-4E5A-9F61-7A3B2C1D0E01";
    const MAC_INFO_UUID = "8B1F0004-2C4D-4E5A-9F61-7A3B2C1D0E01";
    const PAIRING_ADV_UUID = "8B1F00A0-2C4D-4E5A-9F61-7A3B2C1D0E01";
    const CCCD_UUID = "00002902-0000-1000-8000-00805F9B34FB";

    const STATUS_AWAITING_HELLO = 0;
    const STATUS_ACCEPTED = 1;
    const STATUS_REJECTED = 2;
    const STATUS_PENDING = 3;

    const WATCH_NAME = "fenix 6";
    const DEFAULT_NAME = "Garmin";

    const OP_HELLO = 0x01;
    const OP_NEXT = 0x02;
    const OP_PREVIOUS = 0x03;

    const ID_SIZE = 8;
    const MAX_HELLO_NAME_BYTES = 11;
    const MAX_MAC_INFO_SIZE = 22;

    function encodeHello(watchId as ByteArray, name as String) as ByteArray {
        var nameBytes = (name.length() == 0 ? DEFAULT_NAME : name).toUtf8Array();
        var n = nameBytes.size();
        if (n > MAX_HELLO_NAME_BYTES) {
            n = MAX_HELLO_NAME_BYTES;
            // Never cut inside a multi-byte sequence: back off over continuation bytes (10xxxxxx).
            while (n > 0 && (nameBytes[n] & 0xC0) == 0x80) {
                n--;
            }
        }
        var out = new [1 + watchId.size() + n]b;
        out[0] = OP_HELLO;
        for (var i = 0; i < watchId.size(); i++) {
            out[1 + i] = watchId[i];
        }
        for (var i = 0; i < n; i++) {
            out[1 + watchId.size() + i] = nameBytes[i];
        }
        return out;
    }

    function encodeNext() as ByteArray {
        return [OP_NEXT]b;
    }

    function encodePrevious() as ByteArray {
        return [OP_PREVIOUS]b;
    }

    function decodeMacInfo(data as ByteArray) as Dictionary? {
        if (data.size() < ID_SIZE || data.size() > MAX_MAC_INFO_SIZE) {
            return null;
        }
        var name = "";
        if (data.size() > ID_SIZE) {
            var decoded = null;
            try {
                decoded = StringUtil.convertEncodedString(data.slice(ID_SIZE, null), {
                    :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                    :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                    :encoding => StringUtil.CHAR_ENCODING_UTF8
                });
            } catch (e) {
                decoded = null;
            }
            name = (decoded instanceof String) ? decoded : "";
        }
        return {:id => data.slice(0, ID_SIZE), :name => name};
    }
}
