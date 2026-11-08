#!/usr/bin/env bash
# The code-signing dry run on macOS (ROADMAP §8 exit check, risk "Code signing and
# notarization"): signs a copy of a built Ferman.app as M5's release will, inside out with the
# hardened runtime and the release entitlements, but with a throwaway self-signed identity in a
# temporary keychain, then verifies the seal. No secrets, no Apple account, no notarization, no
# timestamp server; the original bundle is not touched. tools/signing/README.md says what M5 adds.
#
# Usage: tools/signing/dry-run-macos.sh <Ferman.app>   (needs sudo without a password: CI only)
set -euo pipefail

if [ $# -ne 1 ] || [ ! -d "$1/Contents" ]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 64
fi
repo="$(cd "$(dirname "$0")/../.." && pwd)"
entitlements="$repo/app/macos/Runner/Release.entitlements"
work="$(mktemp -d)"
keychain="$work/dry-run.keychain-db"
pass=dry-run
name="Ferman Signing Dry Run"
# security create-keychain adds the keychain to the user's search list; put the list back.
saved=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  saved+=("${line//\"/}")
done < <(security list-keychains -d user)
trusted=
cleanup() {
  if [ -n "$trusted" ]; then sudo security remove-trusted-cert -d "$work/cert.pem" || true; fi
  security list-keychains -d user -s "${saved[@]}" || true
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$name" \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
# OpenSSL 3 needs -legacy for a PKCS #12 file that security can import; LibreSSL has no flag.
legacy=()
if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then legacy=(-legacy); fi
openssl pkcs12 -export "${legacy[@]}" -inkey "$work/key.pem" -in "$work/cert.pem" \
  -name "$name" -out "$work/identity.p12" -passout "pass:$pass"
security create-keychain -p "$pass" "$keychain"
security set-keychain-settings "$keychain"
security unlock-keychain -p "$pass" "$keychain"
security import "$work/identity.p12" -k "$keychain" -P "$pass" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$pass" "$keychain" >/dev/null
identity="$(openssl x509 -in "$work/cert.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
# codesign takes only a trusted identity. Trusting it for code signing in the admin domain needs
# sudo without a prompt (a CI runner); the trust is removed again on exit.
sudo -n security add-trusted-cert -d -r trustRoot -p codeSign -k "$keychain" "$work/cert.pem"
trusted=1
security find-identity -v -p codesigning "$keychain"

app="$work/$(basename "$1")"
ditto "$1" "$app"
sign() {
  codesign --force --keychain "$keychain" --sign "$identity" --timestamp=none --options runtime "$@"
}
# Inside out: the deepest frameworks and libraries first, then the helper, then the app.
while IFS= read -r item; do
  sign "$item"
done < <(find "$app/Contents/Frameworks" \( -name '*.framework' -o -name '*.dylib' \) -print 2>/dev/null |
  awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2-)
sign "$app/Contents/MacOS/ferman-mcp"
sign --entitlements "$entitlements" "$app"

codesign --verify --deep --strict --verbose=2 "$app"
authority="$(codesign -dvv "$app" 2>&1 | grep '^Authority=' | head -n 1)"
if [ "$authority" != "Authority=$name" ]; then
  echo "error: the app is not signed by the dry-run identity ($authority)" >&2
  exit 1
fi
codesign -d --entitlements - "$app" 2>/dev/null | grep -q 'com.apple.security.app-sandbox' || {
  echo "error: the signature lost the release entitlements" >&2
  exit 1
}
echo "Signed and verified a copy of $(basename "$1") with a throwaway identity."
