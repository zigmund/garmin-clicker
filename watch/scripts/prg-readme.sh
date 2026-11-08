#!/bin/sh
# README for the per-model .prg zip: install steps and which file fits which watch.
# Usage: prg-readme.sh DEVICES_DIR VERSION DEVICE_ID...
devices="$1"; version="$2"; shift 2
cat <<TXT
Clicker $version for Garmin watches: one .prg per watch model.

Most people should install Clicker from the Connect IQ Store instead.
To side-load (developer install):
  1. Find your model below and take its .prg file.
  2. Connect the watch by USB. On macOS use OpenMTP (the watch is an MTP device);
     close Garmin Express first.
  3. Copy the file to GARMIN/APPS on the watch, eject, unplug.
  4. Open Clicker from the watch's app list; pair it with the Mac app.

File                      Model
TXT
for d in "$@"; do
    name=$(sed -n 's/.*"displayName"[^"]*"\([^"]*\)".*/\1/p' "$devices/$d/compiler.json" 2>/dev/null | head -1)
    printf '%-25s %s\n' "$d.prg" "${name:-$d}"
done
