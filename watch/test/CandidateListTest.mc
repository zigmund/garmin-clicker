import Toybox.Lang;
import Toybox.Test;

// Candidates are plain strings here; "same device" is string equality.
(:test)
class SameProbe {
    function initialize() {}

    function same(a, b) as Boolean {
        return (a as String).equals(b as String);
    }

    function list() as CandidateList {
        return new CandidateList(method(:same), "Mac");
    }
}

(:test)
function candidatesAddAndRefresh(logger as Logger) as Boolean {
    var c = (new SameProbe()).list();
    Test.assert(c.see("a", "Mac A", 0));
    Test.assert(!c.see("a", "Mac A", 1000));
    Test.assert(c.see("b", "Mac B", 1000));
    Test.assertEqual(c.size(), 2);
    Test.assertEqual(c.names()[0], "Mac A");
    Test.assertEqual(c.names()[1], "Mac B");
    Test.assertEqual(c.item(1), "b");
    Test.assert(c.item(2) == null);
    return true;
}

(:test)
function candidatesDedupByName(logger as Logger) as Boolean {
    var c = (new SameProbe()).list();
    c.see("a", "MacBook", 0);
    // Same name from another address (address rotation): one row, the most recently seen device.
    Test.assert(!c.see("b", "MacBook", 1000));
    Test.assertEqual(c.size(), 1);
    Test.assertEqual(c.item(0), "b");
    // A known device renamed to an existing name: the duplicate row goes.
    c.see("x", "Other", 1100);
    Test.assert(c.see("x", "MacBook", 1200));
    Test.assertEqual(c.size(), 1);
    Test.assertEqual(c.item(0), "x");
    return true;
}

(:test)
function candidatesNullNameKeepsKnownName(logger as Logger) as Boolean {
    var c = (new SameProbe()).list();
    c.see("a", "MacBook", 0);
    Test.assert(!c.see("a", null, 500));
    Test.assertEqual(c.names()[0], "MacBook");
    Test.assert(c.see("b", null, 600));
    Test.assertEqual(c.names()[1], "Mac");
    return true;
}

(:test)
function candidatesPruneStale(logger as Logger) as Boolean {
    var c = (new SameProbe()).list();
    c.see("a", "A", 0);
    c.see("b", "B", 10000);
    Test.assert(!c.prune(15000));
    Test.assert(c.prune(15001));
    Test.assertEqual(c.size(), 1);
    Test.assertEqual(c.names()[0], "B");
    c.see("b", "B", 20000);
    Test.assert(!c.prune(35000));
    Test.assert(c.prune(35001));
    Test.assertEqual(c.size(), 0);
    return true;
}

(:test)
function candidatesCapAndClear(logger as Logger) as Boolean {
    var c = (new SameProbe()).list();
    var ids = ["0", "1", "2", "3", "4", "5", "6", "7"];
    for (var i = 0; i < ids.size(); i++) {
        Test.assert(c.see(ids[i], "Mac " + ids[i], i == 0 ? 0 : 10000));
    }
    Test.assert(!c.see("8", "Mac 8", 10000));
    Test.assertEqual(c.size(), 8);
    // Full, but a stale row makes room.
    Test.assert(c.see("8", "Mac 8", 15001));
    Test.assertEqual(c.size(), 8);
    Test.assertEqual(c.names()[7], "Mac 8");
    c.clear();
    Test.assertEqual(c.size(), 0);
    return true;
}
