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

# Both, from the tag. MARKETING_VERSION is what people see; CURRENT_PROJECT_VERSION
# is CFBundleVersion, which is the field Sparkle compares — left at its default
# of 1 it never changes and no update is ever offered.
SIGN_ARGS+=(MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION")

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
ZIP="$BUILD_DIR/$NAME-$VERSION.zip"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"

# Sparkle ships every helper ad-hoc signed, and `xcodebuild archive` does not
# re-sign them — verified: Autoupdate came out flags=0x10002(adhoc,runtime),
# TeamIdentifier=not set, from an archive signed with a real Developer ID.
# Notarization rejects that. No --deep: the docs warn against it, and each
# nested item is signed individually below, app last since it seals the rest.
if [ -n "${DEVELOPER_ID:-}" ] && [ -d "$SPARKLE" ]; then
  echo "▸ re-signing Sparkle helpers"
  for helper in \
      "XPCServices/Installer.xpc" \
      "XPCServices/Downloader.xpc" \
      "Autoupdate" \
      "Updater.app"; do
    [ -e "$SPARKLE/$helper" ] || continue
    codesign --force --sign "$DEVELOPER_ID" --options runtime --timestamp \
      --preserve-metadata=entitlements "$SPARKLE/$helper"
  done
  codesign --force --sign "$DEVELOPER_ID" --options runtime --timestamp \
    "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign "$DEVELOPER_ID" --options runtime --timestamp "$APP"
fi

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

# `codesign --verify --deep --strict` passes on an app whose nested helpers are
# ad-hoc — verified. So check for it explicitly; otherwise the only thing that
# catches it is notarization, as an opaque rejection.
# `|| true`: the inner `grep -q … && echo` returns 1 when nothing matches, and
# `set -e` would treat "found no problems" as a failure.
ADHOC=$(find "$APP/Contents/Frameworks" "$APP/Contents/MacOS" -type f -perm +111 2>/dev/null \
        | while read -r bin; do
            if codesign -dvv "$bin" 2>&1 | grep -q "Signature=adhoc"; then echo "$bin"; fi
          done || true)
if [ -n "${DEVELOPER_ID:-}" ] && [ -n "$ADHOC" ]; then
  echo "  ERROR: ad-hoc signed binaries remain:"
  echo "$ADHOC" | sed 's|.*/Contents/|    …/Contents/|'
  exit 1
fi

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/  /'
  SIG="$(codesign -dvv "$APP" 2>&1 || true)"
  grep -E "^(Authority|TeamIdentifier|Timestamp)" <<<"$SIG" | sed 's/^/  /'
  # Required for notarization: a binary without it is rejected at submission,
  # not at launch.
  grep -q "flags=.*runtime" <<<"$SIG" \
    || { echo "  ERROR: hardened runtime not enabled"; exit 1; }
fi

if [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
  # The app is notarized and stapled *before* either artifact is built, so the
  # copy Sparkle installs carries its own ticket and launches offline. Stapling
  # only the DMG leaves the app inside it unstapled.
  echo "▸ notarizing the app"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$BUILD_DIR/notarize.zip"
  xcrun notarytool submit "$BUILD_DIR/notarize.zip" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$APP"
  rm -f "$BUILD_DIR/notarize.zip"
fi

# ditto, not zip: frameworks are full of symlinks and a tool that follows them
# breaks the signature. --keepParent keeps the .app wrapper.
echo "▸ building update archive"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

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

  # The zip is what Sparkle actually installs, so prove it separately.
  VERIFY_DIR=$(mktemp -d)
  ditto -x -k "$ZIP" "$VERIFY_DIR"
  xcrun stapler validate "$VERIFY_DIR/$NAME.app" | sed 's/^/  /'
  spctl -a -t exec -vv "$VERIFY_DIR/$NAME.app" 2>&1 | sed 's/^/  /'
  rm -rf "$VERIFY_DIR"
fi

# Sparkle verifies this signature against SUPublicEDKey before installing, so
# a compromised host still cannot ship an update.
SIGN_UPDATE="${SIGN_UPDATE:-$(find ~/Library/Developer/Xcode/DerivedData \
    -path "*/artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -1 || true)}"
if [ -n "${SIGN_UPDATE:-}" ]; then
  if [ -x "$SIGN_UPDATE" ]; then
    echo "▸ signing the update archive"
    if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
      # CI has no keychain; --ed-key-file - reads the key from stdin.
      SIG=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$ZIP")
    else
      SIG=$("$SIGN_UPDATE" "$ZIP")
    fi
    echo "  $SIG"
    printf '%s\n' "$SIG" > "$BUILD_DIR/appcast-fragment.txt"
  else
    echo "  WARNING: sign_update not found; update archive is unsigned"
  fi
fi

# So CI does not have to rebuild these paths from the version string.
if [ -n "${GITHUB_ENV:-}" ]; then
  { echo "DMG_PATH=$DMG"; echo "ZIP_PATH=$ZIP"; } >> "$GITHUB_ENV"
fi

echo "▸ $ZIP"
ls -lh "$ZIP" | awk '{print "  " $5}'
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
