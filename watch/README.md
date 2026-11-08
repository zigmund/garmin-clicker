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
left running. Test sources live in `test/` and are marked `(:test)`. The test build adds
`test.jungle`, which excludes the `(:withBle)` code (BLE delegate and profile registration): the
runner instantiates the app for every test, and the simulator has no BLE anyway.

## Install on the watch

Connect the watch via USB and copy `bin/GarminClicker.prg` to `GARMIN/APPS` on the watch.
If the watch mounts over MTP, use OpenMTP or Android File Transfer.

## How the link works

- Paired Mac saved: the watch scans for the GATT service `8B1F0001-…` (the Mac's reconnect
  advertising), connects, reads MacInfo and checks the Mac ID, subscribes to Status (CCCD),
  sends HELLO and reads Status: `0x01` → "Connected".
- Pairing (Settings → Pairing → Start pairing, or "Pair now?" → Yes): the watch lists Macs
  advertising the pairing UUID `8B1F00A0-…`; after Start on a name it connects, sends HELLO and
  waits for the Mac's decision (Status `0x03` → "Confirm on Mac…", up to 60 s; `0x01` → "Paired";
  `0x02` → "Rejected by Mac").
- Commands: NEXT/PREV are written with response, one BLE request in flight, at most 3 presses
  pending (more → double vibration). A failed write is never judged by its ATT code (the Mac
  answers 0x80 "HELLO required" / 0x81 "rejected", but Connect IQ may not pass the code through):
  the watch reads Status instead — `0x00` → HELLO and one retry, `0x02` → "Rejected by Mac",
  anything else → double vibration. No answer within 2 s, a failed Status read or a missing
  service (broadcasting switched off on the Mac) → the link is dropped and the watch searches again.

## Device checklist (with the Mac app; the simulator has no BLE)

1. First launch → "No Mac paired. Pair now?" → No → status "Not paired"; after a restart the
   question is not asked again.
2. Mac: "Pair Watch…". Watch: Settings → Pairing → "Start pairing" → the Mac's name is in the
   list → Start → "Confirm on Mac…" → on the Mac "Allow" → "Paired" → main screen
   "Connected / <Mac>".
3. Google Slides: Down → next slide, Up → previous, short vibration; no noticeable delay.
4. Press Down 5 times quickly → slides advance; presses beyond the 3-press queue (if it fills) →
   double vibration.
5. Turn Bluetooth off on the Mac → Down → double vibration, "Searching for Mac…"; turn it back on
   → "Connected" by itself. Same with the Mac's "Broadcast" checkbox off/on (the Mac keeps the
   connection but removes its service; the watch must drop the link and search again).
6. Back while the timer runs → the app does not exit; long Up → menu.
7. Hold Down — check that the firmware does not grab it (music hot key). If it does, disable the
   hot key on the watch (Settings → System → Hot Keys) and note it here.
8. Mac "Deny" during pairing → "Rejected by Mac" (the Mac answers HELLO later with 0x81 during its
   cooldown — still "Rejected by Mac") → back to the list.
9. "Forget Mac" → "Not paired"; the Mac can be paired again only through pairing mode. Also: on
   the Mac "Forget watch" while connected → the next press gets 0x80, the watch re-sends HELLO,
   the Mac answers 0x81 → double vibration and "Rejected by Mac".
10. Remap buttons and change the language — both survive a restart.
