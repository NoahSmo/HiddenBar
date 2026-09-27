#!/bin/zsh
# Compile et assemble HiddenBar.app
#   ./build.sh            → build + installe dans /Applications + lance
#   ./build.sh --release  → build + zip dans build/ (pour une release GitHub / Homebrew)
set -e
cd "$(dirname "$0")"

VERSION="1.0.0"
BUILD_NUMBER="3"

swift build -c release --arch arm64 --arch x86_64

APP="build/HiddenBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/HiddenBar "$APP/Contents/MacOS/HiddenBar"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>HiddenBar</string>
    <key>CFBundleIdentifier</key><string>com.noah.hiddenbar</string>
    <key>CFBundleExecutable</key><string>HiddenBar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

if [[ "$1" == "--release" ]]; then
    ZIP="build/HiddenBar-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "OK → $ZIP"
    echo "sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
    exit 0
fi

# Installe toujours au même endroit : sur macOS 27, MenuBarAgent mémorise
# la position des icônes par chemin d'app. Lancer une copie ailleurs
# (ex. build/) repartirait de zéro et « oublierait » les icônes cachées.
pkill -x HiddenBar || true
ditto "$APP" /Applications/HiddenBar.app
open /Applications/HiddenBar.app
echo "OK → /Applications/HiddenBar.app"
