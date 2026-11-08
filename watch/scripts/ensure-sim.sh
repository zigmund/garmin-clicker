#!/bin/sh
# Start the Connect IQ simulator unless running; wait until it accepts connections.
: "${SDK:?}"
if ! pgrep -f "ConnectIQ.app/Contents/MacOS" >/dev/null 2>&1; then
    "$SDK/bin/connectiq" >/dev/null 2>&1 &
fi
# The simulator listens on TCP 1234 when ready.
i=0
while ! nc -z 127.0.0.1 1234 >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then echo "simulator did not become ready" >&2; exit 1; fi
    sleep 1
done
