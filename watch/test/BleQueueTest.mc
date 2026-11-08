import Toybox.Lang;
import Toybox.Test;

// Records which requests were started and which callbacks fired, on a fake clock.
(:test)
class QueueProbe {
    var now as Number = 0;
    var started as Array<String> = [];
    var results as Array<Boolean> = [];
    var timeouts as Number = 0;

    function initialize() {}

    function clock() as Number {
        return now;
    }

    function runA() as Void {
        started.add("A");
    }

    function runB() as Void {
        started.add("B");
    }

    function done(ok as Boolean) as Void {
        results.add(ok);
    }

    function timedOut() as Void {
        timeouts++;
    }

    function command(run as Method() as Void) as BleRequest {
        return new BleRequest(:cmd, run, method(:done), true);
    }
}

(:test)
function queueSerializes(logger as Logger) as Boolean {
    var p = new QueueProbe();
    var q = new RequestQueue(p.method(:clock));
    Test.assert(q.enqueue(p.command(p.method(:runA))));
    Test.assert(q.enqueue(p.command(p.method(:runB))));
    Test.assertEqual(p.started.size(), 1);
    Test.assertEqual(p.started[0], "A");
    Test.assertEqual(q.pending(), 2);
    q.onComplete(true);
    Test.assertEqual(p.started.size(), 2);
    Test.assertEqual(p.started[1], "B");
    Test.assertEqual(p.results.size(), 1);
    Test.assert(p.results[0]);
    q.onComplete(true);
    Test.assertEqual(q.pending(), 0);
    Test.assert(q.current() == null);
    return true;
}

(:test)
function queueRejectsFourthPending(logger as Logger) as Boolean {
    var p = new QueueProbe();
    var q = new RequestQueue(p.method(:clock));
    Test.assert(q.enqueue(p.command(p.method(:runA))));
    Test.assert(q.enqueue(p.command(p.method(:runA))));
    Test.assert(q.enqueue(p.command(p.method(:runA))));
    Test.assert(!q.enqueue(p.command(p.method(:runB))));
    Test.assertEqual(q.pending(), 3);
    // Internal (non-command) requests are not limited.
    Test.assert(q.enqueue(new BleRequest(:read, p.method(:runB), null, false)));
    // A finished command frees a slot.
    q.onComplete(true);
    Test.assert(q.enqueue(p.command(p.method(:runB))));
    return true;
}

(:test)
function queueTimeoutFails(logger as Logger) as Boolean {
    var p = new QueueProbe();
    var q = new RequestQueue(p.method(:clock));
    q.setOnTimeout(p.method(:timedOut));
    q.enqueue(p.command(p.method(:runA)));
    q.enqueue(p.command(p.method(:runB)));
    p.now = 1999;
    q.tick();
    Test.assertEqual(p.results.size(), 0);
    p.now = 2000;
    q.tick();
    Test.assertEqual(p.results.size(), 1);
    Test.assert(!p.results[0]);
    Test.assertEqual(p.timeouts, 1);
    Test.assertEqual(p.started.size(), 2);
    Test.assertEqual(p.started[1], "B");
    // The deadline restarts for the next request.
    p.now = 3999;
    q.tick();
    Test.assertEqual(p.results.size(), 1);
    return true;
}

(:test)
function queueTouchExtendsDeadline(logger as Logger) as Boolean {
    var p = new QueueProbe();
    var q = new RequestQueue(p.method(:clock));
    q.enqueue(p.command(p.method(:runA)));
    p.now = 1500;
    q.touch();
    p.now = 3000;
    q.tick();
    Test.assertEqual(p.results.size(), 0);
    p.now = 3500;
    q.tick();
    Test.assertEqual(p.results.size(), 1);
    return true;
}

(:test)
function queueClearFailsEverything(logger as Logger) as Boolean {
    var p = new QueueProbe();
    var q = new RequestQueue(p.method(:clock));
    q.enqueue(p.command(p.method(:runA)));
    q.enqueue(p.command(p.method(:runB)));
    q.clear();
    Test.assertEqual(p.results.size(), 2);
    Test.assert(!p.results[0] && !p.results[1]);
    Test.assertEqual(q.pending(), 0);
    Test.assertEqual(p.started.size(), 1);
    return true;
}
