#!/bin/bash
# Prepends one <item> to site/appcast.xml from a built release.
#
#   ./Tools/update-appcast.sh <version> <zip> <edSignature> <length> [notes.html]
#
# Release notes are embedded rather than linked: sparkle:releaseNotesLink makes
# a second network request when the update dialog opens, which this app should
# not do, and a linked file would need signing of its own.

set -euo pipefail

VERSION="${1:?version}"
ZIP="${2:?zip path}"
SIGNATURE="${3:?edSignature}"
LENGTH="${4:?length}"
NOTES_FILE="${5:-}"

REPO="colangeloz/loady"
APPCAST="site/appcast.xml"
URL="https://github.com/$REPO/releases/download/v$VERSION/$(basename "$ZIP")"

# Re-running a release must not append a duplicate.
if grep -q "<sparkle:version>$VERSION</sparkle:version>" "$APPCAST"; then
  echo "  v$VERSION is already in the appcast; nothing to do"
  exit 0
fi

# Markdown in, minimal HTML out. Deliberately minimal: these render in
# Sparkle's WebKit view, so only escaped list items go through.
NOTES="<p>See the <a href=\"https://github.com/$REPO/releases/tag/v$VERSION\">release notes</a>.</p>"
if [ -n "$NOTES_FILE" ] && [ -s "$NOTES_FILE" ]; then
  CONVERTED=$(python3 -c '
import html, sys
lines = open(sys.argv[1]).read().splitlines()
items = [l.lstrip("*-# ").strip() for l in lines if l.strip().startswith(("*", "-"))]
print("<ul>" + "".join("<li>%s</li>" % html.escape(i) for i in items) + "</ul>" if items else "")
' "$NOTES_FILE")
  [ -n "$CONVERTED" ] && NOTES="$CONVERTED"
fi

ITEM=$(cat <<ITEMXML

    <item>
      <title>Loady $VERSION</title>
      <link>https://github.com/$REPO/releases/tag/v$VERSION</link>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0.0</sparkle:minimumSystemVersion>
      <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <description><![CDATA[
$NOTES
      ]]></description>
      <enclosure
        url="$URL"
        length="$LENGTH"
        type="application/octet-stream"
        sparkle:edSignature="$SIGNATURE" />
    </item>
ITEMXML
)

# Newest first, so the item goes directly after <language>.
python3 - "$APPCAST" "$ITEM" <<'PY'
import sys
path, item = sys.argv[1], sys.argv[2]
s = open(path).read()
anchor = "<language>en</language>"
assert anchor in s, "appcast is missing its <language> anchor"
open(path, "w").write(s.replace(anchor, anchor + item, 1))
PY

echo "  added v$VERSION to $APPCAST"
