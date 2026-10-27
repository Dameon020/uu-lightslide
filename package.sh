#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
  "") ARCHS="arm64 x86_64" ./build.sh ;;
  --reuse-app) ;;
  *) echo "Usage: ./package.sh [--reuse-app]" >&2; exit 1 ;;
esac
APP="$PWD/dist/UU轻滑.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ "$VERSION" != "$APP_VERSION" ]; then
  echo 'App version is invalid or differs from source. Rebuild first.' >&2; exit 1
fi
ACTUAL_ARCHS="$(xcrun lipo -archs "$APP/Contents/MacOS/UUScrollHelper")"
for expected in arm64 x86_64; do
  if [[ " $ACTUAL_ARCHS " != *" $expected "* ]]; then
    echo "Missing architecture: $expected" >&2; exit 1
  fi
done
codesign --verify --strict "$APP"
mkdir -p .build release
STAGE="$(mktemp -d "$PWD/.build/package.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
PREFIX="UU-LightSlide-v${VERSION}"
DMG="$PWD/release/${PREFIX}-universal.dmg"
APPZIP="$PWD/release/${PREFIX}-universal.app.zip"
SOURCEZIP="$PWD/release/${PREFIX}-source.zip"
mkdir -p "$STAGE/dmg"
ditto --norsrc --noextattr "$APP" "$STAGE/dmg/UU轻滑.app"
ln -s /Applications "$STAGE/dmg/Applications"
cp 使用说明.html "$STAGE/dmg/安装说明.html"
cp LICENSE NOTICE.md "$STAGE/dmg/"
hdiutil create -ov -volname "UU LightSlide ${VERSION}" -srcfolder "$STAGE/dmg" \
  -format UDZO -fs HFS+ "$DMG"
ditto --norsrc --noextattr -c -k --keepParent "$APP" "$APPZIP"
SRC="$STAGE/${PREFIX}-source"
mkdir -p "$SRC/Assets"
# Explicit allow-list: never archive the working directory or personal logs wholesale.
for name in Sources Tests docs .github; do cp -R "$name" "$SRC/"; done
for name in Info.plist build.sh test.sh package.sh README.md LICENSE NOTICE.md CONTRIBUTING.md CHANGELOG.md .gitignore 使用说明.html; do
  cp "$name" "$SRC/"
done
cp Assets/AppIcon.png Assets/AppIcon.icns "$SRC/Assets/"
ditto --norsrc --noextattr -c -k --keepParent "$SRC" "$SOURCEZIP"
(
  cd release
  shasum -a 256 "${PREFIX}-universal.dmg" "${PREFIX}-universal.app.zip" "${PREFIX}-source.zip" > SHA256SUMS.txt
)
echo "Release files: $PWD/release"
