#!/bin/sh
# Run a make command for the watch app inside the Connect IQ SDK image (same as CI).
# Usage: scripts/ciq-docker.sh KEY_DIR make-args...   (KEY_DIR holds developer_key.der)
# The image (Alpine) has the SDK and every device; bash/make/zip are added per run.
set -eu
IMAGE=ghcr.io/blackshadev/garmin-connectiq-tools:9.3.0
key_dir=$(cd "$1" && pwd); shift
root=$(cd "$(dirname "$0")/.." && pwd)
exec docker run --rm --platform linux/amd64 \
    -v "$root/watch":/w -v "$key_dir":/k:ro -w /w \
    --entrypoint sh "$IMAGE" -c 'apk add -q bash make zip >/dev/null && exec make "$@" SDK=/connectiq DEVICES_DIR=/root/.Garmin/ConnectIQ/Devices KEY=/k/developer_key.der' make "$@"
