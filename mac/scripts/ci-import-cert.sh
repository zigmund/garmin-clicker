#!/bin/bash
# CI helper (GitHub macOS runner): imports the self-signed code signing identity
# into a temporary keychain and makes it usable by codesign non-interactively.
#
# Env in:  MAC_CERT_P12_BASE64  base64 of the .p12 (cert + private key)
#          MAC_CERT_PASSWORD    .p12 password
#          KEYCHAIN_PASSWORD    optional, default: random
#          RUNNER_TEMP          optional, default: mktemp dir
# Stdout:  KEYCHAIN=<path>   (append to $GITHUB_ENV; pass to make as KEYCHAIN=)
# All other output goes to stderr.
set -euo pipefail

: "${MAC_CERT_P12_BASE64:?MAC_CERT_P12_BASE64 is required}"
: "${MAC_CERT_PASSWORD:?MAC_CERT_PASSWORD is required}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(/usr/bin/openssl rand -hex 16)}"

DIR="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="$DIR/garmin-clicker-ci.keychain-db"
P12="$DIR/garmin-clicker-ci.p12"
trap 'rm -f "$P12"' EXIT

{
    echo "Creating temporary keychain $KEYCHAIN"
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    security set-keychain-settings "$KEYCHAIN"   # no auto-lock, no timeout
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

    printf '%s' "$MAC_CERT_P12_BASE64" | base64 --decode > "$P12"
    security import "$P12" -k "$KEYCHAIN" -P "$MAC_CERT_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

    # Add to the user search list, keeping the existing keychains.
    existing=()
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"; line="${line%\"}"; line="${line#\"}"
        [ -n "$line" ] && existing+=("$line")
    done < <(security list-keychains -d user)
    security list-keychains -d user -s "$KEYCHAIN" ${existing[@]+"${existing[@]}"}

    # No trust settings needed: codesign signs with an untrusted self-signed
    # identity as long as it is named with --keychain (verified; the identity
    # shows CSSMERR_TP_NOT_TRUSTED in find-identity, which is expected).
    echo "Code signing identities in $KEYCHAIN:"
    ids="$(security find-identity -p codesigning "$KEYCHAIN")"
    echo "$ids"
    grep -q '[1-9][0-9]* identities found' <<< "$ids" || { echo "error: no code signing identity imported." >&2; exit 1; }
} >&2

echo "KEYCHAIN=$KEYCHAIN"
