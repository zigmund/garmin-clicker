#!/bin/sh
# Start the Connect IQ simulator unless running; wait until it accepts connections on 1234
# (the only port monkeydo/shell can target).
: "${SDK:?}"
PORT=1234
sim_pid=$(pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" | head -1)
if [ -z "$sim_pid" ]; then
    "$SDK/bin/connectiq" >/dev/null 2>&1 &
elif ! lsof -nP -iTCP:$PORT -sTCP:LISTEN -a -p "$sim_pid" >/dev/null 2>&1; then
    # A running simulator that does not listen on 1234 (e.g. it bound 1235 because 1234 was busy
    # at start) cannot be reached by monkeydo. Fail fast instead of waiting.
    ports=$(lsof -nP -iTCP -sTCP:LISTEN -a -p "$sim_pid" 2>/dev/null | awk 'NR>1 {print $9}' | tr '\n' ' ')
    echo "Connect IQ simulator (pid $sim_pid) is running but not listening on port $PORT (listens: $ports)." >&2
    echo "Quit the Connect IQ simulator and re-run." >&2
    exit 1
fi
i=0
while ! nc -z 127.0.0.1 $PORT >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then echo "simulator did not become ready on port $PORT" >&2; exit 1; fi
    sleep 1
done
