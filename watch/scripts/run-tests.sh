#!/bin/sh
# Run bin/test.prg in the simulator; exit non-zero if any test failed.
: "${SDK:?}" "${DEVICE:?}"
HERE=$(dirname "$0")
SDK="$SDK" sh "$HERE/ensure-sim.sh" || exit 1
out=$(mktemp)
"$SDK/bin/monkeydo" bin/test.prg "$DEVICE" -t >"$out" 2>&1
cat "$out"
# monkeydo exits non-zero even when tests pass, so judge by its output only.
if grep -Eq "FAILED|ERROR|Unhandled Exception" "$out"; then rm -f "$out"; echo "tests failed" >&2; exit 1; fi
if ! grep -q "PASSED" "$out"; then rm -f "$out"; echo "no PASSED marker in output" >&2; exit 1; fi
rm -f "$out"
