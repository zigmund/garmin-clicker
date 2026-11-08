# Clicker

A presentation clicker on your Garmin watch. Down = next slide, Up = previous slide,
Start = presentation timer. A small macOS menu bar app receives the presses over
Bluetooth LE and turns them into key presses (arrows, Page Up/Down or Space) for
the frontmost app: Google Slides, Keynote, PowerPoint, a web page.

- `watch/` — Connect IQ watch app (Monkey C), 78 five-button models
  (fēnix 5 Plus…9 Pro, epix, enduro, MARQ, Forerunner, Descent, D2).
- `mac/` — menu bar app (Swift, macOS 14+).

## Install

Download the files from the latest [release](../../releases/latest).

### Mac

1. Unzip `GarminClicker-macOS-X.Y.Z.zip` and move **Garmin Clicker.app** to
   `/Applications`.
2. The app is signed with a self-signed certificate (not notarized by Apple), so
   the first launch is blocked: right-click the app → **Open** → **Open**, or
   System Settings → Privacy & Security → **Open Anyway**.
3. Allow Bluetooth when asked, and grant **Accessibility** (System Settings →
   Privacy & Security → Accessibility) so the app can send key presses.
   Updates signed with the same certificate keep this permission.

### Watch

From the Connect IQ Store, or side-load: take your model's file from
`Clicker-X.Y.Z-watch-prg.zip` (its README lists which file fits which watch), copy it
to `GARMIN/APPS` on the watch over USB (on macOS with
[OpenMTP](https://openmtp.ganeshrvel.com)), unplug.

### Pair

Mac menu → **Pair Watch…** (keep the window open); on the watch answer *Pair a Mac
now?* or open Settings (hold Up) → Pairing → Start pairing, pick your Mac and approve
the request on the Mac.

## Build locally

```sh
make -C watch build            # .prg for DEVICE (default fenix6pro), RELEASE=1 for an optimized build
make -C watch test             # unit tests in the Connect IQ simulator
make -C watch sim              # run in the simulator
make -C watch dist             # store package (.iq) + zip of per-model .prg
make -C mac test
make -C mac run
```

The watch build needs the Connect IQ SDK (SDK Manager) and a developer key at
`~/.connectiq/developer_key.der`; see [mac/README.md](mac/README.md) for the Mac side.
`scripts/ciq-docker.sh KEY_DIR <make args>` runs a watch build in the same Docker
image as CI.

Version shown in the apps: the last `vX.Y.Z` tag, `+N` for commits after it, and the
commit (`+` = uncommitted changes) — e.g. `0.0.1+3 (abc1234)` on the watch.

## Releases

Actions → **Release** → Run workflow (on `main`), choose `patch` / `minor` / `major`.
The workflow takes the latest `vX.Y.Z` tag (none yet → `0.0.1`), builds the Mac app,
every watch model and the store package, then creates tag `vX.Y.Z` and a GitHub release
with:

- `GarminClicker-macOS-X.Y.Z.zip`
- `Clicker-X.Y.Z.iq` — upload it by hand at the
  [Connect IQ developer dashboard](https://apps.garmin.com/developer) (Garmin has no
  upload API)
- `Clicker-X.Y.Z-watch-prg.zip` — per-model `.prg` for side-loading

Every push and pull request runs **CI**: the Mac tests and build, and watch builds for
one model per screen type (signed with a throwaway key).

### One-time setup: repository secrets

Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|---|---|
| `CIQ_DEVELOPER_KEY_BASE64` | `base64 -i ~/.connectiq/developer_key.der \| pbcopy` — the key the store app was first uploaded with; updates signed with another key are rejected |
| `MAC_CERT_P12_BASE64` | the "Garmin Clicker Local" signing identity as .p12, base64 (see below) |
| `MAC_CERT_PASSWORD` | the .p12 export password |

Exporting the Mac signing identity (created by `mac/scripts/make-signing-cert.sh`):
Keychain Access → login → My Certificates → right-click **Garmin Clicker Local** →
Export… → `.p12`, set a password, then `base64 -i garmin-clicker-local.p12 | pbcopy`
and delete the file. (`mac/scripts/export-signing-cert.sh` does the same from the
command line.)
