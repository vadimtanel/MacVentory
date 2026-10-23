#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
bash scripts/swift-tool.sh build -c "$configuration" --product Macventory
binary_directory="$(bash scripts/swift-tool.sh build -c "$configuration" --show-bin-path)"
app_directory="$PWD/build/Macventory.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$binary_directory/Macventory" "$app_directory/Contents/MacOS/Macventory"
cp Resources/Info.plist "$app_directory/Contents/Info.plist"
cp Resources/DMG/background.png "$app_directory/Contents/Resources/DMGBackground.png"
cp Resources/ToolbarMark.png "$app_directory/Contents/Resources/ToolbarMark.png"
cp Resources/Macventory.icns "$app_directory/Contents/Resources/Macventory.icns"
for document in LICENSE NOTICE; do
  if [ -f "$document" ]; then cp "$document" "$app_directory/Contents/Resources/"; fi
done
# SwiftPM release binaries can retain local object-file paths in debug symbols.
# Strip only the copied distribution executable before sealing the app bundle.
if [ "$configuration" = release ]; then /usr/bin/strip -S "$app_directory/Contents/MacOS/Macventory"; fi
/usr/bin/codesign --force --sign - "$app_directory"
printf '%s\n' "$app_directory"
