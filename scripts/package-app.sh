#!/bin/bash
# Build a HerdrBar.app bundle. Does not install or restart the live extra.
# Usage: scripts/package-app.sh [dest.app]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

dest="${1:-$HOME/Applications/HerdrBar.app}"
# Release CI sets HERDR_BAR_VERSION from the tag. Local pack: exact tag,
# else nearest v* + `-dev` so About does not claim 1.0.0 (newer than 0.1.x).
version="${HERDR_BAR_VERSION:-}"
if [[ -z "$version" ]]; then
  if exact="$(git -C "$root" describe --tags --exact-match 2>/dev/null)"; then
    version="${exact#v}"
  elif nearest="$(git -C "$root" describe --tags --abbrev=0 2>/dev/null)"; then
    version="${nearest#v}-dev"
  else
    version="dev"
  fi
fi

find_product() {
  local name="$1"
  local candidate
  for candidate in \
    "$root/.build/apple/Products/Release/$name" \
    "$root/.build/release/$name"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Dual-arch is for the GitHub Release zip. Local install/reload stay host-native.
# Quote-empty "${arr[@]}" is unbound under `set -u`; keep the if/else.
if [[ "${HERDR_BAR_UNIVERSAL:-0}" == "1" ]]; then
  swift build -c release --product MacBar --arch arm64 --arch x86_64
else
  swift build -c release --product MacBar
fi

bin="$(find_product MacBar || true)"
if [[ -z "$bin" ]]; then
  echo "MacBar binary not found after swift build" >&2
  exit 1
fi

# WidgetKit on macOS 26 needs a real app-extension product (`-e _NSExtensionMain`).
# SwiftPM cannot emit that; WidgetExtension/ is an XcodeGen spec + committed xcodeproj.
if command -v xcodegen >/dev/null 2>&1; then
  (cd "$root/WidgetExtension" && xcodegen generate >/dev/null)
fi
widget_proj="$root/WidgetExtension/HerdrWidgetExtension.xcodeproj"
if [[ ! -d "$widget_proj" ]]; then
  echo "missing $widget_proj (install xcodegen or commit the generated project)" >&2
  exit 1
fi
widget_dd="$root/.build/widget-derived"
rm -rf "$widget_dd"
xcode_args=(
  -project "$widget_proj"
  -scheme HerdrWidgetExtension
  -configuration Release
  -derivedDataPath "$widget_dd"
  CODE_SIGNING_ALLOWED=NO
  MARKETING_VERSION="$version"
  CURRENT_PROJECT_VERSION="$version"
)
if [[ "${HERDR_BAR_UNIVERSAL:-0}" == "1" ]]; then
  xcode_args+=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
fi
xcodebuild "${xcode_args[@]}"
appex="$widget_dd/Build/Products/Release/HerdrWidget.appex"
if [[ ! -d "$appex" ]]; then
  echo "HerdrWidget.appex not found after xcodebuild" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Resources" "$dest/Contents/PlugIns"

cat > "$dest/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>HerdrBar</string>
  <key>CFBundleIdentifier</key>
  <string>dev.herdr.herdr-bar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>HerdrBar</string>
  <key>CFBundleExecutable</key>
  <string>MacBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>CFBundleVersion</key>
  <string>$version</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>dev.herdr.herdr-bar</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>herdr-bar</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

cp "$bin" "$dest/Contents/MacOS/MacBar"
chmod +x "$dest/Contents/MacOS/MacBar"
ditto "$appex" "$dest/Contents/PlugIns/HerdrWidget.appex"
swift "$root/scripts/render-app-icon.swift" "$dest/Contents/Resources/AppIcon.icns"
# Ad-hoc sign inner extension first, then the extra. Do not `--deep` the
# parent: that restamps the appex without entitlements and pkd skips it.
codesign --force --sign - --timestamp=none \
  --identifier dev.herdr.herdr-bar.widget \
  --entitlements "$root/WidgetExtension/HerdrWidget.entitlements" \
  "$dest/Contents/PlugIns/HerdrWidget.appex" >/dev/null
codesign --force --sign - --timestamp=none \
  --identifier dev.herdr.herdr-bar \
  "$dest" >/dev/null
echo "Packed $dest ($version)"
