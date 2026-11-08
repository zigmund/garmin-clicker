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

For daily use and "Launch at Login", copy the app to `/Applications`:
`make clean` and `make app` delete and replace `mac/build/…`, which would
leave the login item pointing at a missing or different app.

```sh
make -C mac app && ditto "mac/build/Garmin Clicker.app" "/Applications/Garmin Clicker.app"
```

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
2. "Pair Watch…" opens the "Pair Watch" window (waiting, with the Mac's
   name in the instructions); a device with the Mac's name and UUID
   `8B1F00A0-…` appears in the scanner. Pairing mode has no timeout: it
   lasts while the window is open. "Pair Watch…" again brings the window to
   the front.
3. Connect, read MacInfo `8B1F0004-…` (8 bytes ID + Mac name), subscribe to
   Status `8B1F0003-…`.
4. Write `02` → error `0x80`. Read Status → `00`. The phone must not show a
   system pairing prompt (refusals use application error codes `0x80`/`0x81`).
5. Write `01 0102030405060708 6970686F6E65` (HELLO "iphone") → success,
   notify `03`; the window shows "“iphone” wants to connect." with Deny /
   Allow.
6. "Allow" → notify `01`; the window shows "Paired with “iphone”." and Done;
   menu shows "Connected: iphone" and "Paired: iphone"; advertising stops (a
   second scanner does not see the Mac). "Done" closes the window.
7. Google Slides in presentation mode: write `02` → next slide, `03` →
   previous slide. Also right after closing the pairing window (the
   presentation was frontmost before it): the first key goes to the
   presentation.
8. Revoke Accessibility → write `02` → `0x0E`, the menu shows the warning.
9. Disconnect → "Waiting for watch…"; the scanner sees a device **without a
   name** with UUID `8B1F0001-…`; reconnect, HELLO with the same ID → notify
   `01` right away, no window.
10. Outside pairing mode, HELLO with ID `01 1111111111111111` → `0x81`,
    notify `02`, no window. Read Status → `02`.
11. "Pair Watch…", HELLO with a new ID → the request in the window says "It
    will replace “iphone”." → "Deny" → notify `02`, the window is back to
    waiting and the Mac is still visible in the scanner; repeating within a
    minute → `0x81`, the window stays waiting.
12. While a request is shown, disconnect from the phone → the window goes
    back to waiting.
13. While a request is shown, close the window (red close button or ⌘W) →
    notify `02`, the named advertisement disappears; "Pair Watch…" again and
    HELLO → a new request (no cooldown). While waiting, "Close" (or Esc) also
    stops the named advertisement. With a paired watch, unchecking
    "Broadcasting" while the window is open closes it.
14. Turn Bluetooth off and on → "Bluetooth is off" and back; advertising
    resumes (also with a paired watch outside pairing mode; a failed start is
    retried after 2…30 s, see the log).
15. "Forget Watch" while connected → notify `00`; the Mac stops advertising.
16. Uncheck "Broadcasting" while the phone is connected → the scanner does not
    see the Mac, writes to Command from the phone fail; status "Broadcasting
    off"; "Paired: …" stays. Check it again → advertising without a name
    again, reconnect without a window. Relaunching the app keeps the checkbox
    state.
17. Switch the language to Русский → menu and windows are in Russian.

Logs: `log stream --level info --predicate 'subsystem == "com.zigmund.GarminClicker"'`.
