#!/bin/bash
# Import Mac App Store signing certificates and the provisioning profile
# into a temporary keychain on the GitHub Actions macOS runner.
# The p12 files must be exported with OpenSSL -legacy (3DES + SHA1 MAC);
# the OpenSSL 3 default AES/SHA256 MAC fails macOS security import.
set -euo pipefail

: "${MAC_DIST_P12:?}"
: "${MAC_DIST_P12_PASSWORD:?}"
: "${MAC_INSTALLER_P12:?}"
: "${MAC_INSTALLER_P12_PASSWORD:?}"
: "${MAC_PROVISIONING_PROFILE:?}"
: "${RUNNER_TEMP:?}"

KC="$RUNNER_TEMP/macsign.keychain-db"
KC_PWD_FILE="$RUNNER_TEMP/macsign-kc-pass"
openssl rand -base64 24 > "$KC_PWD_FILE"
chmod 600 "$KC_PWD_FILE"
KC_PWD=$(cat "$KC_PWD_FILE")

printf '%s' "$MAC_DIST_P12" | base64 --decode > "$RUNNER_TEMP/mac_dist.p12"
printf '%s' "$MAC_INSTALLER_P12" | base64 --decode > "$RUNNER_TEMP/mac_installer.p12"
printf '%s' "$MAC_PROVISIONING_PROFILE" | base64 --decode > "$RUNNER_TEMP/atguide.provisionprofile"
chmod 600 "$RUNNER_TEMP/mac_dist.p12" "$RUNNER_TEMP/mac_installer.p12" "$RUNNER_TEMP/atguide.provisionprofile"

security create-keychain -p "$KC_PWD" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KC_PWD" "$KC"
security import "$RUNNER_TEMP/mac_dist.p12" -k "$KC" -P "$MAC_DIST_P12_PASSWORD" -A -T /usr/bin/codesign -T /usr/bin/productbuild -T /usr/bin/xcodebuild
security import "$RUNNER_TEMP/mac_installer.p12" -k "$KC" -P "$MAC_INSTALLER_P12_PASSWORD" -A -T /usr/bin/codesign -T /usr/bin/productbuild -T /usr/bin/xcodebuild
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PWD" "$KC" >/dev/null
security list-keychains -d user -s "$KC" ~/Library/Keychains/login.keychain-db

# Install the profile where Xcode and productbuild will find it.
for dest in \
  "$HOME/Library/MobileDevice/Provisioning Profiles" \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
do
  mkdir -p "$dest"
  cp "$RUNNER_TEMP/atguide.provisionprofile" "$dest/02cd375b-9661-496d-b249-8f2ab0dbe1a4.provisionprofile"
done

echo "Imported Mac App Store signing materials."
