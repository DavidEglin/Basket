#!/bin/sh
# Builds a Release Basket.app and packages it as build/Basket-<version>.dmg.
# The app is ad-hoc signed ("Sign to Run Locally"), so on another Mac the first
# open needs right-click → Open (or System Settings → Privacy & Security → Open Anyway).
set -eu

cd "$(dirname "$0")/.."
BUILD=build
DERIVED="$BUILD/DerivedData"

xcodegen generate --quiet

xcodebuild \
    -project Basket.xcodeproj \
    -scheme Basket \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY=- \
    -quiet \
    build

APP="$DERIVED/Build/Products/Release/Basket.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="$BUILD/Basket-$VERSION.dmg"

codesign --verify --deep --strict "$APP"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "Basket $VERSION" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -quiet \
    "$DMG"

echo "Created $DMG"
