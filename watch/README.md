# Garmin Clicker — watch app (Connect IQ)

Fenix 6 family (fenix6, fenix6pro, fenix6s, fenix6spro, fenix6xpro), Connect IQ SDK 9.3.0.
The SDK path is read from `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`;
the signing key is `~/.connectiq/developer_key.der` (override with `KEY=...`).

## Build

```
make -C watch build       # bin/GarminClicker.prg for DEVICE (default fenix6)
make -C watch build-all   # bin/<device>/GarminClicker.prg for all 5 products
make -C watch sim         # run in the simulator
```

## Tests

```
make -C watch test
```

Builds with `-t`, starts the simulator if it is not running (and waits until ready), runs
`monkeydo bin/test.prg fenix6 -t` and fails (non-zero exit) if any test fails. The simulator is
left running. Test sources live in `test/` and are marked `(:test)`.

## Install on the watch

Connect the watch via USB and copy `bin/GarminClicker.prg` to `GARMIN/APPS` on the watch.
If the watch mounts over MTP, use OpenMTP or Android File Transfer.
