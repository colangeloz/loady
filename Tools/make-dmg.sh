#!/bin/bash
# Builds a distributable disk image.
#
# Three levels of output, depending on what's configured:
#
#   nothing set          ad-hoc signed. Runs here, Gatekeeper blocks it elsewhere.
#   DEVELOPER_ID         signed. Gatekeeper still blocks it — signing is not enough.
#   + notary credentials signed, notarized and stapled. Opens on any Mac.
#
# Notary credentials: NOTARY_PROFILE names a stored keychain profile, made once
# with `xcrun notarytool store-credentials`. A CI runner has no keychain to
# store one in, so it passes the App Store Connect key directly instead as
# NOTARY_KEY (the .p8 path), NOTARY_KEY_ID and NOTARY_ISSUER.

set -euo pipefail

NAME="Loady"
VERSION="${VERSION:-0.1.0}"
BUILD_DIR="${BUILD_DIR:-.build/release}"
STAGE="$BUILD_DIR/dmg"
DMG="$BUILD_DIR/$NAME-$VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$STAGE"

if [ -n "${DEVELOPER_ID:-}" ]; then
  SIGN_ARGS=(
    CODE_SIGN_IDENTITY="$DEVELOPER_ID"
    CODE_SIGN_STYLE=Manual
    ENABLE_HARDENED_RUNTIME=YES
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
else
  SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO)
fi

# Without this the bundle reports 1.0 forever, whatever the DMG is called.
SIGN_ARGS+=(MARKETING_VERSION="$VERSION")

NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${NOTARY_KEY:-}" ]; then
  NOTARY_ARGS=(--key "$NOTARY_KEY" --key-id "${NOTARY_KEY_ID:?NOTARY_KEY_ID required}" \
               --issuer "${NOTARY_ISSUER:?NOTARY_ISSUER required}")
fi

echo "▸ archiving"
xcodebuild archive \
  -project "$NAME.xcodeproj" -scheme "$NAME" -configuration Release \
  -archivePath "$BUILD_DIR/$NAME.xcarchive" \
  -destination 'generic/platform=macOS' \
  "${SIGN_ARGS[@]}" \
  >/dev/null

APP="$BUILD_DIR/$NAME.xcarchive/Products/Applications/$NAME.app"

echo "▸ verifying the app binary"
lipo -archs "$APP/Contents/MacOS/$NAME" | sed 's/^/  archs: /'

# These run unsigned too. A check that only fires when signing is configured is
# the check that misses a bad default until the day you first sign.
ENTS="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"

# On by default for new Xcode macOS targets, and it blocks IOServiceOpen —
# which the GPU and sensor readers need.
grep -q "app-sandbox" <<<"$ENTS" \
  && { echo "  ERROR: app-sandbox entitlement present — see ENABLE_APP_SANDBOX"; exit 1; }

# A debug-only entitlement. Notarization rejects any binary carrying it.
grep -q "get-task-allow" <<<"$ENTS" \
  && { echo "  ERROR: get-task-allow present — notarization would reject this"; exit 1; }

plutil -lint -s "$APP/Contents/Info.plist" >/dev/null
# Captured rather than piped throughout: `grep -q` exits on its first match and
# SIGPIPEs the producer, which `set -o pipefail` reports as a failed pipeline.
LSUI="$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$APP/Contents/Info.plist" 2>/dev/null || true)"
[ "$LSUI" = "true" ] || { echo "  ERROR: LSUIElement is not true — the app would show a Dock icon"; exit 1; }
ENT_COUNT=$(grep -c '<key>' <<<"$ENTS" 2>/dev/null) || true
echo "  entitlements: ${ENT_COUNT:-0} · LSUIElement: true · no sandbox"

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/  /'
  SIG="$(codesign -dvv "$APP" 2>&1 || true)"
  grep -E "^(Authority|TeamIdentifier|Timestamp)" <<<"$SIG" | sed 's/^/  /'
  # Required for notarization: a binary without it is rejected at submission,
  # not at launch.
  grep -q "flags=.*runtime" <<<"$SIG" \
    || { echo "  ERROR: hardened runtime not enabled"; exit 1; }
fi

cp -R "$APP" "$STAGE/"

ln -s /Applications "$STAGE/Applications"

echo "▸ building disk image"
hdiutil create \
  -volname "$NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "▸ signing the disk image"
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi

if [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
  if [ -z "${DEVELOPER_ID:-}" ]; then
    echo "  ERROR: notary credentials set but DEVELOPER_ID is not — nothing to notarize."
    exit 1
  fi
  echo "▸ notarizing (Apple's service; usually a few minutes)"
  # --wait, or the script "succeeds" with the submission still pending and
  # stapling fails.
  xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait

  echo "▸ stapling"
  # Attaches the ticket, so first launch works offline.
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG" | sed 's/^/  /'

  echo "▸ Gatekeeper check"
  spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | sed 's/^/  /'
fi

echo "▸ $DMG"
ls -lh "$DMG" | awk '{print "  " $5}'

if [ -z "${DEVELOPER_ID:-}" ]; then
  echo
  echo "  UNSIGNED — Gatekeeper will block this on other machines."
  echo "  Recipients must right-click → Open, or: xattr -dr com.apple.quarantine /Applications/$NAME.app"
elif [ ${#NOTARY_ARGS[@]} -eq 0 ]; then
  echo
  echo "  SIGNED BUT NOT NOTARIZED — Gatekeeper still blocks this on other machines."
  echo "  Set NOTARY_PROFILE (or NOTARY_KEY/_ID/_ISSUER) to complete the pipeline."
fi
