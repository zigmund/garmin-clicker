import Toybox.Lang;

// Hidden diagnostics (5 taps on Settings → Version): BLE counters drawn on the main and pairing
// screens. The counters are always kept; drawing and per-result scan bookkeeping only when on.
module Diag {
    var regAttempts as Number = 0;
    var profile as String = "-";
    var scanning as Boolean = false;
    var scanResults as Number = 0;
    var withUuids as Number = 0;
    var lastUuid as String = "-";
    var lastName as String = "-";
    var connects as Number = 0;
    var txOk as Number = 0;
    var txFail as Number = 0;
    var _on as Boolean? = null;

    function isOn() as Boolean {
        if (_on == null) {
            _on = Settings.diagnostics();
        }
        return _on as Boolean;
    }

    function setOn(on as Boolean) as Void {
        _on = on;
        Settings.setDiagnostics(on);
    }

    function sent(ok as Boolean) as Void {
        if (ok) {
            txOk++;
        } else {
            txFail++;
        }
    }

    // P: profile status (- = no answer yet, EX = exception), R: registration attempts,
    // S: scanning, C: connections made, tx: commands ok/failed.
    function mainLine() as String {
        return "P:" + profile + " R:" + regAttempts + " S:" + (scanning ? 1 : 0) + " C:" + connects + " tx:" + txOk + "/" + txFail;
    }

    // N: scan results seen, U: those with service UUIDs; u/n: last UUID prefix and device name.
    function pairingLines() as Array<String> {
        return [
            "P:" + profile + " R:" + regAttempts + " S:" + (scanning ? 1 : 0) + " N:" + scanResults + " U:" + withUuids,
            "u:" + lastUuid,
            "n:" + lastName
        ];
    }
}
