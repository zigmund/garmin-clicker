import Toybox.Lang;

// One queued GATT transaction. `step` is owned by the link (which operation is in flight);
// `run` issues the first operation; `done` (may be null) receives the outcome.
class BleRequest {
    var step as Symbol;
    var run as Method() as Void;
    var done as (Method(ok as Boolean) as Void)?;
    var isCommand as Boolean;
    var payload as ByteArray? = null;

    function initialize(step as Symbol, run as Method() as Void, done as (Method(ok as Boolean) as Void)?, isCommand as Boolean) {
        self.step = step;
        self.run = run;
        self.done = done;
        self.isCommand = isCommand;
    }
}

// Serializes BLE requests: Connect IQ allows one GATT operation in flight, so the next request
// starts only after the current one completes or times out. Pure: no BLE, injectable clock.
class RequestQueue {
    const MAX_COMMANDS = 3;
    const TIMEOUT_MS = 2000;

    private var _clock as Method() as Number;
    private var _items as Array<BleRequest> = [];
    private var _inFlight as BleRequest? = null;
    private var _deadline as Number = 0;
    private var _starting as Boolean = false;
    private var _onTimeout as (Method() as Void)? = null;

    function initialize(clock as Method() as Number) {
        _clock = clock;
    }

    // Called after a timed-out request's callback, e.g. to treat the link as lost.
    function setOnTimeout(callback as (Method() as Void)?) as Void {
        _onTimeout = callback;
    }

    // False (request dropped) when it is a command and MAX_COMMANDS commands are already pending.
    function enqueue(req as BleRequest) as Boolean {
        if (req.isCommand && pendingCommands() >= MAX_COMMANDS) {
            return false;
        }
        _items.add(req);
        startNext();
        return true;
    }

    // The in-flight request finished: report its outcome and start the next one.
    function onComplete(ok as Boolean) as Void {
        var req = _inFlight;
        if (req == null) {
            return;
        }
        _inFlight = null;
        if (req.done != null) {
            (req.done as Method(ok as Boolean) as Void).invoke(ok);
        }
        startNext();
    }

    // Requests in flight plus waiting.
    function pending() as Number {
        return _items.size() + (_inFlight == null ? 0 : 1);
    }

    function current() as BleRequest? {
        return _inFlight;
    }

    // A multi-step request made progress: restart its deadline.
    function touch() as Void {
        _deadline = _clock.invoke() + TIMEOUT_MS;
    }

    // Fails the in-flight request once its deadline has passed.
    function tick() as Void {
        if (_inFlight == null || _clock.invoke() < _deadline) {
            return;
        }
        var req = _inFlight as BleRequest;
        _inFlight = null;
        if (req.done != null) {
            (req.done as Method(ok as Boolean) as Void).invoke(false);
        }
        if (_onTimeout != null) {
            (_onTimeout as Method() as Void).invoke();
        }
        startNext();
    }

    // Fails every pending request (link lost).
    function clear() as Void {
        var all = _items;
        if (_inFlight != null) {
            all = [_inFlight as BleRequest].addAll(_items);
        }
        _inFlight = null;
        _items = [];
        for (var i = 0; i < all.size(); i++) {
            if (all[i].done != null) {
                (all[i].done as Method(ok as Boolean) as Void).invoke(false);
            }
        }
    }

    private function pendingCommands() as Number {
        var n = (_inFlight != null && (_inFlight as BleRequest).isCommand) ? 1 : 0;
        for (var i = 0; i < _items.size(); i++) {
            if (_items[i].isCommand) {
                n++;
            }
        }
        return n;
    }

    // `run` may complete synchronously (e.g. on a failed request) and re-enter; the guard keeps
    // a single loop in charge of starting requests.
    private function startNext() as Void {
        if (_starting) {
            return;
        }
        _starting = true;
        while (_inFlight == null && _items.size() > 0) {
            var req = _items[0];
            _items = _items.slice(1, null);
            _inFlight = req;
            touch();
            req.run.invoke();
        }
        _starting = false;
    }
}
