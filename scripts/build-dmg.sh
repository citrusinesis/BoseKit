#!/bin/sh
set -eu

if [ $# -ne 1 ]; then
    echo "usage: $0 <version>" >&2
    exit 64
fi

version="$1"
root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/build"
derived="$output/DerivedData"
stage="$output/dmg"
dmg="$output/BoseKit-$version.dmg"

xcodebuild build \
    -workspace "$root/BoseKit.xcworkspace" \
    -scheme BoseKit \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived" \
    MARKETING_VERSION="$version" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM=

app="$derived/Build/Products/Release/BoseKit.app"
codesign --verify --deep --strict "$app"

rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

diskutil image create from --format UDZO --volumeName BoseKit "$stage" "$dmg"
rm -rf "$stage"

shasum -a 256 "$dmg"
