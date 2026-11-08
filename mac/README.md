# Garmin Clicker for macOS

Menu bar app that receives NEXT / PREV commands from a paired Garmin watch over
Bluetooth LE and turns them into key presses for the frontmost app (slides).

Requirements: macOS 14+, Xcode command line tools with the full Xcode toolchain
(Swift Testing needs it):

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Build and run

```sh
make -C mac test   # unit tests (ClickerCore)
make -C mac app    # builds "mac/build/Garmin Clicker.app" and signs it
make -C mac run    # builds and opens the app
make -C mac clean
```

The app lives in the menu bar only (no Dock icon).

## Code signing (once)

macOS ties the Accessibility permission to the app's signature. With ad-hoc
signing (the fallback) the permission is lost after every rebuild. Create a
local self-signed signing identity once:

```sh
mac/scripts/make-signing-cert.sh
```

It adds the certificate "Garmin Clicker Local" to the login keychain and trusts
it for code signing (macOS asks for your password). Running it again is safe.
After that `make -C mac app` signs with this identity automatically; without it
the build prints a warning and signs ad-hoc.

## Permissions

- **Keyboard control (Accessibility).** Needed to send key presses. Use
  "Allow Keyboard Control…" in the menu, then enable Garmin Clicker in
  System Settings → Privacy & Security → Accessibility. The menu shows a
  warning while the permission is missing.
- **Bluetooth.** macOS asks on first launch; it can be changed in
  System Settings → Privacy & Security → Bluetooth.

## Settings

All in the menu: key scheme (arrows, Page Up / Page Down, Space /
Shift+Space), language (automatic, English, Russian), launch at login,
broadcasting on/off (when a watch is paired), pairing and forgetting the watch.

## Manual check with a phone

Bluetooth checklist with a phone acting as the watch (nRF Connect or
LightBlue). Writes go to Command `8B1F0002-…` (write with response); bytes are
hex.

1. No watch paired and pairing mode off: the phone does **not** see the Mac.
2. "Pair Watch…": a device with the Mac's name and UUID `8B1F00A0-…` appears.
3. Connect, read MacInfo `8B1F0004-…` (8 bytes ID + Mac name), subscribe to
   Status `8B1F0003-…`.
4. Write `02` → error `0x05`. Read Status → `00`.
5. Write `01 0102030405060708 6970686F6E65` (HELLO "iphone") → success,
   notify `03`; the Mac shows "Allow “iphone” to connect?".
6. "Allow" → notify `01`; menu shows "Connected: iphone" and "Paired: iphone";
   advertising stops (a second scanner does not see the Mac).
7. Google Slides in presentation mode: write `02` → next slide, `03` →
   previous slide.
8. Revoke Accessibility → write `02` → `0x0E`, the menu shows the warning.
9. Disconnect → "Waiting for watch…"; the scanner sees a device **without a
   name** with UUID `8B1F0001-…`; reconnect, HELLO with the same ID → notify
   `01` right away, no window.
10. Outside pairing mode, HELLO with ID `01 1111111111111111` → `0x08`,
    notify `02`, no window. Read Status → `02`.
11. "Pair Watch…", HELLO with a new ID → window with "It will replace
    “iphone”." → "Deny" → notify `02`; repeating within a minute → `0x08`,
    no window.
12. While the window is open, disconnect from the phone → the window closes.
13. Pairing mode left idle for 2 min → the named advertisement disappears.
14. Turn Bluetooth off and on → "Bluetooth is off" and back; advertising
    resumes.
15. "Forget Watch" while connected → notify `00`; the Mac stops advertising.
16. Uncheck "Broadcasting" while the phone is connected → the scanner does not
    see the Mac, writes to Command from the phone fail; status "Broadcasting
    off"; "Paired: …" stays. Check it again → advertising without a name
    again, reconnect without a window. Relaunching the app keeps the checkbox
    state.
17. Switch the language to Русский → menu and windows are in Russian.

Logs: `log stream --level info --predicate 'subsystem == "com.zigmund.GarminClicker"'`.
