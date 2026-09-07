#!/bin/bash
# Build a HerdrBar.app bundle. Does not install or restart the live extra.
# Usage: scripts/package-app.sh [dest.app]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

dest="${1:-$HOME/Applications/HerdrBar.app}"
version="${HERDR_BAR_VERSION:-}"
if [[ -z "$version" ]]; then
  version="$(git -C "$root" describe --tags --exact-match 2>/dev/null || true)"
  version="${version#v}"
fi
version="${version:-1.0.0}"

# Dual-arch is for the GitHub Release zip. Local install/reload stay host-native.
if [[ "${HERDR_BAR_UNIVERSAL:-0}" == "1" ]]; then
  swift build -c release --product MacBar --arch arm64 --arch x86_64
else
  swift build -c release --product MacBar
fi

bin=""
for candidate in \
  "$root/.build/apple/Products/Release/MacBar" \
  "$root/.build/release/MacBar"
do
  if [[ -x "$candidate" ]]; then
    bin="$candidate"
    break
  fi
done
if [[ -z "$bin" ]]; then
  echo "MacBar binary not found after swift build" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Resources"

cat > "$dest/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>dev.herdr.herdr-bar</string>
  <key>CFBundleName</key>
  <string>HerdrBar</string>
  <key>CFBundleExecutable</key>
  <string>MacBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>$version</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$bin" "$dest/Contents/MacOS/MacBar"
chmod +x "$dest/Contents/MacOS/MacBar"
# Ad-hoc sign so the extra launches after a zip download + xattr -cr.
codesign --force --deep --sign - "$dest" >/dev/null
echo "Packed $dest ($version)"
