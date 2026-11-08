import Toybox.Lang;

// The pairing list: Macs seen advertising pairing mode, in the order first seen.
// One row per device and per name (a Mac that rotates its address shows up once, as the most
// recently seen device); rows not seen for STALE_MS are pruned. Pure: devices are opaque,
// compared by the injected `same` (ScanResult.isSameDevice on the watch).
class CandidateList {
    const MAX = 8;
    const STALE_MS = 15000;

    private var _same as Method(a, b) as Boolean;
    private var _fallbackName as String;
    // Each entry: {:item => device, :name => String, :seen => Number}
    private var _entries as Array<Dictionary> = [];

    function initialize(same as Method(a, b) as Boolean, fallbackName as String) {
        _same = same;
        _fallbackName = fallbackName;
    }

    // A device was seen now; name null keeps a known device's name (or uses the fallback).
    // True if the list of names changed.
    function see(item, name as String?, now as Number) as Boolean {
        var index = -1;
        for (var i = 0; i < _entries.size(); i++) {
            if (_same.invoke(_entries[i][:item], item)) {
                index = i;
                break;
            }
        }
        if (name == null) {
            name = index >= 0 ? _entries[index][:name] as String : _fallbackName;
        }
        if (index < 0) {
            index = indexOfName(name);
        }
        if (index < 0) {
            var changed = false;
            if (_entries.size() >= MAX) {
                changed = prune(now);
                if (_entries.size() >= MAX) {
                    return changed;
                }
            }
            _entries.add({:item => item, :name => name, :seen => now});
            return true;
        }
        var entry = _entries[index];
        var changed = !(entry[:name] as String).equals(name);
        entry[:item] = item;
        entry[:name] = name;
        entry[:seen] = now;
        // A renamed device may now duplicate another row's name: keep only this one.
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < _entries.size(); i++) {
            if (i == index || !(_entries[i][:name] as String).equals(name)) {
                kept.add(_entries[i]);
            }
        }
        if (kept.size() != _entries.size()) {
            _entries = kept;
            changed = true;
        }
        return changed;
    }

    // Drops rows not seen for more than STALE_MS. True if any was dropped.
    function prune(now as Number) as Boolean {
        var kept = [] as Array<Dictionary>;
        for (var i = 0; i < _entries.size(); i++) {
            if (now - (_entries[i][:seen] as Number) <= STALE_MS) {
                kept.add(_entries[i]);
            }
        }
        var changed = kept.size() != _entries.size();
        _entries = kept;
        return changed;
    }

    function clear() as Void {
        _entries = [];
    }

    function size() as Number {
        return _entries.size();
    }

    function names() as Array<String> {
        var out = [] as Array<String>;
        for (var i = 0; i < _entries.size(); i++) {
            out.add(_entries[i][:name] as String);
        }
        return out;
    }

    function item(index as Number) {
        return index >= 0 && index < _entries.size() ? _entries[index][:item] : null;
    }

    private function indexOfName(name as String) as Number {
        for (var i = 0; i < _entries.size(); i++) {
            if ((_entries[i][:name] as String).equals(name)) {
                return i;
            }
        }
        return -1;
    }
}
