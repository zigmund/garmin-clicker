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
left running. Test sources live in `test/` and are marked `(:test)`, helpers included (classes
and the `TestStorage` module — a global `(:test)` function must itself be a unit test), so none
of it reaches the release build. The test build adds
`test.jungle`, which excludes the `(:withBle)` code (BLE delegate and profile registration): the
runner instantiates the app for every test, and the simulator has no BLE anyway.

## Adding a language

Add `resources/jsonData/l10n_<code>.json` (same keys as `l10n_en.json`, including a
`language_<code>` label added to every JSON file), declare it in `resources/jsonData/jsonData.xml`
and add one entry to `L10n.LANGUAGES` (code, resource, label key, device language). Settings
validation, "Automatic" and the Language menu follow the table; `jsonKeySetsMatch` checks the new
file.

## Install on the watch

Connect the watch via USB and copy `bin/GarminClicker.prg` to `GARMIN/APPS` on the watch.
If the watch mounts over MTP, use OpenMTP or Android File Transfer.

## How the link works

- Paired Mac saved: the watch scans for the GATT service `8B1F0001-…` (the Mac's reconnect
  advertising), connects, reads MacInfo and checks the Mac ID, subscribes to Status (CCCD),
  sends HELLO and reads Status: `0x01` → "Connected".
- Scanning: the first minute of searching scans continuously, then 10 s on / 5 s off until the
  Mac shows up (saves battery while the Mac is away). If the system refuses to connect, the next
  attempt waits ~1 s. The pairing list always scans continuously.
- Pairing (Settings → Pairing → Start pairing, or "Pair now?" → Yes): the watch lists Macs
  advertising the pairing UUID `8B1F00A0-…` (one row per name; a Mac not seen for 15 s drops off
  the list); after Start on a name it connects, sends HELLO and waits for the Mac's decision:
  Status `0x03` → "Confirm on Mac…" for as long as the Mac's pairing window shows the request
  (no timeout on the watch; Back cancels). The result comes as a Status notify; Status is also
  read every 4 s in case the notify is lost. `0x01` → "Paired"; `0x02` → "Rejected by Mac";
  `0x00` (request gone) → back to the list.
- Commands: NEXT/PREV are written with response, one BLE request in flight, at most 3 presses
  pending (more → double vibration). A failed write is never judged by its ATT code (the Mac
  answers 0x80 "HELLO required" / 0x81 "rejected", but Connect IQ may not pass the code through):
  the watch reads Status instead — `0x00` → subscribe to Status again (the subscription is lost
  when the Mac re-publishes its service after "Broadcast" off/on or an app relaunch), HELLO and
  one retry; `0x02` → "Rejected by Mac"; anything else → double vibration. No answer within 2 s,
  a failed Status read or a missing service (broadcasting switched off on the Mac) → the link is
  dropped and the watch searches again.
- A Status notify `0x00` while connected (the Mac forgot this watch or paired another one) →
  the watch sends HELLO right away and settles on "Connected" or "Rejected by Mac".
- "Rejected by Mac" outside pairing: the watch disconnects and stops searching until pairing is
  started again or the app is restarted.

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
   cooldown — still "Rejected by Mac") → back to the list. Leave a request unanswered on the Mac
   for over a minute → the watch keeps showing "Confirm on Mac…" (no timeout); "Allow" still
   pairs. Back on "Confirm on Mac…" cancels.
9. "Forget Mac" → "Not paired"; the Mac can be paired again only through pairing mode. Also: on
   the Mac "Forget watch" while connected (pairing window closed) → within a second the watch
   shows "Rejected by Mac" (notify 0x00 → HELLO → 0x81), no press needed; it stops searching;
   presses → double vibration.
10. Remap buttons and change the language — both survive a restart.
11. Mac "Broadcast" off and on again, or quit and relaunch the Mac app, while the watch stays
    connected → the next press may fail once internally but the slide still advances (the watch
    re-subscribes to Status, sends HELLO and retries); the Mac shows the watch as connected again.
12. Menu → "Reset timer" while the timer runs → 0:00, paused. Menu → "Exit" → "Exit Garmin
    Clicker?" → No stays in the app, Yes exits.
13. Leave the Mac away for a few minutes ("Searching for Mac…") → bring it back → the watch
    reconnects within ~15 s.
