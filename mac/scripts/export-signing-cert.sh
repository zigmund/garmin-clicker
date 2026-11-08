#!/bin/bash
# Run once, locally: exports the "Garmin Clicker Local" identity (certificate +
# private key) from the login keychain to a password-protected .p12 for CI.
# macOS will show Keychain Access prompts during the export; that is expected.
#
# `security export` cannot select a single identity, so all identities are
# exported to a temporary file, then only the one named below is kept.
#
# Usage: scripts/export-signing-cert.sh [output.p12]   (default ./garmin-clicker-local.p12)
set -euo pipefail

NAME="${SIGN_CERT_NAME:-Garmin Clicker Local}"
KEYCHAIN="${SIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
OUT="${1:-./garmin-clicker-local.p12}"
OPENSSL=/usr/bin/openssl   # LibreSSL: .p12 readable by `security import`

if [ -n "${EXPORT_PASSWORD:-}" ]; then   # non-interactive (tests)
    PASSWORD="$EXPORT_PASSWORD"
else
    read -r -s -p "Export password for the .p12: " PASSWORD; echo
    read -r -s -p "Repeat password: " AGAIN; echo
    [ "$PASSWORD" = "$AGAIN" ] || { echo "error: passwords do not match." >&2; exit 1; }
fi
[ -n "$PASSWORD" ] || { echo "error: empty password." >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Exporting identities from $KEYCHAIN (approve the keychain prompts)…"
security export -k "$KEYCHAIN" -t identities -f pkcs12 -P "$PASSWORD" -o "$WORK/all.p12"
"$OPENSSL" pkcs12 -in "$WORK/all.p12" -nodes -passin "pass:$PASSWORD" -out "$WORK/all.pem" 2>/dev/null

# Split into one file per PEM block.
awk -v d="$WORK" '/-----BEGIN /{n++; f=sprintf("%s/blk%03d.pem", d, n)} f{print > f} /-----END /{f=""}' "$WORK/all.pem"

cert="" key=""
for f in "$WORK"/blk*.pem; do
    grep -q 'BEGIN CERTIFICATE' "$f" || continue
    if "$OPENSSL" x509 -in "$f" -noout -subject | grep -qF "CN = $NAME" ||
       "$OPENSSL" x509 -in "$f" -noout -subject | grep -qF "CN=$NAME"; then
        cert="$f"; break
    fi
done
[ -n "$cert" ] || { echo "error: identity \"$NAME\" not found in $KEYCHAIN." >&2; exit 1; }

want="$("$OPENSSL" x509 -in "$cert" -noout -modulus)"
for f in "$WORK"/blk*.pem; do
    grep -q 'PRIVATE KEY' "$f" || continue
    if [ "$("$OPENSSL" rsa -in "$f" -noout -modulus 2>/dev/null)" = "$want" ]; then key="$f"; break; fi
done
[ -n "$key" ] || { echo "error: private key for \"$NAME\" is not in the export." >&2; exit 1; }

"$OPENSSL" pkcs12 -export -inkey "$key" -in "$cert" -name "$NAME" -out "$OUT" -passout "pass:$PASSWORD"
chmod 600 "$OUT"
echo "Wrote $OUT"

cat <<MSG

Copy it as base64:
  base64 -i "$OUT" | pbcopy

Add GitHub repository secrets (Settings -> Secrets and variables -> Actions):
  MAC_CERT_P12_BASE64  = the base64 text just copied
  MAC_CERT_PASSWORD    = the password you entered above
Then delete $OUT.
MSG
