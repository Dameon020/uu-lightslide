#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/UU轻滑.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
read -r -a TARGET_ARCHS <<< "${ARCHS:-arm64 x86_64}"
SLICES=()
for arch in "${TARGET_ARCHS[@]}"; do
  case "$arch" in arm64|x86_64) ;; *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; esac
  mkdir -p ".build/$arch"
  xcrun swiftc -O -swift-version 5 -target "${arch}-apple-macosx13.0" \
    Sources/ScrollCore.swift Sources/ScrollEngine.swift Sources/main.swift \
    -o ".build/$arch/UUScrollHelper" -framework Cocoa -framework ApplicationServices -framework ServiceManagement
  SLICES+=(".build/$arch/UUScrollHelper")
done
xcrun lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/UUScrollHelper"
cp Info.plist "$APP/Contents/Info.plist"
cp 使用说明.html "$APP/Contents/Resources/使用说明.html"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE.md "$APP/Contents/Resources/"
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP"
else
  codesign --force --sign - --identifier local.rixin.UUScrollHelper \
    --requirements '=designated => identifier "local.rixin.UUScrollHelper"' "$APP"
fi
codesign --verify --strict "$APP"
xcrun lipo -info "$APP/Contents/MacOS/UUScrollHelper"
echo "Built: $APP"
