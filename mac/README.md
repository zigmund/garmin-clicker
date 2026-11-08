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

Bluetooth checklist (nRF Connect / LightBlue) is added together with the
Bluetooth layer.
