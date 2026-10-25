#!/bin/bash
# Prepare local artifacts only. Never creates commits, uploads, or publishes releases.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/review-publication.py
bash scripts/build-app.sh release
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
architecture="$(/usr/bin/lipo -archs build/Macventory.app/Contents/MacOS/Macventory | tr ' ' '-')"
output="$PWD/artifacts/Macventory-$version-$architecture"
mkdir -p artifacts
stage="$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")"
/usr/bin/ditto build/Macventory.app "$stage/Macventory.app"
/bin/ln -s /Applications "$stage/Applications"
cp Resources/DMG/FinderLayout "$stage/.DS_Store"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/Macventory.app "$output.zip"
/usr/bin/hdiutil create -volname Macventory -fs HFS+ -srcfolder "$stage" -ov -format UDZO "$output.dmg"
source_name="Macventory-$version-source.tar.gz"
# Use the reviewed Git publication set, not a recursive directory sweep that can
# accidentally include regenerated/ignored resources or private local files.
COPYFILE_DISABLE=1 /usr/bin/tar -czf "artifacts/$source_name" -T build/publication-manifest.txt
(
  cd artifacts
  /usr/bin/shasum -a 256 "$(basename "$output").zip" "$(basename "$output").dmg" "$source_name" > "$(basename "$output").sha256"
)
/usr/bin/codesign --verify --deep --strict --verbose=2 build/Macventory.app
printf '%s\n' "$output.zip" "$output.dmg" "$output.sha256" "$PWD/artifacts/$source_name"
