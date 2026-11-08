import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;

// BLE central link to the Mac app (see "Протокол — что делают часы").
// Modes: normal (reconnect to the saved Mac, if any) and pairing (list Macs in pairing mode,
// connect to the chosen one, wait for approval on the Mac).
// Every GATT operation goes through RequestQueue: one in flight at a time.
class BleLink extends BluetoothLowEnergy.BleDelegate {
    const FALLBACK_MAC_NAME = "Mac";
    const CONNECT_TIMEOUT_MS = 10000;
    const CONFIRM_TIMEOUT_MS = 60000;
    const TICK_MS = 500;
    const MAX_CANDIDATES = 8;
    const MAX_IGNORED = 8;

    private var _serviceUuid as BluetoothLowEnergy.Uuid;
    private var _commandUuid as BluetoothLowEnergy.Uuid;
    private var _statusUuid as BluetoothLowEnergy.Uuid;
    private var _macInfoUuid as BluetoothLowEnergy.Uuid;
    private var _pairingAdvUuid as BluetoothLowEnergy.Uuid;

    private var _queue as RequestQueue;
    private var _ticker as Timer.Timer? = null;
    private var _onStateChange as (Method() as Void)? = null;

    private var _state as Number = LinkState.LINK_NOT_PAIRED;
    private var _pairing as Boolean = false;
    private var _registered as Boolean = false;
    private var _wantScan as Boolean = false;
    private var _scanning as Boolean = false;

    private var _device as BluetoothLowEnergy.Device? = null;
    private var _target as BluetoothLowEnergy.ScanResult? = null;
    private var _targetName as String = FALLBACK_MAC_NAME;
    private var _macInfo as Dictionary? = null;
    private var _connectDeadline as Number? = null;
    private var _confirmDeadline as Number? = null;

    // Pairing list: parallel arrays of scan results and their advertised names.
    private var _candidates as Array<BluetoothLowEnergy.ScanResult> = [];
    private var _candidateNames as Array<String> = [];
    // Devices that answered with another Mac's ID during reconnect; skipped while scanning.
    private var _ignored as Array<BluetoothLowEnergy.ScanResult> = [];

    function initialize() {
        BleDelegate.initialize();
        _serviceUuid = BluetoothLowEnergy.stringToUuid(Protocol.SERVICE_UUID);
        _commandUuid = BluetoothLowEnergy.stringToUuid(Protocol.COMMAND_UUID);
        _statusUuid = BluetoothLowEnergy.stringToUuid(Protocol.STATUS_UUID);
        _macInfoUuid = BluetoothLowEnergy.stringToUuid(Protocol.MAC_INFO_UUID);
        _pairingAdvUuid = BluetoothLowEnergy.stringToUuid(Protocol.PAIRING_ADV_UUID);
        _queue = new RequestQueue(method(:clock));
        _queue.setOnTimeout(method(:linkLost));

        BluetoothLowEnergy.setDelegate(self);
        try {
            BluetoothLowEnergy.registerProfile({
                :uuid => _serviceUuid,
                :characteristics => [
                    {:uuid => _commandUuid},
                    {:uuid => _statusUuid, :descriptors => [BluetoothLowEnergy.cccdUuid()]},
                    {:uuid => _macInfoUuid}
                ]
            });
        } catch (e) {
            System.println("registerProfile failed: " + e.getErrorMessage());
        }
        resumeNormal();
    }

    function clock() as Number {
        return System.getTimer();
    }

    // ---- Contract used by the UI ----

    function state() as Number {
        return _state;
    }

    function macName() as String? {
        var mac = Settings.pairedMac();
        return mac == null ? null : mac[:name] as String;
    }

    function setOnStateChange(callback as (Method() as Void)?) as Void {
        _onStateChange = callback;
    }

    // NEXT / PREVIOUS. callback(false) right away when not connected or the queue is full.
    function send(action as Number, callback as Method(ok as Boolean) as Void) as Void {
        if (_state != LinkState.LINK_CONNECTED) {
            callback.invoke(false);
            return;
        }
        var req = new BleRequest(:cmd, method(:issue), callback, true);
        req.payload = action == ButtonMap.ACTION_PREVIOUS ? Protocol.encodePrevious() : Protocol.encodeNext();
        if (!_queue.enqueue(req)) {
            callback.invoke(false);
        }
        updateTicker();
    }

    // Drops the current link and lists Macs advertising pairing mode.
    function startPairing() as Void {
        drop();
        _pairing = true;
        _candidates = [];
        _candidateNames = [];
        setState(LinkState.LINK_SEARCHING);
        setScan(true);
    }

    function isPairing() as Boolean {
        return _pairing;
    }

    function candidateNames() as Array<String> {
        return _candidateNames;
    }

    // Connect to the chosen Mac from the pairing list.
    function selectCandidate(index as Number) as Void {
        if (!_pairing || index < 0 || index >= _candidates.size()) {
            return;
        }
        connect(_candidates[index], _candidateNames[index]);
    }

    // Leave pairing (Back on the pairing screen): back to the saved Mac, if any.
    function cancelPairing() as Void {
        if (!_pairing) {
            return;
        }
        drop();
        resumeNormal();
    }

    function forget() as Void {
        drop();
        _pairing = false;
        Settings.forgetMac();
        setState(LinkState.LINK_NOT_PAIRED);
    }

    // App is stopping: release the radio.
    function shutdown() as Void {
        _onStateChange = null;
        drop();
        stopTicker();
    }

    // ---- State machine ----

    private function resumeNormal() as Void {
        _pairing = false;
        if (Settings.pairedMac() == null) {
            setScan(false);
            setState(LinkState.LINK_NOT_PAIRED);
        } else {
            setState(LinkState.LINK_SEARCHING);
            setScan(true);
        }
    }

    private function setState(state as Number) as Void {
        _state = state;
        _confirmDeadline = state == LinkState.LINK_CONFIRM ? clock() + CONFIRM_TIMEOUT_MS : null;
        if (state != LinkState.LINK_CONNECTING) {
            _connectDeadline = null;
        }
        updateTicker();
        changed();
    }

    private function changed() as Void {
        if (_onStateChange != null) {
            (_onStateChange as Method() as Void).invoke();
        }
    }

    // Stop scanning, fail pending requests, release the device.
    private function drop() as Void {
        setScan(false);
        _queue.clear();
        if (_device != null) {
            var device = _device as BluetoothLowEnergy.Device;
            _device = null;
            try {
                BluetoothLowEnergy.unpairDevice(device);
            } catch (e) {
                System.println("unpairDevice failed: " + e.getErrorMessage());
            }
        }
        _target = null;
        _macInfo = null;
        _connectDeadline = null;
        _confirmDeadline = null;
    }

    // Disconnect, a failed Status read, a timeout, a missing service: start searching again.
    // In pairing mode this returns to the list.
    function linkLost() as Void {
        drop();
        if (_pairing) {
            setState(LinkState.LINK_SEARCHING);
            setScan(true);
        } else {
            resumeNormal();
        }
    }

    private function connect(result as BluetoothLowEnergy.ScanResult, name as String) as Void {
        setScan(false);
        _target = result;
        _targetName = name;
        var device = null;
        try {
            device = BluetoothLowEnergy.pairDevice(result);
        } catch (e) {
            System.println("pairDevice failed: " + e.getErrorMessage());
        }
        if (device == null) {
            linkLost();
            return;
        }
        _device = device;
        setState(LinkState.LINK_CONNECTING);
        _connectDeadline = clock() + CONNECT_TIMEOUT_MS;
        updateTicker();
    }

    private function setScan(on as Boolean) as Void {
        _wantScan = on;
        applyScan();
    }

    private function applyScan() as Void {
        var on = _wantScan && _registered;
        if (on == _scanning) {
            return;
        }
        _scanning = on;
        BluetoothLowEnergy.setScanState(on ? BluetoothLowEnergy.SCAN_STATE_SCANNING : BluetoothLowEnergy.SCAN_STATE_OFF);
    }

    // Applies a Status value (read or notify). Idempotent: reads and notifies may repeat a value.
    private function applyStatus(value as Number) as Void {
        if (value == Protocol.STATUS_ACCEPTED) {
            if (_pairing) {
                if (_macInfo == null) {
                    return; // not our session yet
                }
                var info = _macInfo as Dictionary;
                var name = info[:name] as String;
                Settings.setPairedMac(info[:id] as ByteArray, name.length() > 0 ? name : _targetName);
                _pairing = false;
                _ignored = [];
            }
            if (_state != LinkState.LINK_CONNECTED) {
                setState(LinkState.LINK_CONNECTED);
            }
        } else if (value == Protocol.STATUS_PENDING) {
            if (_state != LinkState.LINK_CONFIRM) {
                setState(LinkState.LINK_CONFIRM);
            }
        } else if (value == Protocol.STATUS_REJECTED) {
            if (_state == LinkState.LINK_REJECTED) {
                return;
            }
            if (_pairing) {
                // The pairing screen shows the rejection, then restarts the list.
                drop();
            }
            setState(LinkState.LINK_REJECTED);
        }
        // STATUS_AWAITING_HELLO: nothing to do until the next command (it re-sends HELLO).
    }

    // ---- GATT operations (one in flight; `step` of the current request says which) ----

    private function characteristic(uuid as BluetoothLowEnergy.Uuid) as BluetoothLowEnergy.Characteristic? {
        if (_device == null) {
            return null;
        }
        var service = (_device as BluetoothLowEnergy.Device).getService(_serviceUuid);
        return service == null ? null : service.getCharacteristic(uuid);
    }

    private function enqueueSetup(step as Symbol) as Void {
        _queue.enqueue(new BleRequest(step, method(:issue), null, false));
        updateTicker();
    }

    // Issues the operation for the current request's step. A missing service/characteristic
    // (e.g. broadcasting switched off on the Mac) or a refused request means the link is lost.
    function issue() as Void {
        var req = _queue.current();
        if (req == null) {
            return;
        }
        var step = req.step;
        var ok = false;
        try {
            if (step == :macInfo) {
                ok = read(_macInfoUuid);
            } else if (step == :statusRead || step == :cmdStatus) {
                ok = read(_statusUuid);
            } else if (step == :cccd) {
                var status = characteristic(_statusUuid);
                var cccd = status == null ? null : status.getDescriptor(BluetoothLowEnergy.cccdUuid());
                if (cccd != null) {
                    cccd.requestWrite([0x01, 0x00]b);
                    ok = true;
                }
            } else if (step == :hello || step == :cmdHello) {
                ok = write(Protocol.encodeHello(Settings.watchId(), Protocol.WATCH_NAME));
            } else if (step == :cmd || step == :cmdRetry) {
                ok = write(req.payload as ByteArray);
            }
        } catch (e) {
            System.println("GATT request failed: " + e.getErrorMessage());
            ok = false;
        }
        if (!ok) {
            linkLost();
        }
    }

    private function read(uuid as BluetoothLowEnergy.Uuid) as Boolean {
        var c = characteristic(uuid);
        if (c == null) {
            return false;
        }
        c.requestRead();
        return true;
    }

    private function write(value as ByteArray) as Boolean {
        var c = characteristic(_commandUuid);
        if (c == null) {
            return false;
        }
        c.requestWrite(value, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        return true;
    }

    // Moves the in-flight request to its next operation.
    private function advance(req as BleRequest, step as Symbol) as Void {
        req.step = step;
        _queue.touch();
        issue();
    }

    private function complete(ok as Boolean) as Void {
        _queue.onComplete(ok);
        updateTicker();
    }

    // ---- BleDelegate callbacks ----

    function onProfileRegister(uuid as BluetoothLowEnergy.Uuid, status as BluetoothLowEnergy.Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS) {
            _registered = true;
            applyScan();
        } else {
            System.println("profile registration failed: " + status);
        }
    }

    function onScanResults(scanResults as BluetoothLowEnergy.Iterator) as Void {
        if (!_scanning) {
            return;
        }
        var listChanged = false;
        for (var r = scanResults.next(); r != null; r = scanResults.next()) {
            if (!(r instanceof BluetoothLowEnergy.ScanResult)) {
                continue;
            }
            var result = r as BluetoothLowEnergy.ScanResult;
            if (_pairing) {
                if (advertises(result, _pairingAdvUuid) && addCandidate(result)) {
                    listChanged = true;
                }
            } else if (advertises(result, _serviceUuid) && indexOf(_ignored, result) < 0) {
                connect(result, FALLBACK_MAC_NAME);
                return;
            }
        }
        if (listChanged) {
            changed();
        }
    }

    function onConnectedStateChanged(device as BluetoothLowEnergy.Device, state as BluetoothLowEnergy.ConnectionState) as Void {
        if (_device == null || device != _device) {
            return; // a device we already dropped (callbacks pass the object pairDevice returned)
        }
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            if (_state != LinkState.LINK_CONNECTING) {
                return;
            }
            _connectDeadline = null;
            enqueueSetup(:macInfo);
        } else {
            linkLost();
        }
    }

    function onCharacteristicRead(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status, value as ByteArray) as Void {
        var req = _queue.current();
        if (req == null) {
            return;
        }
        var ok = status == BluetoothLowEnergy.STATUS_SUCCESS && value != null;
        if (req.step == :macInfo && characteristic.getUuid().equals(_macInfoUuid)) {
            onMacInfo(ok ? Protocol.decodeMacInfo(value) : null);
        } else if (characteristic.getUuid().equals(_statusUuid) && (req.step == :statusRead || req.step == :cmdStatus)) {
            if (!ok || value.size() < 1) {
                // The Mac no longer answers (e.g. its service is gone): the link is lost.
                linkLost();
                return;
            }
            var v = value[0];
            if (req.step == :statusRead) {
                if (v == Protocol.STATUS_AWAITING_HELLO) {
                    linkLost(); // HELLO was not taken at all
                    return;
                }
                complete(true);
                applyStatus(v);
            } else if (v == Protocol.STATUS_AWAITING_HELLO) {
                advance(req, :cmdHello);
            } else {
                complete(false);
                applyStatus(v);
            }
        }
    }

    function onCharacteristicWrite(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status) as Void {
        var req = _queue.current();
        if (req == null || !characteristic.getUuid().equals(_commandUuid)) {
            return;
        }
        var ok = status == BluetoothLowEnergy.STATUS_SUCCESS;
        var step = req.step;
        if (step == :hello) {
            // Whatever the write status, the Status value tells what the Mac decided.
            advance(req, :statusRead);
        } else if (step == :cmdHello) {
            advance(req, :cmdRetry);
        } else if (step == :cmd) {
            if (ok) {
                complete(true);
            } else {
                // Do not rely on the ATT code reaching us: ask the Mac why via Status.
                advance(req, :cmdStatus);
            }
        } else if (step == :cmdRetry) {
            complete(ok);
        }
    }

    function onDescriptorWrite(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status) as Void {
        var req = _queue.current();
        if (req == null || req.step != :cccd) {
            return;
        }
        if (status != BluetoothLowEnergy.STATUS_SUCCESS) {
            linkLost();
            return;
        }
        complete(true);
        enqueueSetup(:hello);
    }

    function onCharacteristicChanged(characteristic as BluetoothLowEnergy.Characteristic, value as ByteArray) as Void {
        if (_device != null && characteristic.getUuid().equals(_statusUuid) && value.size() >= 1) {
            applyStatus(value[0]);
        }
    }

    private function onMacInfo(info as Dictionary?) as Void {
        if (info == null) {
            linkLost();
            return;
        }
        if (!_pairing) {
            var paired = Settings.pairedMac();
            if (paired == null || !sameBytes(info[:id] as ByteArray, paired[:id] as ByteArray)) {
                // Another Mac advertising our service: skip it from now on.
                if (_target != null) {
                    _ignored.add(_target as BluetoothLowEnergy.ScanResult);
                    if (_ignored.size() > MAX_IGNORED) {
                        _ignored = _ignored.slice(1, null);
                    }
                }
                linkLost();
                return;
            }
        }
        _macInfo = info;
        complete(true);
        enqueueSetup(:cccd);
    }

    // ---- Timer: request timeouts, connect and confirmation deadlines ----

    function onTick() as Void {
        var now = clock();
        if (_connectDeadline != null && now >= (_connectDeadline as Number)) {
            linkLost();
        } else if (_confirmDeadline != null && now >= (_confirmDeadline as Number)) {
            linkLost();
        } else {
            _queue.tick();
        }
        updateTicker();
    }

    private function updateTicker() as Void {
        var needed = _queue.pending() > 0 || _connectDeadline != null || _confirmDeadline != null;
        if (needed && _ticker == null) {
            _ticker = new Timer.Timer();
            (_ticker as Timer.Timer).start(method(:onTick), TICK_MS, true);
        } else if (!needed) {
            stopTicker();
        }
    }

    private function stopTicker() as Void {
        if (_ticker != null) {
            (_ticker as Timer.Timer).stop();
            _ticker = null;
        }
    }

    // ---- Helpers ----

    private function advertises(result as BluetoothLowEnergy.ScanResult, uuid as BluetoothLowEnergy.Uuid) as Boolean {
        var uuids = result.getServiceUuids();
        for (var u = uuids.next(); u != null; u = uuids.next()) {
            if (uuid.equals(u)) {
                return true;
            }
        }
        return false;
    }

    // Adds a new Mac to the pairing list (or refreshes a known one). True if the list grew.
    private function addCandidate(result as BluetoothLowEnergy.ScanResult) as Boolean {
        var i = indexOf(_candidates, result);
        if (i >= 0) {
            _candidates[i] = result;
            return false;
        }
        if (_candidates.size() >= MAX_CANDIDATES) {
            return false;
        }
        var name = result.getDeviceName();
        _candidates.add(result);
        _candidateNames.add(name != null ? name : FALLBACK_MAC_NAME);
        return true;
    }

    private function indexOf(list as Array<BluetoothLowEnergy.ScanResult>, result as BluetoothLowEnergy.ScanResult) as Number {
        for (var i = 0; i < list.size(); i++) {
            if (list[i].isSameDevice(result)) {
                return i;
            }
        }
        return -1;
    }

    private function sameBytes(a as ByteArray, b as ByteArray) as Boolean {
        if (a.size() != b.size()) {
            return false;
        }
        for (var i = 0; i < a.size(); i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }
}
