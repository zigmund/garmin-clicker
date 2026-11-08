#!/bin/bash
# Creates (once) a self-signed code signing certificate "Garmin Clicker Local"
# in the login keychain and trusts it for code signing. With a stable identity
# macOS keeps the Accessibility permission across rebuilds of the app.
#
# Safe to run repeatedly: existing certificate and trust are reused.
# macOS will ask for your password when the trust setting is added.
set -euo pipefail

NAME="Garmin Clicker Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
# System LibreSSL: its PKCS#12 output is readable by `security import`
# (OpenSSL 3+ defaults to algorithms the keychain may reject).
OPENSSL=/usr/bin/openssl

valid_identity() {
    security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$NAME\""
}

if valid_identity; then
    echo "Signing identity \"$NAME\" already exists and is trusted. Nothing to do."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Certificate \"$NAME\" found in the login keychain, reusing it."
    security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$WORK/cert.pem"
else
    echo "Creating certificate \"$NAME\"…"
    cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = $NAME

[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF
    "$OPENSSL" req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
        -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

    P12_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)"
    "$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -name "$NAME" -out "$WORK/cert.p12" -passout "pass:$P12_PASSWORD"

    # -T lets codesign use the private key without a keychain prompt.
    security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" \
        -T /usr/bin/codesign -T /usr/bin/security
fi

echo "Trusting \"$NAME\" for code signing (macOS will ask for your password)…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

if valid_identity; then
    echo "Done. \"make -C mac app\" will now sign with \"$NAME\"."
else
    echo "error: \"$NAME\" is still not a valid code signing identity." >&2
    exit 1
fi
